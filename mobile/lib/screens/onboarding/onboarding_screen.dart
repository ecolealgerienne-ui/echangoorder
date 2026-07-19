import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class _OnboardingSlide {
  final IconData icon;
  final String titleKey;
  final String subtitleKey;

  const _OnboardingSlide({required this.icon, required this.titleKey, required this.subtitleKey});
}

/// F01 — specs §"3 slides maximum : Commander / Choisir retrait ou
/// livraison / Suivre sa commande". Icônes Material en guise
/// d'illustration (pas d'asset graphique dédié dans le projet, cohérent
/// avec le reste de l'app qui n'utilise que des icônes).
const _slides = [
  _OnboardingSlide(
    icon: Icons.shopping_basket_outlined,
    titleKey: 'onboarding.slide1Title',
    subtitleKey: 'onboarding.slide1Subtitle',
  ),
  _OnboardingSlide(
    icon: Icons.storefront_outlined,
    titleKey: 'onboarding.slide2Title',
    subtitleKey: 'onboarding.slide2Subtitle',
  ),
  _OnboardingSlide(
    icon: Icons.local_shipping_outlined,
    titleKey: 'onboarding.slide3Title',
    subtitleKey: 'onboarding.slide3Subtitle',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<AuthState>().completeOnboarding();
    context.go('/auth-welcome');
  }

  void _next() {
    if (_currentPage == _slides.length - 1) {
      _finish();
      return;
    }
    // PageView respecte nativement la Directionality ambiante (sens de
    // swipe inversé en RTL) — rien à gérer explicitement ici pour l'arabe.
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final isLastSlide = _currentPage == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(slide.icon, size: 96, color: AppColors.primary),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          slide.titleKey.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.subtitleKey.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentPage ? AppColors.primary : AppColors.disabled,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(label: isLastSlide ? 'common.confirm'.tr() : 'common.next'.tr(), onPressed: _next),
                  AppButton(label: 'common.skip'.tr(), onPressed: _finish, variant: AppButtonVariant.secondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
