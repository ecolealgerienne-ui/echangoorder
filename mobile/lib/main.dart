import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'navigation/app_router.dart';
import 'state/auth_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      child: const EchangoOrderApp(),
    ),
  );
}

class EchangoOrderApp extends StatefulWidget {
  const EchangoOrderApp({super.key});

  @override
  State<EchangoOrderApp> createState() => _EchangoOrderAppState();
}

class _EchangoOrderAppState extends State<EchangoOrderApp> {
  late final AuthState _authState;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authState = AuthState();
    _router = buildAppRouter(_authState);
  }

  @override
  void dispose() {
    _authState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthState>.value(
      value: _authState,
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
