import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../engine/race_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pixel_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'name_field.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu: mode + setup + customization + start.
class MenuScreen extends StatefulWidget {
  final RacerAudio audio;
  final RacerSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  RacerSettings get s => widget.settings;
  RacerAudio get audio => widget.audio;
  PixelTheme get theme =>
      PixelThemes.byId(s.themeId, custom: s.customTheme);

  // Draft setup (applied on START).
  late int mode;
  late int difficulty;
  late int aiLevel;
  late int humans;
  late int bots;

  @override
  void initState() {
    super.initState();
    mode = s.mode;
    difficulty = s.difficulty;
    aiLevel = s.aiLevel;
    humans = s.humans;
    bots = s.bots;
    audio.startMenuMusic();
  }

  void _startRace() {
    audio.click();
    s.setSetup(
        mode: mode, difficulty: difficulty, aiLevel: aiLevel, humans: humans, bots: bots);
    final configs = <RacerConfig>[];
    final totalSeats = mode == 1 ? 1 : humans + bots;
    for (var i = 0; i < totalSeats; i++) {
      final isBot = i >= humans;
      configs.add(RacerConfig(
        name: s.playerNames[i],
        isBot: isBot,
        aiLevel: isBot ? aiLevel : 1,
        carColorIndex: i % 4,
        carStyle: s.carStyle,
      ));
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: audio,
          settings: s,
          configs: configs,
          mode: RaceMode.values[mode],
          trackStyle: s.trackStyle,
          difficulty: difficulty,
        ),
      ),
    ).then((_) => audio.startMenuMusic());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) => Scaffold(
        backgroundColor: theme.grassDark,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 14),
                _sectionTitle('RACE MODE'),
                const SizedBox(height: 8),
                _modeRow(),
                const SizedBox(height: 14),
                _sectionTitle('SETUP'),
                const SizedBox(height: 8),
                PixelUi.panel(
                  theme: theme,
                  child: Column(
                    children: [
                      if (mode != 1) ...[
                        _stepper('Human drivers', humans, 1, 2,
                            (v) => setState(() => humans = v)),
                        _stepper(
                            'AI rivals',
                            bots,
                            mode == 0 ? (humans >= 2 ? 0 : 1) : 0,
                            3,
                            (v) => setState(() => bots = v)),
                      ],
                      _choiceRow(
                        'Difficulty',
                        RacerSettings.difficultyNames,
                        difficulty,
                        (v) => setState(() => difficulty = v),
                        proLocked: const [2],
                      ),
                      if (mode != 1)
                        _choiceRow(
                          'AI rivals',
                          RacerSettings.aiLevelNames,
                          aiLevel,
                          (v) => setState(() => aiLevel = v),
                          proLocked: const [2],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionTitle('DRIVERS'),
                const SizedBox(height: 8),
                _namesCard(),
                const SizedBox(height: 14),
                _sectionTitle('THEME'),
                const SizedBox(height: 8),
                _themeGrid(),
                const SizedBox(height: 14),
                _sectionTitle('CAR STYLE'),
                const SizedBox(height: 8),
                _carRow(),
                const SizedBox(height: 14),
                _sectionTitle('TRACK'),
                const SizedBox(height: 8),
                _trackRow(),
                const SizedBox(height: 22),
                PixelUi.button(
                  theme: theme,
                  text: mode == 2 ? 'START CRUISE' : 'START RACE',
                  onTap: _startRace,
                  fontSize: 22,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PixelUi.button(
                        theme: theme,
                        text: s.isPro ? 'PRO ★' : 'GET PRO',
                        color: const Color(0xFFB98A2B),
                        small: true,
                        onTap: () {
                          audio.click();
                          Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (_) => ProScreen(
                                      audio: audio, settings: s)))
                              .then((_) => setState(() {}));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PixelUi.button(
                        theme: theme,
                        text: 'SETTINGS',
                        color: theme.panelEdge,
                        small: true,
                        onTap: () {
                          audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SettingsScreen(
                                  audio: audio, settings: s)));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PixelUi.button(
                        theme: theme,
                        text: 'HOW TO',
                        color: theme.panelEdge,
                        small: true,
                        onTap: () {
                          audio.click();
                          _showHowTo();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    s.races == 0
                        ? 'No races yet — your legend starts now!'
                        : 'Races: ${s.races}   Wins: ${s.wins}'
                            '${s.bestLapMs > 0 ? '   Best lap: ${_fmtMs(s.bestLapMs)}' : ''}'
                            '${s.endlessBestM > 0 ? '   Cruise best: ${s.endlessBestM}m' : ''}',
                    style: PixelUi.label(12, theme: theme),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            border: Border.all(color: theme.panelEdge, width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: const Offset(4, 4)),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Image.asset(
            'assets/pixelracer_logo.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Center(child: Text('🏁', style: TextStyle(fontSize: 32))),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PIXEL RACER', style: PixelUi.display(30, theme: theme)),
              Text('Tiny cars. Massive drifts. Zero mercy.',
                  style: PixelUi.label(12, theme: theme)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: PixelUi.label(14, theme: theme, color: theme.text),
      );

  Widget _modeRow() {
    return Row(
      children: List.generate(3, (i) {
        final selected = mode == i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                left: i == 0 ? 0 : 6, right: i == 2 ? 0 : 6),
            child: GestureDetector(
              onTap: () {
                audio.click();
                setState(() {
                  mode = i;
                  if (i == 0 && humans + bots < 2) bots = 2 - humans;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? theme.accent : theme.panel,
                  border: Border.all(color: theme.panelEdge, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: theme.panelEdge,
                        offset: const Offset(3, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Text(['🏁', '⏱️', '🛣️'][i],
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      RacerSettings.modeNames[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _stepper(
      String label, int value, int min, int max, ValueChanged<int> onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: PixelUi.body(15, theme: theme))),
          _stepBtn('−', value > min, () {
            audio.click();
            onChange(value - 1);
          }),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text('$value',
                style: PixelUi.display(20, theme: theme)),
          ),
          _stepBtn('+', value < max, () {
            audio.click();
            onChange(value + 1);
          }),
        ],
      ),
    );
  }

  Widget _stepBtn(String t, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? theme.accent : Colors.grey.shade600,
          border: Border.all(color: theme.panelEdge, width: 3),
        ),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _choiceRow(String label, List<String> options, int selected,
      ValueChanged<int> onChange,
      {List<int> proLocked = const []}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PixelUi.body(15, theme: theme)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: List.generate(options.length, (i) {
              final sel = selected == i;
              final locked = !s.isPro && proLocked.contains(i);
              return GestureDetector(
                onTap: () {
                  if (locked) {
                    audio.invalid();
                    _nudgePro();
                    return;
                  }
                  audio.click();
                  onChange(i);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? theme.accent : theme.panel,
                    border: Border.all(
                        color: sel ? theme.panelEdge : theme.muted,
                        width: 3),
                  ),
                  child: Text(
                    locked ? '${options[i]} 🔒' : options[i],
                    style: TextStyle(
                      color: locked ? theme.muted : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _nudgePro() {
    Navigator.of(context)
        .push(
            MaterialPageRoute(builder: (_) => ProScreen(audio: audio, settings: s)))
        .then((_) => setState(() {}));
  }

  Widget _namesCard() {
    final seats = mode == 1 ? 1 : humans + bots;
    return PixelUi.panel(
      theme: theme,
      child: Column(
        children: List.generate(seats, (i) {
          final isBot = i >= humans;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  color: theme.carColors[i % 4],
                ),
                const SizedBox(width: 10),
                // Names save on every keystroke and commit on focus loss.
                Expanded(
                  child: DriverNameField(
                    key: ValueKey('driver_$i'),
                    theme: theme,
                    index: i,
                    initial: s.playerNames[i],
                    label: isBot
                        ? 'AI driver ${i - humans + 1} name'
                        : 'Driver ${i + 1} name',
                    onName: (v) => s.setPlayerName(i, v),
                  ),
                ),
                const SizedBox(width: 8),
                Text(isBot ? '🤖' : '🧑',
                    style: const TextStyle(fontSize: 18)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _themeGrid() {
    final themes = PixelThemes.all;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: themes.length + 1, // + custom creator
      itemBuilder: (_, i) {
        if (i == themes.length) return _customTile();
        final t = themes[i];
        final selected = s.themeId == t.id && t.id != 'custom';
        final locked = t.pro && !s.isPro;
        return GestureDetector(
          onTap: () {
            if (locked) {
              audio.invalid();
              _nudgePro();
              return;
            }
            audio.click();
            s.setTheme(t.id);
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.panel,
              border: Border.all(
                  color: selected ? theme.accent : theme.panelEdge,
                  width: selected ? 4 : 3),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: t.grass,
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.4),
                          width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: t.track,
                          border:
                              Border.all(color: t.trackEdge, width: 3),
                        ),
                        child: locked
                            ? const Center(
                                child: Text('🔒',
                                    style: TextStyle(fontSize: 12)))
                            : null,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    t.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: locked ? theme.muted : theme.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _customTile() {
    final selected = s.themeId == 'custom';
    final locked = !s.isPro;
    return GestureDetector(
      onTap: () {
        if (locked) {
          audio.invalid();
          _nudgePro();
          return;
        }
        audio.click();
        Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) =>
                    CustomThemeScreen(audio: audio, settings: s)))
            .then((_) => setState(() {}));
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.panel,
          border: Border.all(
              color: selected ? theme.accent : theme.panelEdge,
              width: selected ? 4 : 3),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(5),
                color: s.customTheme.grass,
                child: Center(
                  child: Text(locked ? '🔒' : '🎨',
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('My Creation',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carRow() {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: CarStyles.count,
        itemBuilder: (_, i) {
          final selected = s.carStyle == i;
          final locked = CarStyles.isPro(i) && !s.isPro;
          return GestureDetector(
            onTap: () {
              if (locked) {
                audio.invalid();
                _nudgePro();
                return;
              }
              audio.click();
              s.setCarStyle(i);
            },
            child: Container(
              width: 84,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.panel,
                border: Border.all(
                    color: selected ? theme.accent : theme.panelEdge,
                    width: selected ? 4 : 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 40,
                    child: CustomPaint(
                        painter: _MiniCarPainter(
                            style: i,
                            color: theme.carColors[0],
                            locked: locked)),
                  ),
                  Text(
                    locked ? '🔒' : CarStyles.names[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: locked ? theme.muted : theme.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _trackRow() {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: TrackStyles.count,
        itemBuilder: (_, i) {
          final selected = s.trackStyle == i;
          final locked = TrackStyles.isPro(i) && !s.isPro;
          return GestureDetector(
            onTap: () {
              if (locked) {
                audio.invalid();
                _nudgePro();
                return;
              }
              audio.click();
              s.setTrackStyle(i);
            },
            child: Container(
              width: 84,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.panel,
                border: Border.all(
                    color: selected ? theme.accent : theme.panelEdge,
                    width: selected ? 4 : 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 52,
                    child: CustomPaint(
                        painter: _MiniTrackPainter(
                            style: i, theme: theme, locked: locked)),
                  ),
                  Text(
                    locked ? '🔒' : TrackStyles.names[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: locked ? theme.muted : theme.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showHowTo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.panel,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: theme.panelEdge, width: 3)),
        title: Text('HOW TO RACE', style: PixelUi.display(22, theme: theme)),
        content: Text(
          '• Your car accelerates on its own — DRAG sideways to steer.\n\n'
          '• Grand Prix: 3 laps, first across the line wins.\n\n'
          '• Drift hard through corners to charge a speed boost — it fires automatically!\n\n'
          '• Time Trial: 3 solo laps, chase your best time.\n\n'
          '• Endless Cruise: how far can you go? 3 crashes ends the run.\n\n'
          '• 2 humans? Left half steers driver 1, right half steers driver 2.',
          style: PixelUi.body(14, theme: theme),
        ),
        actions: [
          TextButton(
            onPressed: () {
              audio.click();
              Navigator.of(context).pop();
            },
            child: Text('GOT IT!',
                style: TextStyle(
                    color: theme.accent,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

String _fmtMs(int ms) {
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final c = (ms % 1000) ~/ 10;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${c.toString().padLeft(2, '0')}';
}

/// Shared pixel-car drawing, reused by the race painter.
void paintPixelCar(
  Canvas canvas,
  int style,
  Color body,
  Color dark,
  Color glass, {
  double scale = 1.0,
}) {
  // Per-style body recipe: (length, width, cabX, cabW, spoiler, wheelR).
  const recipes = [
    [40.0, 24.0, -4.0, 14.0, 0.0, 5.0], // Coupe
    [46.0, 20.0, -8.0, 10.0, 1.0, 4.5], // Formula
    [44.0, 26.0, -6.0, 14.0, 0.0, 6.0], // Muscle
    [42.0, 24.0, -10.0, 12.0, 1.0, 6.5], // Hot Rod
    [48.0, 26.0, 6.0, 12.0, 0.0, 6.0], // Pickup
    [38.0, 26.0, -2.0, 12.0, 0.0, 7.0], // Buggy
    [46.0, 24.0, -4.0, 16.0, 0.0, 4.5], // Lowrider
    [44.0, 22.0, -6.0, 12.0, 1.0, 5.0], // Speedster
  ];
  final r = recipes[style.clamp(0, 7)];
  final len = (r[0] as double) * scale;
  final wid = (r[1] as double) * scale;
  final cabX = (r[2] as double) * scale;
  final cabW = (r[3] as double) * scale;
  final spoiler = (r[4] as double) > 0.5;
  final wheelR = (r[5] as double) * scale;

  final wheel = Paint()..color = const Color(0xFF1E1E1E);
  final hub = Paint()..color = const Color(0xFF9A9A9A);
  // Wheels (chunky squares).
  for (final wx in [-len * 0.30, len * 0.32]) {
    for (final wy in [-wid / 2 - 2 * scale, wid / 2 - 2 * scale]) {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(wx, wy + 2 * scale),
              width: wheelR * 2,
              height: wheelR * 2),
          wheel);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(wx, wy + 2 * scale),
              width: wheelR,
              height: wheelR),
          hub);
    }
  }
  // Shadow.
  canvas.drawRect(
      Rect.fromCenter(
          center: Offset(2 * scale, 3 * scale),
          width: len + 4 * scale,
          height: wid + 4 * scale),
      Paint()..color = const Color(0x55000000));
  // Body.
  canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: len, height: wid),
      Paint()..color = body);
  // Hood shading (rear half darker).
  canvas.drawRect(
      Rect.fromCenter(
          center: Offset(-len * 0.25, 0), width: len * 0.5, height: wid),
      Paint()..color = dark);
  // Cabin / glass.
  canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cabX, 0), width: cabW, height: wid * 0.62),
      Paint()..color = glass);
  // Nose stripe.
  canvas.drawRect(
      Rect.fromCenter(
          center: Offset(len * 0.42, 0), width: 4 * scale, height: wid),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75));
  // Spoiler.
  if (spoiler) {
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(-len * 0.48, 0),
            width: 5 * scale,
            height: wid + 6 * scale),
        Paint()..color = dark);
  }
}

class _MiniCarPainter extends CustomPainter {
  final int style;
  final Color color;
  final bool locked;
  _MiniCarPainter(
      {required this.style, required this.color, required this.locked});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    if (locked) {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: 40, height: 24),
          Paint()..color = const Color(0xFF777777));
      return;
    }
    paintPixelCar(canvas, style, color,
        Color.lerp(color, Colors.black, 0.35)!,
        const Color(0xFFBFE0EA),
        scale: 0.8);
  }

  @override
  bool shouldRepaint(covariant _MiniCarPainter old) => false;
}

class _MiniTrackPainter extends CustomPainter {
  final int style;
  final PixelTheme theme;
  final bool locked;
  _MiniTrackPainter(
      {required this.style, required this.theme, required this.locked});

  @override
  void paint(Canvas canvas, Size size) {
    if (locked) return;
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.38;
    final path = Path();
    for (var i = 0; i <= 60; i++) {
      final a = i / 60 * math.pi * 2;
      final w = 1 +
          [0.1, 0.22, 0.16, 0.2, 0.3, 0.26, 0.13, 0.18][style] *
              math.sin(2 * a + style);
      final p =
          Offset(cx + r * w * math.cos(a), cy + r * w * math.sin(a) * 0.8);
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
          ..strokeWidth = 10
          ..color = theme.track);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.trackEdge);
  }

  @override
  bool shouldRepaint(covariant _MiniTrackPainter old) => false;
}
