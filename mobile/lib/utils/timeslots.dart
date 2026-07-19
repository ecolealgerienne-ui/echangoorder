/// F07 — créneaux de retrait/livraison générés côté client : pas de
/// modèle de créneaux en back-office pour l'instant (cf. status-V1.md §
/// Points de vigilance), donc pas de notion de "créneau complet" — juste
/// des fenêtres fixes de 2h, aujourd'hui (celles pas encore passées) et
/// demain, comme le wireframe F07.
class TimeSlot {
  final DateTime start;
  final DateTime end;
  final bool isToday;

  const TimeSlot({required this.start, required this.end, required this.isToday});
}

const _todaySlotHours = [10, 14, 16];
const _tomorrowSlotHours = [9, 11];

List<TimeSlot> generateTimeSlots(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final slots = <TimeSlot>[];

  for (final hour in _todaySlotHours) {
    final start = today.add(Duration(hours: hour));
    if (start.isAfter(now)) {
      slots.add(TimeSlot(start: start, end: start.add(const Duration(hours: 2)), isToday: true));
    }
  }
  final tomorrow = today.add(const Duration(days: 1));
  for (final hour in _tomorrowSlotHours) {
    final start = tomorrow.add(Duration(hours: hour));
    slots.add(TimeSlot(start: start, end: start.add(const Duration(hours: 2)), isToday: false));
  }
  return slots;
}

String formatSlotTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${hour}h$minute';
}

String formatSlotRange(DateTime start, DateTime end) => '${formatSlotTime(start)} - ${formatSlotTime(end)}';
