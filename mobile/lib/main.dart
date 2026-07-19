import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'navigation/app_router.dart';
import 'services/odoo_api_client.dart';
import 'state/auth_state.dart';
import 'state/cart_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      child: EchangoOrderApp(prefs: prefs),
    ),
  );
}

class EchangoOrderApp extends StatefulWidget {
  final SharedPreferences prefs;

  const EchangoOrderApp({super.key, required this.prefs});

  @override
  State<EchangoOrderApp> createState() => _EchangoOrderAppState();
}

class _EchangoOrderAppState extends State<EchangoOrderApp> {
  late final AuthState _authState;
  late final OdooApiClient _apiClient;
  late final CartState _cartState;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authState = AuthState(widget.prefs);
    _apiClient = OdooApiClient();
    _cartState = CartState(_apiClient);
    _router = buildAppRouter(_authState);
  }

  @override
  void dispose() {
    _authState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>.value(value: _authState),
        Provider<OdooApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<CartState>.value(value: _cartState),
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
