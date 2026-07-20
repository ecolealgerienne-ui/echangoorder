import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/odoo_api_client.dart';
import '../../state/checkout_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/timeslots.dart';
import '../../widgets/app_button.dart';

/// F07 — étape 3 : créneau. Capacité par créneau optionnelle
/// (`x_timeslot_capacity`, back-office) : un créneau sans capacité
/// configurée reste toujours sélectionnable (comportement historique).
class CheckoutTimeslotScreen extends StatefulWidget {
  const CheckoutTimeslotScreen({super.key});

  @override
  State<CheckoutTimeslotScreen> createState() => _CheckoutTimeslotScreenState();
}

class _CheckoutTimeslotScreenState extends State<CheckoutTimeslotScreen> {
  late final List<TimeSlot> _slots;
  DateTime? _selected;
  // Ensemble vide tant que la vérification de capacité n'a pas répondu —
  // échec silencieux volontaire (pas d'AppMessenger) : ne bloque jamais la
  // sélection d'un créneau, juste pas de grisage tant que l'info manque.
  Set<DateTime> _fullSlots = {};

  @override
  void initState() {
    super.initState();
    _slots = generateTimeSlots(DateTime.now());
    _selected = context.read<CheckoutState>().slotStart;
    _loadCapacity();
  }

  Future<void> _loadCapacity() async {
    final mode = context.read<CheckoutState>().receptionMode;
    if (mode == null) return;
    try {
      final full = await context.read<OdooApiClient>().fetchFullTimeslots(
            receptionMode: mode == ReceptionMode.delivery ? 'home_delivery' : 'pickup',
            slots: _slots.map((s) => s.start).toList(),
          );
      if (!mounted) return;
      setState(() {
        _fullSlots = full;
        // Le créneau déjà sélectionné (retour en arrière) vient d'être
        // signalé complet entre-temps : désélectionné plutôt que de
        // laisser _continue() confirmer un créneau plein.
        if (_selected != null && full.contains(_selected)) _selected = null;
      });
    } catch (_) {
      // Cf. commentaire sur _fullSlots.
    }
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
          // RadioGroup centralise groupValue/onChanged pour tous les Radio
          // descendants (Radio.groupValue/onChanged individuels dépréciés
          // depuis Flutter 3.32).
          child: RadioGroup<DateTime>(
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
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
      ),
    );
  }

  Widget _slotTile(TimeSlot slot) {
    if (_fullSlots.contains(slot.start)) {
      return ListTile(
        enabled: false,
        title: Text(formatSlotRange(slot.start, slot.end)),
        trailing: Text('errors.checkout.slot_full'.tr(), style: const TextStyle(color: AppColors.textMuted)),
      );
    }
    return RadioListTile<DateTime>(
      value: slot.start,
      title: Text(formatSlotRange(slot.start, slot.end)),
    );
  }
}
