import 'package:flutter/material.dart';

/// Design tokens — direction visuelle "Casbah" (voir `docs/design_direction.md`
/// pour la palette complète, la typographie cible et le langage de formes).
/// Chaux d'Alger + portes bleues ; le vert d'origine est conservé comme
/// [secondary] plutôt que remplacé (accessibilité/performance : voir
/// CLAUDE.md § Exigences transversales).
class AppColors {
  static const background = Color(0xFFF1F3F2);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF16232B);
  static const textMuted = Color(0xFF5C6B70);
  static const border = Color(0xFFDDE3E0);

  /// Action principale (CTA) — porte bleue des ruelles de la Casbah.
  static const primary = Color(0xFF1C5271);
  /// Vert hérité de l'ancienne identité — nuance secondaire (succès/confirmé),
  /// pas encore branché sur un composant précis : réservé aux prochaines
  /// passes (statut de commande "Confirmée", F08/F09).
  static const secondary = Color(0xFF1F8A55);
  // Assombri (audit contraste, phase F) : 0xFFD64545 d'origine ne donnait que
  // ~4.4:1 avec du texte blanc dessus (badge "Épuisé", bouton danger),
  // sous le seuil AA (4.5:1) pour du texte < 18px/14px gras. Cette teinte
  // atteint ~5.1:1, tout en restant dans la même famille de rouge.
  static const danger = Color(0xFFD02E2E);
  static const disabled = Color(0xFFC7CBD1);
  // Distinct du bleu primaire et du rouge "Épuisé" — badge Promo (demande
  // utilisateur : une couleur qui le distingue des autres badges/boutons de
  // la tuile produit). Tuile de la Casbah plutôt que l'orange générique
  // d'origine. Assombri (même audit contraste que [danger] ci-dessus) :
  // 0xFFB5622E ne donnait que ~4.4:1 avec du texte blanc ; ~5.3:1 ici.
  static const promo = Color(0xFFA25829);
}

/// Contrepartie sombre de [AppColors] — mêmes rôles, tons ajustés pour le
/// contraste sur fond sombre. Pas encore consommée par les widgets custom
/// (qui référencent [AppColors] directement) : la bascule complète est
/// prévue phase par phase à mesure que chaque écran/composant est retouché
/// (voir `docs/design_direction.md` § Plan de mise à jour, phases B-E). Le
/// chrome Material standard (AppBar, boutons, texte via [ThemeData]) suit
/// déjà [ThemeMode.system] dès cette passe.
class AppColorsDark {
  static const background = Color(0xFF0E1A20);
  static const surface = Color(0xFF16262D);
  static const text = Color(0xFFEDF3F2);
  static const textMuted = Color(0xFFA9B7B9);
  static const border = Color(0xFF243237);
  static const primary = Color(0xFF5B9DBF);
  static const secondary = Color(0xFF3DAE79);
  // Volontairement clair/saturé (pas assombri comme [AppColors.danger]) :
  // ce ton sert surtout de texte/icône sur fond sombre (~6:1 contre le fond),
  // pas de fond de badge — voir [AppColorTokens.onDanger] pour le texte posé
  // par-dessus un badge/bouton de cette couleur en mode sombre.
  static const danger = Color(0xFFE8746B);
  static const disabled = Color(0xFF3A4A4E);
  static const promo = Color(0xFFD98A54);
}

/// Résolution des tokens de couleur selon le thème courant (clair/sombre)
/// — à utiliser dans les widgets (`AppColorTokens.of(context).primary`,
/// etc.) plutôt que [AppColors]/[AppColorsDark] statiques directement, pour
/// qu'ils suivent `ThemeMode.system` (audit dark mode, phase F — voir
/// `docs/design_direction.md`). Introduit en phase F pour les composants
/// touchés par le chantier design (A-E) ; le reste de l'app migre au fur
/// et à mesure qu'un écran est retouché.
class AppColorTokens {
  final Color background;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color danger;
  final Color disabled;
  final Color promo;
  // Couleur de texte/icône à poser SUR un fond [danger]/[promo] (badge
  // "Épuisé"/"Promo", bouton danger) — distincte de [danger]/[promo]
  // eux-mêmes car ces derniers servent aussi de texte/icône sur fond
  // neutre, un rôle qui demande la relation de contraste inverse (audit
  // WCAG, phase F ; voir commentaires sur [AppColors.danger]/[promo] et
  // [AppColorsDark.danger] ci-dessus). Clair : blanc, sûr une fois les
  // fonds assombris. Sombre : encre foncée, ces fonds étant volontairement
  // clairs en mode sombre.
  final Color onDanger;
  final Color onPromo;

  const AppColorTokens._({
    required this.background,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.danger,
    required this.disabled,
    required this.promo,
    required this.onDanger,
    required this.onPromo,
  });

  static const _light = AppColorTokens._(
    background: AppColors.background,
    surface: AppColors.surface,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    border: AppColors.border,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    danger: AppColors.danger,
    disabled: AppColors.disabled,
    promo: AppColors.promo,
    onDanger: AppColors.surface,
    onPromo: AppColors.surface,
  );

  static const _dark = AppColorTokens._(
    background: AppColorsDark.background,
    surface: AppColorsDark.surface,
    text: AppColorsDark.text,
    textMuted: AppColorsDark.textMuted,
    border: AppColorsDark.border,
    primary: AppColorsDark.primary,
    secondary: AppColorsDark.secondary,
    danger: AppColorsDark.danger,
    disabled: AppColorsDark.disabled,
    promo: AppColorsDark.promo,
    onDanger: AppColors.text,
    onPromo: AppColors.text,
  );

  static AppColorTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Accessibilité : police min 14px, boutons min 44px de hauteur (specs §4.2).
class AppLayout {
  static const minTouchHeight = 44.0;
  static const radius = 12.0;
}

/// Langage de formes Casbah : coin supérieur prononcé, inférieur discret —
/// clin d'œil à l'arc en fer à cheval mauresque. Réservé aux conteneurs
/// pleine largeur (en-têtes, feuille de panier/checkout — phase D), pas aux
/// petites cartes qui gardent [AppLayout.radius] uniforme.
class AppShape {
  static const archTop = BorderRadius.only(
    topLeft: Radius.circular(30),
    topRight: Radius.circular(30),
    bottomLeft: Radius.circular(10),
    bottomRight: Radius.circular(10),
  );
}

/// Ombres — profondeur légère pour détacher les cartes du fond chaux
/// (constat initial : cartes blanches sur fond blanc, aucun relief).
/// Teintée vers l'encre plutôt qu'un noir neutre générique.
class AppElevation {
  static const card = [
    BoxShadow(color: Color(0x1A16232B), blurRadius: 18, offset: Offset(0, 8)),
  ];
  static const cardDark = [
    BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 10)),
  ];

  /// Variante à utiliser dans les widgets (suit `ThemeMode.system`, phase F).
  static List<BoxShadow> of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cardDark : card;
}

/// Durées/courbes d'animation standard — à réutiliser pour toute micro-
/// interaction (ajout au panier, transitions de feuilles) plutôt que des
/// valeurs ad hoc par écran.
class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}

/// Police d'affichage (titres uniquement — le corps de texte reste la
/// police système, FR comme AR, pour ne pas complexifier le rendu RTL sur
/// les écrans denses). Cible : "Lora" (latin) + "El Messiri" (arabe),
/// deux familles distinctes déclarées séparément et reliées par
/// `fontFamilyFallback` — Flutter ne fusionne pas deux polices de scripts
/// différents sous un seul nom de famille, contrairement à un simple jeu
/// de graisses d'une même police. Voir `docs/design_direction.md` pour les
/// instructions d'ajout en asset local (ce sandbox n'a pas accès réseau
/// pour récupérer les fichiers). Tant qu'elles ne sont pas déclarées dans
/// `pubspec.yaml`, ces noms de famille ne résolvent à rien et Flutter
/// retombe silencieusement sur la police système par défaut — aucun risque
/// de casse en attendant.
const _displayFontFamily = 'CasbahDisplay';
const _displayFontFamilyArabic = 'CasbahDisplayArabic';

ThemeData buildAppTheme() => _buildTheme(brightness: Brightness.light);

ThemeData buildAppDarkTheme() => _buildTheme(brightness: Brightness.dark);

ThemeData _buildTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? AppColorsDark.background : AppColors.background;
  final surface = isDark ? AppColorsDark.surface : AppColors.surface;
  final text = isDark ? AppColorsDark.text : AppColors.text;
  final textMuted = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
  final primary = isDark ? AppColorsDark.primary : AppColors.primary;
  final secondary = isDark ? AppColorsDark.secondary : AppColors.secondary;
  final danger = isDark ? AppColorsDark.danger : AppColors.danger;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: secondary,
      error: danger,
      surface: surface,
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontFamily: _displayFontFamily,
        fontFamilyFallback: const [_displayFontFamilyArabic],
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleMedium: TextStyle(
        fontFamily: _displayFontFamily,
        fontFamilyFallback: const [_displayFontFamilyArabic],
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: text),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: surface,
        minimumSize: const Size.fromHeight(AppLayout.minTouchHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary),
        minimumSize: const Size.fromHeight(AppLayout.minTouchHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radius)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      elevation: 0,
    ),
  );
}
