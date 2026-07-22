import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'About',
      actions: [
        PlaceholderAction(
          label: () => 'legal.cgu'.tr(),
          onPressed: () => context.push('/profile/legal/cgu'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: () => 'legal.privacy'.tr(),
          onPressed: () => context.push('/profile/legal/privacy'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: () => 'legal.legal'.tr(),
          onPressed: () => context.push('/profile/legal/legal'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: () => 'legal.cookies'.tr(),
          onPressed: () => context.push('/profile/legal/cookies'),
          variant: AppButtonVariant.secondary,
        ),
      ],
      child: Text(
        'about.versionLabel'.tr(namedArgs: {'version': _version ?? '…'}),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColorTokens.of(context).textMuted),
      ),
    );
  }
}
