import 'dart:io' show Platform;

/// URL de base du backend Odoo — développement local uniquement.
///
/// - Émulateur Android : `10.0.2.2` est l'alias réseau spécial de
///   l'émulateur vers le "localhost" de la machine hôte (Docker/WSL) —
///   voir la doc Android sur le réseau de l'émulateur.
/// - Simulateur iOS : `localhost` fonctionne directement.
/// - Appareil physique (Android ou iOS) : remplacer par l'adresse IP locale
///   de la machine qui fait tourner Docker/WSL (ex. `192.168.1.x`), les deux
///   appareils devant être sur le même réseau Wi-Fi. `10.0.2.2`/`localhost`
///   ne fonctionnent pas depuis un vrai appareil.
String get odooBaseUrl {
  if (Platform.isAndroid) return 'http://10.0.2.2:8069';
  return 'http://localhost:8069';
}
