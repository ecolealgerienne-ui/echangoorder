import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/checkout_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

/// F07 — étape 1 : mode de réception.
class CheckoutReceptionModeScreen extends StatefulWidget {
  const CheckoutReceptionModeScreen({super.key});

  @override
  State<CheckoutReceptionModeScreen> createState() => _CheckoutReceptionModeScreenState();
}

class _CheckoutReceptionModeScreenState extends State<CheckoutReceptionModeScreen> {
  ReceptionMode? _mode;

  @override
  void initState() {
    super.initState();
    _mode = context.read<CheckoutState>().receptionMode;
  }

  void _continue() {
    final mode = _mode;
    if (mode == null) return;
    context.read<CheckoutState>().setReceptionMode(mode);
    context.push(mode == ReceptionMode.delivery ? '/cart/checkout/address' : '/cart/checkout/timeslot');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens.CheckoutReceptionMode.title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: RadioListTile<ReceptionMode>(
                  value: ReceptionMode.delivery,
                  groupValue: _mode,
                  onChanged: (value) => setState(() => _mode = value),
                  title: Text('checkout.deliveryHome'.tr()),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: RadioListTile<ReceptionMode>(
                  value: ReceptionMode.pickup,
                  groupValue: _mode,
                  onChanged: (value) => setState(() => _mode = value),
                  title: Text('checkout.pickupStore'.tr()),
                ),
              ),
              const Spacer(),
              AppButton(label: 'common.continue'.tr(), onPressed: _mode == null ? null : _continue),
            ],
          ),
        ),
      ),
    );
  }
}
