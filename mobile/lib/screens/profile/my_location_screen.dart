import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../services/permission_service.dart';
import '../../widgets/screen_placeholder.dart';

class MyLocationScreen extends StatelessWidget {
  const MyLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'MyLocation',
      actions: [
        PlaceholderAction(
          label: 'actions.useGpsLocation'.tr(),
          onPressed: () => requestLocationPermission(context),
        ),
      ],
    );
  }
}
