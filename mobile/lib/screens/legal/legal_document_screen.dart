import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../widgets/screen_placeholder.dart';

class LegalDocumentScreen extends StatelessWidget {
  final String docType;

  const LegalDocumentScreen({super.key, required this.docType});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'LegalDocument',
      child: Text('legal.$docType'.tr(), style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
