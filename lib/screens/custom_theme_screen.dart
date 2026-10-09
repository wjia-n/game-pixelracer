import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pixel_themes.dart';

/// Custom theme creator (Pro): pick colors for the whole pixel palette.
class CustomThemeScreen extends StatefulWidget {
  final RacerAudio audio;
  final RacerSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  RacerSettings get s => widget.settings;

  static const _swatches = [
    0xFFE0392B, 0xFFD96C2B, 0xFFF2A03D, 0xFFFFD35E,
    0xFF2BA84A, 0xFF7BC96F, 0xFF5EC8F2, 0xFF2B6CE0,
    0xFF9B59B6, 0xFFFF6FA5, 0xFFF5EFE0, 0xFF4A4A4A,
    0xFF1E1E26, 0xFF5FA04A, 0xFF8A6A45, 0xFFBFE0EA,
  ];

  static const _keys = [
    'grass', 'grassDark', 'track', 'trackEdge', 'startLine',
    'panel', 'panelEdge', 'accent', 'accentDark', 'text', 'muted',
    'pc0', 'pc1', 'pc2', 'pc3',
  ];

  static const _labels = {
    'grass': 'Terrain',
    'grassDark': 'Terrain shade',
    'track': 'Road',
    'trackEdge': 'Road edge',
    'startLine': 'Start line',
    'panel': 'Panels',
    'panelEdge': 'Panel border',
    'accent': 'Accent',
    'accentDark': 'Accent shade',
    'text': 'Text',
    'muted': 'Muted text',
    'pc0': 'Car 1',
    'pc1': 'Car 2',
    'pc2': 'Car 3',
    'pc3': 'Car 4',
  };

  String? _editing;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) {
        final theme = PixelThemes.byId('custom', custom: s.customTheme);
        return Scaffold(
          backgroundColor: theme.grassDark,
          appBar: AppBar(
            backgroundColor: theme.panel,
            foregroundColor: theme.text,
            title: Text('MY CREATION',
                style: PixelUi.display(20, theme: theme)),
            actions: [
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  s.resetCustomColors();
                },
                child: Text('RESET',
                    style: TextStyle(
                        color: theme.accent,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live preview: mini track + cars in the custom colors.
                PixelUi.panel(
                  theme: theme,
                  child: SizedBox(
                    height: 130,
                    child: CustomPaint(
                        painter: _PreviewPainter(theme: theme)),
                  ),
                ),
                const SizedBox(height: 14),
                for (final key in _keys)
                  _colorRow(theme, key),
                const SizedBox(height: 18),
                PixelUi.button(
                  theme: theme,
                  text: 'USE THIS THEME',
                  onTap: () {
                    widget.audio.click();
                    s.setTheme('custom');
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _colorRow(PixelTheme theme, String key) {
    final current = s.customColors[key] ?? 0xFF000000;
    final open = _editing == key;
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            widget.audio.click();
            setState(() => _editing = open ? null : key);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.panel,
              border: Border.all(color: theme.panelEdge, width: 3),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(current),
                    border: Border.all(
                        color: Colors.black.withValues(alpha: 0.5),
                        width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_labels[key] ?? key,
                      style: PixelUi.body(15, theme: theme)),
                ),
                Text(open ? '▲' : '▼',
                    style: PixelUi.body(14, theme: theme)),
              ],
            ),
          ),
        ),
        if (open)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.panel,
              border: Border.all(color: theme.panelEdge, width: 3),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sw in _swatches)
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      s.setCustomColor(key, 0xFF000000 | sw);
                      setState(() {});
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF000000 | sw),
                        border: Border.all(
                          color: current == (0xFF000000 | sw)
                              ? Colors.white
                              : Colors.black.withValues(alpha: 0.4),
                          width: current == (0xFF000000 | sw) ? 4 : 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final PixelTheme theme;
  _PreviewPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = theme.grass);
    final cx = size.width / 2, cy = size.height / 2;
    final rx = size.width * 0.33, ry = size.height * 0.30;
    final path = Path();
    for (var i = 0; i <= 48; i++) {
      final a = i / 48 * math.pi * 2;
      final w = 1 + 0.14 * math.sin(2 * a) + 0.07 * math.sin(3 * a + 1);
      final p = Offset(cx + rx * w * math.cos(a), cy + ry * w * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 34
          ..color = theme.trackEdge);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..color = theme.track);
    // Sample cars.
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(cx - 60 + i * 40, cy);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 30, height: 18),
          Paint()..color = theme.carColors[i]);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}
