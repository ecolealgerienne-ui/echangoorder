import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/checkout_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/timeslots.dart';
import '../../widgets/app_button.dart';

/// F07 — étape 3 : créneau. Pas de notion de "créneau complet" pour
/// l'instant (pas de modèle de créneaux en back-office, cf.
/// status-V1.md) — tous les créneaux générés sont sélectionnables.
class CheckoutTimeslotScreen extends StatefulWidget {
  const CheckoutTimeslotScreen({super.key});

  @override
  State<CheckoutTimeslotScreen> createState() => _CheckoutTimeslotScreenState();
}

class _CheckoutTimeslotScreenState extends State<CheckoutTimeslotScreen> {
  late final List<TimeSlot> _slots;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _slots = generateTimeSlots(DateTime.now());
    _selected = context.read<CheckoutState>().slotStart;
  }

  void _continue() {
    final selected = _selected;
    if (selected == null) return;
    context.read<CheckoutState>().setSlot(selected);
    context.push('/cart/checkout/summary');
  }

  @override
  Widget build(BuildContext context) {
    final todaySlots = _slots.where((s) => s.isToday).toList();
    final tomorrowSlots = _slots.where((s) => !s.isToday).toList();

    return Scaffold(
      appBar: AppBar(title: Text('screens.CheckoutTimeslot.title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    if (todaySlots.isNotEmpty) ...[
                      Text('checkout.today'.tr(), style: Theme.of(context).textTheme.titleMedium),
                      for (final slot in todaySlots) _slotTile(slot),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text('checkout.tomorrow'.tr(), style: Theme.of(context).textTheme.titleMedium),
                    for (final slot in tomorrowSlots) _slotTile(slot),
                  ],
                ),
              ),
              AppButton(label: 'common.continue'.tr(), onPressed: _selected == null ? null : _continue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotTile(TimeSlot slot) {
    return RadioListTile<DateTime>(
      value: slot.start,
      groupValue: _selected,
      onChanged: (value) => setState(() => _selected = value),
      title: Text(formatSlotRange(slot.start, slot.end)),
    );
  }
}
