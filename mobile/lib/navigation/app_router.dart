import 'package:go_router/go_router.dart';

import '../screens/auth/auth_welcome_screen.dart';
import '../screens/auth/forgot_pin_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/reauth_pin_screen.dart';
import '../screens/auth/register_step1_screen.dart';
import '../screens/auth/register_step2_screen.dart';
import '../screens/auth/register_step3_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/catalog/category_products_screen.dart';
import '../screens/catalog/search_screen.dart';
import '../screens/checkout/checkout_address_screen.dart';
import '../screens/checkout/checkout_out_of_zone_screen.dart';
import '../screens/checkout/checkout_reception_mode_screen.dart';
import '../screens/checkout/checkout_summary_screen.dart';
import '../screens/checkout/checkout_timeslot_screen.dart';
import '../screens/checkout/order_confirmation_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/legal/about_screen.dart';
import '../screens/legal/legal_document_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/order/order_history_screen.dart';
import '../screens/order/order_tracking_screen.dart';
import '../screens/order/substitution_screen.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/profile/addresses_screen.dart';
import '../screens/profile/change_pin_screen.dart';
import '../screens/profile/favorites_screen.dart';
import '../screens/profile/language_settings_screen.dart';
import '../screens/profile/notification_settings_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/system/maintenance_screen.dart';
import '../screens/vitrine/vitrine_screen.dart';
import '../state/auth_state.dart';
import 'main_tab_scaffold.dart';

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
        builder: (context, state) => RegisterStep2Screen(phone: (state.extra as String?) ?? ''),
      ),
      GoRoute(
        path: '/register/step3',
        builder: (context, state) => RegisterStep3Screen(phone: (state.extra as String?) ?? ''),
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
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/catalog',
              builder: (context, state) => const CatalogScreen(),
              routes: [
                GoRoute(
                  path: 'category/:categoryId',
                  builder: (context, state) => CategoryProductsScreen(
                    categoryId: state.pathParameters['categoryId']!,
                    categoryName: state.extra as String?,
                  ),
                ),
                GoRoute(path: 'search', builder: (context, state) => const SearchScreen()),
                GoRoute(
                  path: 'product/:productId',
                  builder: (context, state) =>
                      ProductDetailScreen(productId: state.pathParameters['productId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cart',
              builder: (context, state) => const CartScreen(),
              routes: [
                GoRoute(
                  path: 'checkout/reception-mode',
                  builder: (context, state) => const CheckoutReceptionModeScreen(),
                ),
                GoRoute(
                  path: 'checkout/address',
                  builder: (context, state) => const CheckoutAddressScreen(),
                ),
                GoRoute(
                  path: 'checkout/out-of-zone',
                  builder: (context, state) => const CheckoutOutOfZoneScreen(),
                ),
                GoRoute(
                  path: 'checkout/timeslot',
                  builder: (context, state) => const CheckoutTimeslotScreen(),
                ),
                GoRoute(
                  path: 'checkout/summary',
                  builder: (context, state) => const CheckoutSummaryScreen(),
                ),
                GoRoute(
                  path: 'checkout/confirmation/:orderRef',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return OrderConfirmationScreen(
                      orderRef: state.pathParameters['orderRef']!,
                      amountTotal: (extra?['amount_total'] as num?)?.toDouble(),
                      receptionMode: extra?['reception_mode'] as String?,
                      slotStart: extra?['slot_start'] as String?,
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
                  routes: [
                    GoRoute(
                      path: 'substitution',
                      builder: (context, state) =>
                          SubstitutionScreen(orderRef: state.pathParameters['orderRef']!),
                    ),
                  ],
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
