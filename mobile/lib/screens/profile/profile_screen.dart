import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/odoo_api_client.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/screen_placeholder.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _logout(BuildContext context) {
    context.read<OdooApiClient>().clearSession();
    context.read<AuthState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'Profile',
      actions: [
        PlaceholderAction(
          label: 'screens.Addresses.title'.tr(),
          onPressed: () => context.push('/profile/addresses'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'screens.MyLocation.title'.tr(),
          onPressed: () => context.push('/profile/my-location'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'screens.ChangePin.title'.tr(),
          onPressed: () => context.push('/profile/change-pin'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'screens.NotificationSettings.title'.tr(),
          onPressed: () => context.push('/profile/notifications'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'screens.LanguageSettings.title'.tr(),
          onPressed: () => context.push('/profile/language'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'screens.OrderHistory.title'.tr(),
          onPressed: () => context.push('/profile/orders'),
        ),
        PlaceholderAction(
          label: 'screens.About.title'.tr(),
          onPressed: () => context.push('/profile/about'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'actions.logout'.tr(),
          onPressed: () => _logout(context),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'actions.deleteAccount'.tr(),
          onPressed: () => showDeleteAccountDialog(context),
          variant: AppButtonVariant.danger,
        ),
      ],
    );
  }
}
