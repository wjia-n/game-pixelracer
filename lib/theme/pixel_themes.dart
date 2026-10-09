import 'package:flutter/material.dart';

/// Pixel-art arcade art direction: chunky pixels, warm physical toy feel,
/// hard pixel edges. NO neon glow, NO cyberpunk — this is the game's identity.
///
/// A [PixelTheme] is a full palette the whole app reads from. Free themes are
/// always selectable; Pro themes and the custom creator need a Pro unlock.
class PixelTheme {
  final String id;
  final String name;
  final bool pro;

  // Track + world colors.
  final Color grass; // surrounding terrain
  final Color grassDark; // terrain shadow rows
  final Color track; // road surface
  final Color trackEdge; // road border / kerb
  final Color startLine;

  // UI colors.
  final Color panel; // cards / sheets
  final Color panelEdge; // chunky pixel border
  final Color accent; // primary action color
  final Color accentDark;
  final Color text;
  final Color muted;
  final Color danger;

  // Racer colors for seats 0..3.
  final List<Color> carColors;
  final List<String> carColorNames;

  const PixelTheme({
    required this.id,
    required this.name,
    required this.pro,
    required this.grass,
    required this.grassDark,
    required this.track,
    required this.trackEdge,
    required this.startLine,
    required this.panel,
    required this.panelEdge,
    required this.accent,
    required this.accentDark,
    required this.text,
    required this.muted,
    required this.danger,
    required this.carColors,
    required this.carColorNames,
  });
}

/// 12+ car body styles drawn by the painter. Indices 4+ are Pro-locked.
class CarStyles {
  static const names = [
    'Coupe',
    'Formula',
    'Muscle',
    'Hot Rod',
    'Pickup',
    'Buggy',
    'Lowrider',
    'Speedster',
  ];
  static const int count = 8;
  static const int freeCount = 4; // 0..3 free, 4..7 Pro
  static bool isPro(int i) => i >= freeCount && i < count;
  static const String customId = 'custom';
}

/// 8 track shapes (parametric loop variants). Indices 4+ are Pro-locked.
class TrackStyles {
  static const names = [
    'Oval Park',
    'Kidney Loop',
    'Hairpin Pass',
    'Snake Run',
    'Figure-Eight',
    'Desert Rally',
    'Frozen Lake',
    'Grand Circuit',
  ];
  static const int count = 8;
  static const int freeCount = 4;
  static bool isPro(int i) => i >= freeCount && i < count;
}

/// The 12-theme catalog. Pixel-palettes only; each theme is a real palette
/// swap, not a different art style.
class PixelThemes {
  static const _carNames = ['One', 'Two', 'Three', 'Four'];

  static const List<PixelTheme> all = [
    PixelTheme(
      id: 'arcade_classic',
      name: 'Arcade Classic',
      pro: false,
      grass: Color(0xFF5FA04A),
      grassDark: Color(0xFF4C8439),
      track: Color(0xFF4A4A4A),
      trackEdge: Color(0xFFE8E0C8),
      startLine: Color(0xFFFFFFFF),
      panel: Color(0xFF3A2E22),
      panelEdge: Color(0xFF201712),
      accent: Color(0xFFE0392B),
      accentDark: Color(0xFFA32418),
      text: Color(0xFFF5EFE0),
      muted: Color(0xFFB9AE97),
      danger: Color(0xFFFF5544),
      carColors: [
        Color(0xFFE0392B),
        Color(0xFF2B6CE0),
        Color(0xFF2BA84A),
        Color(0xFFE0A52B),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'desert_dust',
      name: 'Desert Dust',
      pro: false,
      grass: Color(0xFFE0B76A),
      grassDark: Color(0xFFC99F54),
      track: Color(0xFF8A6A45),
      trackEdge: Color(0xFF5E452B),
      startLine: Color(0xFFFFF4DC),
      panel: Color(0xFF5A3F22),
      panelEdge: Color(0xFF382612),
      accent: Color(0xFFD96C2B),
      accentDark: Color(0xFFA34E1C),
      text: Color(0xFFFFF4DC),
      muted: Color(0xFFC8A87E),
      danger: Color(0xFFFF4444),
      carColors: [
        Color(0xFFC0392B),
        Color(0xFF2980B9),
        Color(0xFF27AE60),
        Color(0xFFF39C12),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'cotton_candy',
      name: 'Cotton Candy',
      pro: false,
      grass: Color(0xFFF2A9C4),
      grassDark: Color(0xFFD98AA6),
      track: Color(0xFF7B6BC4),
      trackEdge: Color(0xFFFFFFFF),
      startLine: Color(0xFFFFF4DC),
      panel: Color(0xFF5E4A8A),
      panelEdge: Color(0xFF3A2C5E),
      accent: Color(0xFFFF6FA5),
      accentDark: Color(0xFFC94F7E),
      text: Color(0xFFFFF4FA),
      muted: Color(0xFFD9B8CC),
      danger: Color(0xFFFF3344),
      carColors: [
        Color(0xFFFF6FA5),
        Color(0xFF5EC8F2),
        Color(0xFF7DE07D),
        Color(0xFFFFD35E),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'midnight_asphalt',
      name: 'Midnight Asphalt',
      pro: false,
      grass: Color(0xFF2E4A5E),
      grassDark: Color(0xFF243B4C),
      track: Color(0xFF1E1E26),
      trackEdge: Color(0xFF8A94A6),
      startLine: Color(0xFFF5EFE0),
      panel: Color(0xFF23232E),
      panelEdge: Color(0xFF101016),
      accent: Color(0xFFF2A03D),
      accentDark: Color(0xFFB97224),
      text: Color(0xFFF5EFE0),
      muted: Color(0xFF9AA0B4),
      danger: Color(0xFFFF5544),
      carColors: [
        Color(0xFFF2A03D),
        Color(0xFF4A90E2),
        Color(0xFF50C878),
        Color(0xFFE05E7B),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'forest_trail',
      name: 'Forest Trail',
      pro: false,
      grass: Color(0xFF3E7A3E),
      grassDark: Color(0xFF2F6230),
      track: Color(0xFF6B5233),
      trackEdge: Color(0xFF3E3222),
      startLine: Color(0xFFF5EFE0),
      panel: Color(0xFF2E4028),
      panelEdge: Color(0xFF17210F),
      accent: Color(0xFF7BC96F),
      accentDark: Color(0xFF4E9A44),
      text: Color(0xFFF0F5E8),
      muted: Color(0xFFA8BC9C),
      danger: Color(0xFFFF5544),
      carColors: [
        Color(0xFFE0392B),
        Color(0xFF2B6CE0),
        Color(0xFFF2D13D),
        Color(0xFF9B59B6),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'retro_crt',
      name: 'Retro CRT',
      pro: false,
      grass: Color(0xFF0F380F),
      grassDark: Color(0xFF0B2A0B),
      track: Color(0xFF306230),
      trackEdge: Color(0xFF8BAC0F),
      startLine: Color(0xFF9BBC0F),
      panel: Color(0xFF0F380F),
      panelEdge: Color(0xFF071907),
      accent: Color(0xFF9BBC0F),
      accentDark: Color(0xFF6E8A0B),
      text: Color(0xFF9BBC0F),
      muted: Color(0xFF5E7A0F),
      danger: Color(0xFFE0392B),
      carColors: [
        Color(0xFF9BBC0F),
        Color(0xFF306230),
        Color(0xFFE0E0E0),
        Color(0xFFE0392B),
      ],
      carColorNames: _carNames,
    ),
    // ---------------- Pro themes ----------------
    PixelTheme(
      id: 'sunset_blvd',
      name: 'Sunset Blvd',
      pro: true,
      grass: Color(0xFFC96A4A),
      grassDark: Color(0xFFA95438),
      track: Color(0xFF4A3A5E),
      trackEdge: Color(0xFFF2A03D),
      startLine: Color(0xFFFFF4DC),
      panel: Color(0xFF4A2E3A),
      panelEdge: Color(0xFF2A1722),
      accent: Color(0xFFFF8C42),
      accentDark: Color(0xFFC96A2B),
      text: Color(0xFFFFF4DC),
      muted: Color(0xFFD9A88E),
      danger: Color(0xFFFF3344),
      carColors: [
        Color(0xFFFF8C42),
        Color(0xFF9B59B6),
        Color(0xFF4A90E2),
        Color(0xFF50C878),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'volcano',
      name: 'Volcano Run',
      pro: true,
      grass: Color(0xFF3A2320),
      grassDark: Color(0xFF2A1917),
      track: Color(0xFF5A2E1E),
      trackEdge: Color(0xFFE0392B),
      startLine: Color(0xFFFFD35E),
      panel: Color(0xFF2E1A16),
      panelEdge: Color(0xFF160B09),
      accent: Color(0xFFFF5E2B),
      accentDark: Color(0xFFB93E1B),
      text: Color(0xFFFFE8D6),
      muted: Color(0xFFB98A74),
      danger: Color(0xFFFF2222),
      carColors: [
        Color(0xFFFF5E2B),
        Color(0xFFFFD35E),
        Color(0xFF8A2B1E),
        Color(0xFFB9B9B9),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'frozen_lake',
      name: 'Frozen Lake',
      pro: true,
      grass: Color(0xFFBFE0EA),
      grassDark: Color(0xFFA2C8D8),
      track: Color(0xFF6A8AA0),
      trackEdge: Color(0xFFFFFFFF),
      startLine: Color(0xFF1E2E3A),
      panel: Color(0xFF2E4A5E),
      panelEdge: Color(0xFF17262E),
      accent: Color(0xFF5EC8F2),
      accentDark: Color(0xFF3A92B8),
      text: Color(0xFFF4FBFF),
      muted: Color(0xFFA8C4D4),
      danger: Color(0xFFFF5544),
      carColors: [
        Color(0xFFE0392B),
        Color(0xFF1E5AA8),
        Color(0xFF7DE07D),
        Color(0xFFFFD35E),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'graveyard',
      name: 'Graveyard Shift',
      pro: true,
      grass: Color(0xFF3A3A4A),
      grassDark: Color(0xFF2C2C38),
      track: Color(0xFF5E5E6E),
      trackEdge: Color(0xFF9B59B6),
      startLine: Color(0xFFF5EFE0),
      panel: Color(0xFF26262E),
      panelEdge: Color(0xFF121218),
      accent: Color(0xFF9B59B6),
      accentDark: Color(0xFF6E3E82),
      text: Color(0xFFF0EAF5),
      muted: Color(0xFFA89AB4),
      danger: Color(0xFFFF5544),
      carColors: [
        Color(0xFF9B59B6),
        Color(0xFF50C878),
        Color(0xFFF2A03D),
        Color(0xFFE0E0E0),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'tropical',
      name: 'Tropical GP',
      pro: true,
      grass: Color(0xFF3EC96A),
      grassDark: Color(0xFF2FA854),
      track: Color(0xFF8A6A45),
      trackEdge: Color(0xFFFFF4DC),
      startLine: Color(0xFF1E2E1A),
      panel: Color(0xFF1E4A3A),
      panelEdge: Color(0xFF0F2A20),
      accent: Color(0xFFFFD35E),
      accentDark: Color(0xFFC9A33E),
      text: Color(0xFFFFFBEC),
      muted: Color(0xFFA8D4B8),
      danger: Color(0xFFFF5544),
      carColors: [
        Color(0xFFFFD35E),
        Color(0xFFE0392B),
        Color(0xFF5EC8F2),
        Color(0xFFFF6FA5),
      ],
      carColorNames: _carNames,
    ),
    PixelTheme(
      id: 'monochrome',
      name: 'Monochrome',
      pro: true,
      grass: Color(0xFF9A9A9A),
      grassDark: Color(0xFF7E7E7E),
      track: Color(0xFF4A4A4A),
      trackEdge: Color(0xFFE0E0E0),
      startLine: Color(0xFFFFFFFF),
      panel: Color(0xFF2E2E2E),
      panelEdge: Color(0xFF141414),
      accent: Color(0xFFE0E0E0),
      accentDark: Color(0xFF9A9A9A),
      text: Color(0xFFFFFFFF),
      muted: Color(0xFFB9B9B9),
      danger: Color(0xFFFFFFFF),
      carColors: [
        Color(0xFFE0E0E0),
        Color(0xFF9A9A9A),
        Color(0xFF5E5E5E),
        Color(0xFF2E2E2E),
      ],
      carColorNames: _carNames,
    ),
  ];

  static PixelTheme byId(String id, {PixelTheme? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) =>
      id == 'custom' || all.any((t) => t.id == id && t.pro);
}

/// Pixel chunky styles used by screens (hard edges, 2px "pixel" borders).
class PixelUi {
  static TextStyle display(double size, {required PixelTheme theme}) =>
      TextStyle(
        color: theme.text,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        shadows: [
          Shadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(3, 3)),
        ],
      );

  static TextStyle label(double size,
          {required PixelTheme theme, Color? color}) =>
      TextStyle(
        color: color ?? theme.muted,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      );

  static TextStyle body(double size,
          {required PixelTheme theme, Color? color}) =>
      TextStyle(color: color ?? theme.text, fontSize: size);

  /// A chunky pixel button: flat color, hard 3px border, blocky shadow.
  static Widget button({
    required PixelTheme theme,
    required String text,
    required VoidCallback? onTap,
    Color? color,
    double fontSize = 17,
    bool small = false,
  }) {
    final c = color ?? theme.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 14 : 22, vertical: small ? 8 : 13),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade600 : c,
          border: Border.all(color: theme.panelEdge, width: 3),
          boxShadow: [
            BoxShadow(
                color: theme.panelEdge,
                offset: const Offset(4, 4)),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: const Offset(2, 2)),
            ],
          ),
        ),
      ),
    );
  }

  /// A chunky pixel panel card.
  static Widget panel({
    required PixelTheme theme,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.panel,
        border: Border.all(color: theme.panelEdge, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(4, 4)),
        ],
      ),
      child: child,
    );
  }
}
