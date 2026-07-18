// Vérifie que les traductions FR/AR sont complètes et synchronisées.
// Lancer avec : flutter test test/translations_completeness_test.dart
//
// C'est le point centralisé pour détecter des traductions manquantes :
// si ce test passe, aucune clé n'est utilisée dans le code sans entrée
// i18n, et fr.json / ar.json ont exactement les mêmes clés (pas de dérive
// entre les deux langues au fil des ajouts).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _loadJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Aplati un JSON imbriqué en clés en points : {"a": {"b": "x"}} -> {"a.b": "x"}
Set<String> _flattenKeys(Map<String, dynamic> json, [String prefix = '']) {
  final keys = <String>{};
  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      keys.addAll(_flattenKeys(value, path));
    } else {
      keys.add(path);
    }
  });
  return keys;
}

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Clés utilisées via `'chemin.vers.la.cle'.tr()` (littéraux uniquement —
/// les clés construites dynamiquement, ex. `'screens.$screenKey.title'`,
/// ne sont pas capturées ici et doivent être vérifiées séparément).
Set<String> _staticTrKeysUsedInCode() {
  final pattern = RegExp(r"'([a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+)+)'\.tr\(\)");
  final keys = <String>{};
  for (final file in _dartFiles()) {
    for (final match in pattern.allMatches(file.readAsStringSync())) {
      keys.add(match.group(1)!);
    }
  }
  return keys;
}

/// Valeurs de `screenKey: '...'` passées à `ScreenPlaceholder`.
Set<String> _screenKeysUsedInCode() {
  final pattern = RegExp(r"screenKey:\s*'([^']+)'");
  final keys = <String>{};
  for (final file in _dartFiles()) {
    for (final match in pattern.allMatches(file.readAsStringSync())) {
      keys.add(match.group(1)!);
    }
  }
  return keys;
}

void main() {
  final frKeys = _flattenKeys(_loadJson('assets/translations/fr.json'));
  final arKeys = _flattenKeys(_loadJson('assets/translations/ar.json'));

  test('fr.json et ar.json ont exactement les mêmes clés', () {
    final onlyInFr = frKeys.difference(arKeys);
    final onlyInAr = arKeys.difference(frKeys);
    expect(onlyInFr, isEmpty, reason: 'Présentes en FR, absentes en AR : $onlyInFr');
    expect(onlyInAr, isEmpty, reason: 'Présentes en AR, absentes en FR : $onlyInAr');
  });

  test("toutes les clés statiques 'x.y.z'.tr() du code existent dans fr.json/ar.json", () {
    final used = _staticTrKeysUsedInCode();
    expect(used, isNotEmpty, reason: 'Aucune clé détectée — le pattern de scan a probablement un problème');
    final missingFr = used.difference(frKeys);
    final missingAr = used.difference(arKeys);
    expect(missingFr, isEmpty, reason: 'Clés utilisées dans le code mais absentes de fr.json : $missingFr');
    expect(missingAr, isEmpty, reason: 'Clés utilisées dans le code mais absentes de ar.json : $missingAr');
  });

  test('tous les screenKey utilisés ont un title + subtitle en FR et AR', () {
    final screenKeys = _screenKeysUsedInCode();
    expect(screenKeys, isNotEmpty, reason: 'Aucun screenKey détecté — le pattern de scan a probablement un problème');
    final missing = <String>[];
    for (final key in screenKeys) {
      for (final field in ['title', 'subtitle']) {
        final path = 'screens.$key.$field';
        if (!frKeys.contains(path)) missing.add('FR: $path');
        if (!arKeys.contains(path)) missing.add('AR: $path');
      }
    }
    expect(missing, isEmpty, reason: 'Entrées screens.* manquantes : $missing');
  });
}
