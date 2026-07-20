import 'package:go_router/go_router.dart';

import '../screens/auth/auth_welcome_screen.dart';
import '../screens/auth/forgot_pin_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/reauth_pin_screen.dart';
import '../screens/auth/register_step1_screen.dart';
import '../screens/auth/register_step2_screen.dart';
import '../screens/auth/register_step3_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/checkout/checkout_address_screen.dart';
import '../screens/checkout/checkout_out_of_zone_screen.dart';
import '../screens/checkout/checkout_reception_mode_screen.dart';
import '../screens/checkout/checkout_resolve_unavailable_screen.dart';
import '../screens/checkout/checkout_summary_screen.dart';
import '../screens/checkout/checkout_timeslot_screen.dart';
import '../screens/checkout/order_confirmation_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/legal/about_screen.dart';
import '../screens/legal/legal_document_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/order/order_history_screen.dart';
import '../screens/order/order_tracking_screen.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/profile/addresses_screen.dart';
import '../screens/profile/change_pin_screen.dart';
import '../screens/profile/favorites_screen.dart';
import '../screens/profile/language_settings_screen.dart';
import '../screens/profile/notification_settings_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/system/maintenance_screen.dart';
import '../screens/vitrine/vitrine_screen.dart';
import '../state/auth_state.dart';
import 'main_tab_scaffold.dart';
import 'sheet_page.dart';

const _publicPaths = [
  '/vitrine',
  '/onboarding',
  '/auth-welcome',
  '/register/step1',
  '/register/step2',
  '/register/step3',
  '/login',
  '/forgot-pin',
  // F13 — accessible depuis l'inscription (utilisateur pas encore
  // authentifié), en plus de `/profile/legal/:docType` (déjà accessible
  // depuis "À propos" une fois connecté).
  '/legal',
];

GoRouter buildAppRouter(AuthState authState) {
  return GoRouter(
    initialLocation: '/vitrine',
    refreshListenable: authState,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // Session expirée (24h d'inactivité ou rejet serveur) : imposé avant
      // tout le reste, quelle que soit la route visée, jusqu'à ce que
      // ReauthPinScreen fasse repasser AuthState en `authenticated`.
      if (authState.isSessionExpired) {
        return loc == '/reauth' ? null : '/reauth';
      }
      final isPublicRoute = _publicPaths.any((p) => loc.startsWith(p));
      if (!authState.isAuthenticated && !isPublicRoute && loc != '/maintenance') {
        return '/vitrine';
      }
      if (authState.isAuthenticated && (isPublicRoute || loc == '/reauth')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/vitrine', builder: (context, state) => const VitrineScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth-welcome', builder: (context, state) => const AuthWelcomeScreen()),
      GoRoute(path: '/register/step1', builder: (context, state) => const RegisterStep1Screen()),
      GoRoute(
        path: '/register/step2',
        builder: (context, state) {
          final draft = (state.extra as Map<String, dynamic>?) ?? const {};
          return RegisterStep2Screen(
            phone: draft['phone'] as String? ?? '',
            name: draft['name'] as String? ?? '',
            lang: draft['lang'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/register/step3',
        builder: (context, state) {
          final draft = (state.extra as Map<String, dynamic>?) ?? const {};
          return RegisterStep3Screen(
            phone: draft['phone'] as String? ?? '',
            name: draft['name'] as String? ?? '',
            lang: draft['lang'] as String? ?? '',
          );
        },
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/forgot-pin', builder: (context, state) => const ForgotPinScreen()),
      GoRoute(path: '/reauth', builder: (context, state) => const ReauthPinScreen()),
      GoRoute(
        path: '/legal/:docType',
        builder: (context, state) => LegalDocumentScreen(docType: state.pathParameters['docType']!),
      ),
      // Affiché quand le health-check Odoo (GET /web/health) échoue, une fois branché.
      GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainTabScaffold(navigationShell: navigationShell),
        branches: [
          // Catalogue (F04) fusionné dans l'Accueil (2026-07-20, demande
          // utilisateur) : le bandeau catégories de HomeScreen filtre
          // directement sa propre grille au lieu de naviguer vers un écran
          // dédié — CatalogScreen/CategoryProductsScreen supprimés (rôle
          // repris par HomeScreen). SearchScreen reste un écran à part
          // entière (une vraie recherche texte mérite sa propre UI), déplacé
          // sous l'onglet Accueil.
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'product/:productId',
                  builder: (context, state) =>
                      ProductDetailScreen(productId: state.pathParameters['productId']!),
                ),
                GoRoute(path: 'search', builder: (context, state) => const SearchScreen()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cart',
              builder: (context, state) => const CartScreen(),
              // Tunnel checkout présenté en feuille (slide-up, coins arrondis,
              // fond assombri) plutôt qu'en push plein écran classique —
              // direction Casbah, voir `navigation/sheet_page.dart` et
              // `docs/design_direction.md` § Phase D. Le panier lui-même
              // (au-dessus) reste un onglet classique de la barre de
              // navigation, non concerné par ce traitement.
              routes: [
                GoRoute(
                  path: 'checkout/reception-mode',
                  pageBuilder: (context, state) =>
                      sheetPage(state: state, child: const CheckoutReceptionModeScreen()),
                ),
                GoRoute(
                  path: 'checkout/address',
                  pageBuilder: (context, state) => sheetPage(state: state, child: const CheckoutAddressScreen()),
                ),
                GoRoute(
                  path: 'checkout/out-of-zone',
                  pageBuilder: (context, state) =>
                      sheetPage(state: state, child: const CheckoutOutOfZoneScreen()),
                ),
                GoRoute(
                  path: 'checkout/timeslot',
                  pageBuilder: (context, state) => sheetPage(state: state, child: const CheckoutTimeslotScreen()),
                ),
                GoRoute(
                  path: 'checkout/summary',
                  pageBuilder: (context, state) => sheetPage(state: state, child: const CheckoutSummaryScreen()),
                ),
                GoRoute(
                  path: 'checkout/resolve-unavailable',
                  pageBuilder: (context, state) => sheetPage(
                    state: state,
                    child: CheckoutResolveUnavailableScreen(
                      lines: (state.extra as List).cast<Map<String, dynamic>>(),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'checkout/confirmation/:orderRef',
                  pageBuilder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return sheetPage(
                      state: state,
                      child: OrderConfirmationScreen(
                        orderRef: state.pathParameters['orderRef']!,
                        amountTotal: (extra?['amount_total'] as num?)?.toDouble(),
                        receptionMode: extra?['reception_mode'] as String?,
                        slotStart: extra?['slot_start'] as String?,
                      ),
                    );
                  },
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'addresses', builder: (context, state) => const AddressesScreen()),
                GoRoute(path: 'favorites', builder: (context, state) => const FavoritesScreen()),
                GoRoute(
                  path: 'product/:productId',
                  builder: (context, state) =>
                      ProductDetailScreen(productId: state.pathParameters['productId']!),
                ),
                GoRoute(path: 'change-pin', builder: (context, state) => const ChangePinScreen()),
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const NotificationSettingsScreen(),
                ),
                GoRoute(path: 'language', builder: (context, state) => const LanguageSettingsScreen()),
                GoRoute(path: 'orders', builder: (context, state) => const OrderHistoryScreen()),
                GoRoute(
                  path: 'orders/:orderRef',
                  builder: (context, state) =>
                      OrderTrackingScreen(orderRef: state.pathParameters['orderRef']!),
                ),
                GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
                GoRoute(
                  path: 'legal/:docType',
                  builder: (context, state) =>
                      LegalDocumentScreen(docType: state.pathParameters['docType']!),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
}
