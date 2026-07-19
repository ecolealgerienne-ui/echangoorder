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
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final authState = AuthState(prefs);
  late final OdooApiClient apiClient;
  apiClient = OdooApiClient(
    // Session Odoo expirée côté serveur (24h d'inactivité, cf. CLAUDE.md) :
    // on se déconnecte localement plutôt que de laisser chaque écran
    // gérer ce cas séparément — go_router redirige alors automatiquement
    // vers les routes publiques via le `redirect` déjà branché sur
    // AuthState (voir navigation/app_router.dart).
    onSessionExpired: () {
      authState.logout();
      apiClient.clearSession();
    },
  );
  await apiClient.restoreSession();

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

class _EchangoOrderAppState extends State<EchangoOrderApp> {
  late final CartState _cartState;
  late final CheckoutState _checkoutState;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _cartState = CartState(widget.apiClient);
    _checkoutState = CheckoutState();
    _router = buildAppRouter(widget.authState);
  }

  @override
  void dispose() {
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
      ],
      child: MaterialApp.router(
        title: 'Echango Order',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: _router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
      ),
    );
  }
}
