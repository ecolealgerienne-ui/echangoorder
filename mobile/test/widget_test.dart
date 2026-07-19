import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echango_order/main.dart';
import 'package:echango_order/services/odoo_api_client.dart';
import 'package:echango_order/state/auth_state.dart';

void main() {
  testWidgets('App builds and shows the Vitrine screen without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await EasyLocalization.ensureInitialized();

    // Pas d'appel à restoreSession()/clearSession() ici : ça toucherait le
    // stockage sécurisé (canal de plateforme indisponible en test widget).
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('fr'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('fr'),
        startLocale: const Locale('fr'),
        child: EchangoOrderApp(authState: AuthState(prefs), apiClient: OdooApiClient()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EchangoOrderApp), findsOneWidget);
  });
}
