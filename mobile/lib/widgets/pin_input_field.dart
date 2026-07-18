import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../validation/validators.dart';

/// Champ de saisie PIN réutilisable (6 à 12 chiffres — voir
/// `validation/validators.dart` pour la note sur cet écart avec les specs).
/// Masqué par défaut avec bascule de visibilité (plus long qu'un PIN à 4
/// chiffres, donc plus sujet aux fautes de frappe si totalement masqué).
class PinInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelKey;
  final ValueChanged<String>? onChanged;

  const PinInputField({
    super.key,
    required this.controller,
    required this.labelKey,
    this.onChanged,
  });

  @override
  State<PinInputField> createState() => _PinInputFieldState();
}

class _PinInputFieldState extends State<PinInputField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      maxLength: kPinMaxLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.labelKey.tr(),
        helperText: 'auth.pinHint'.tr(),
        counterText: '',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
