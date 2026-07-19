import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/screen_placeholder.dart';

/// F10 — profil : en-tête nom/téléphone réel (`/echango/profile`), nom
/// modifiable (tap). Le téléphone reste en lecture seule : c'est aussi le
/// login (F02), le modifier nécessiterait une re-vérification par SMS non
/// implémentée — voir status-V1.md.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>>? _profileFuture;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthState>().status == SessionStatus.authenticated) {
      _load();
    }
  }

  void _load() {
    setState(() {
      _profileFuture = context.read<OdooApiClient>().getProfile();
    });
  }

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('profile.editNameTitle'.tr()),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentName || !mounted) return;

    try {
      await context.read<OdooApiClient>().updateProfileName(name: newName);
      if (!mounted) return;
      AppMessenger.showInfo(context, 'profile.nameUpdated');
      _load();
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e);
    }
  }

  void _logout(BuildContext context) {
    context.read<OdooApiClient>().clearSession();
    context.read<AuthState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthState>().status == SessionStatus.authenticated;

    return ScreenPlaceholder(
      screenKey: 'Profile',
      actions: [
        PlaceholderAction(
          label: 'screens.Addresses.title'.tr(),
          onPressed: () => context.push('/profile/addresses'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'screens.Favorites.title'.tr(),
          onPressed: () => context.push('/profile/favorites'),
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
      child: isAuthenticated ? _buildHeader(context) : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (_profileFuture == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snapshot.data!;
        final name = profile['name'] as String? ?? '';
        final phone = profile['phone'] as String? ?? '';
        return InkWell(
          onTap: () => _editName(name),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 40, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      Text(phone, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}
