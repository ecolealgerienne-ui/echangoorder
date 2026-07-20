import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'navigation/app_router.dart';
import 'services/odoo_api_client.dart';
import 'state/auth_state.dart';
import 'state/cart_state.dart';
import 'state/checkout_state.dart';
import 'state/currency_state.dart';
import 'state/favorites_state.dart';
import 'state/locale_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final authState = AuthState(prefs);
  late final OdooApiClient apiClient;
  apiClient = OdooApiClient(
    // Session Odoo expirée côté serveur (rejet explicite, ou 24h
    // d'inactivité détectées côté client via checkInactivity()) :
    // expireSession() (pas logout()) conserve le téléphone connu pour
    // permettre une ré-authentification par PIN seul (ReauthPinScreen) au
    // lieu de renvoyer tout l'écran de connexion — go_router redirige
    // automatiquement vers /reauth via le `redirect` branché sur AuthState
    // (voir navigation/app_router.dart).
    onSessionExpired: () {
      apiClient.clearSession();
      authState.expireSession();
    },
    onActivity: authState.touchActivity,
  );
  await apiClient.restoreSession();
  authState.checkInactivity();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      child: EchangoOrderApp(authState: authState, apiClient: apiClient),
    ),
  );
}

class EchangoOrderApp extends StatefulWidget {
  final AuthState authState;
  final OdooApiClient apiClient;

  const EchangoOrderApp({super.key, required this.authState, required this.apiClient});

  @override
  State<EchangoOrderApp> createState() => _EchangoOrderAppState();
}

class _EchangoOrderAppState extends State<EchangoOrderApp> with WidgetsBindingObserver {
  late final CartState _cartState;
  late final CheckoutState _checkoutState;
  late final FavoritesState _favoritesState;
  late final CurrencyState _currencyState;
  late final LocaleState _localeState;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cartState = CartState(widget.apiClient);
    _checkoutState = CheckoutState();
    _favoritesState = FavoritesState(widget.apiClient);
    _currencyState = CurrencyState(widget.apiClient);
    _localeState = LocaleState();
    // Accessible avant connexion (F00 vitrine) : chargée une fois au
    // démarrage plutôt qu'à l'authentification, silencieuse en cas
    // d'échec (l'app reste utilisable avec le symbole par défaut).
    _currencyState.refresh().catchError((_) {});
    _router = buildAppRouter(widget.authState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Session expirée après 24h d'inactivité (CLAUDE.md) : le retour au
    // premier plan est le point de contrôle réaliste, l'app passant le
    // plus clair de ces 24h en arrière-plan ou fermée.
    if (state == AppLifecycleState.resumed) {
      widget.authState.checkInactivity();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>.value(value: widget.authState),
        Provider<OdooApiClient>.value(value: widget.apiClient),
        ChangeNotifierProvider<CartState>.value(value: _cartState),
        ChangeNotifierProvider<CheckoutState>.value(value: _checkoutState),
        ChangeNotifierProvider<FavoritesState>.value(value: _favoritesState),
        ChangeNotifierProvider<CurrencyState>.value(value: _currencyState),
        ChangeNotifierProvider<LocaleState>.value(value: _localeState),
      ],
      child: MaterialApp.router(
        title: 'Echango Order',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppDarkTheme(),
        themeMode: ThemeMode.system,
        routerConfig: _router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
      ),
    );
  }
}
