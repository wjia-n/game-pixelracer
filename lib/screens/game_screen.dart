import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/race_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pixel_themes.dart';
import 'menu_screen.dart' show paintPixelCar;
import 'pro_screen.dart';

const _shareUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.pixelracer';

/// Race screen: renders the engine state, handles steering, and maps engine
/// events to audio + juice (screen shake, particles).
class GameScreen extends StatefulWidget {
  final RacerAudio audio;
  final RacerSettings settings;
  final List<RacerConfig> configs;
  final RaceMode mode;
  final int trackStyle;
  final int difficulty;

  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.configs,
    required this.mode,
    required this.trackStyle,
    required this.difficulty,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _Skid {
  Offset pos;
  double heading;
  double life; // 1 → 0
  _Skid(this.pos, this.heading) : life = 1;
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {
  late final RaceEngine engine;
  StreamSubscription<RaceEvent>? _events;
  final _steer = <int, int>{}; // pointerId -> racerIndex (humans only)
  final _lastX = <int, double>{};
  final _skids = <_Skid>[];
  double _shake = 0;
  bool _resultsShown = false;
  int _playerBestLapMs = 0;

  RacerSettings get s => widget.settings;
  RacerAudio get audio => widget.audio;
  PixelTheme get theme =>
      PixelThemes.byId(s.themeId, custom: s.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine = RaceEngine();
    engine.addListener(_onEngineTick);
    _events = engine.events.listen(_onEvent);
    engine.startRace(
      configs: widget.configs,
      mode: widget.mode,
      trackStyle: widget.trackStyle,
      difficulty: widget.difficulty,
    );
    audio.startGameMusic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding mid-race pauses the engine; music pauses via main.dart.
    if (state == AppLifecycleState.paused &&
        (engine.phase == RacePhase.racing ||
            engine.phase == RacePhase.countdown)) {
      engine.pause();
    }
  }

  void _onEngineTick() {
    if (!mounted) return;
    // Screen shake decay + skid marks + engine pitch follow.
    if (_shake > 0.2) {
      _shake *= 0.88;
    } else {
      _shake = 0;
    }
    var dirty = _shake > 0;
    for (final r in engine.racers) {
      if (r.skidTime > 0 && !r.finished) {
        final back = Offset(math.cos(r.heading), math.sin(r.heading)) * -14;
        _skids.add(_Skid(r.pos + back, r.heading));
        dirty = true;
      }
    }
    if (_skids.isNotEmpty) {
      for (final k in _skids) {
        k.life -= 1 / 120;
      }
      _skids.removeWhere((k) => k.life <= 0);
      if (_skids.length > 220) {
        _skids.removeRange(0, _skids.length - 220);
      }
      dirty = true;
    }
    final human = engine.humans.isNotEmpty ? engine.humans.first : null;
    if (human != null && engine.phase == RacePhase.racing) {
      audio.setEngineSpeed(human.speed / 320);
    }
    if (dirty) setState(() {});
  }

  void _onEvent(RaceEvent e) {
    switch (e.type) {
      case RaceEventType.countBeep:
        audio.countBeep();
        break;
      case RaceEventType.go:
        audio.goBeep();
        audio.startEngine();
        break;
      case RaceEventType.engineRev:
        audio.gameStart();
        break;
      case RaceEventType.lap:
        final r = e.racerIndex >= 0 && e.racerIndex < engine.racers.length
            ? engine.racers[e.racerIndex]
            : null;
        if (r != null && !r.isBot) {
          audio.lap();
          if (e.place > 0 &&
              (_playerBestLapMs == 0 || e.place < _playerBestLapMs)) {
            _playerBestLapMs = e.place;
          }
        }
        break;
      case RaceEventType.driftBoost:
        audio.boost();
        if (e.racerIndex >= 0) _shake = math.max(_shake, 4);
        break;
      case RaceEventType.positionChange:
        final r = e.racerIndex >= 0 && e.racerIndex < engine.racers.length
            ? engine.racers[e.racerIndex]
            : null;
        if (r != null && !r.isBot && e.place < 4) audio.positionUp();
        break;
      case RaceEventType.crash:
        audio.crash();
        _shake = 16;
        break;
      case RaceEventType.finished:
        audio.stopEngine();
        _onFinished();
        break;
    }
  }

  Future<void> _onFinished() async {
    if (_resultsShown) return;
    _resultsShown = true;
    final standings = engine.standings;
    final humanWon = widget.mode == RaceMode.grandPrix &&
        standings.isNotEmpty &&
        !standings.first.isBot;
    if (humanWon) {
      audio.win();
    } else if (widget.mode == RaceMode.grandPrix) {
      audio.lose();
    } else {
      audio.win();
    }
    final human = engine.humans.isNotEmpty ? engine.humans.first : null;
    await s.recordRace(
      humanWon: humanWon,
      lapMs: _playerBestLapMs,
      endlessM: widget.mode == RaceMode.endless && human != null
          ? human.distance.round()
          : 0,
    );
    if (!mounted) return;
    setState(() {});
    // Sensible review moment: after a win, every 3rd race.
    if (humanWon && s.races % 3 == 0) {
      try {
        if (await InAppReview.instance.isAvailable()) {
          await InAppReview.instance.requestReview();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    engine.removeListener(_onEngineTick);
    audio.stopEngine();
    engine.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- steering
  void _onPointerDown(PointerDownEvent e, Size view) {
    if (engine.phase != RacePhase.racing) return;
    final humans = engine.humans;
    if (humans.isEmpty) return;
    int idx;
    if (humans.length == 1) {
      idx = engine.racers.indexOf(humans.first);
    } else {
      idx = engine.racers.indexOf(
          e.localPosition.dx < view.width / 2 ? humans[0] : humans[1]);
    }
    _steer[e.pointer] = idx;
    _lastX[e.pointer] = e.localPosition.dx;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final idx = _steer[e.pointer];
    if (idx == null) return;
    final dx = e.localPosition.dx - (_lastX[e.pointer] ?? e.localPosition.dx);
    _lastX[e.pointer] = e.localPosition.dx;
    engine.steerHuman(idx, dx);
  }

  void _onPointerUp(PointerEvent e) {
    _steer.remove(e.pointer);
    _lastX.remove(e.pointer);
  }

  // ------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (_, _) {
        final finished = engine.phase == RacePhase.finished;
        return Scaffold(
          backgroundColor: theme.grassDark,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _hud(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          final view = Size(c.maxWidth, c.maxHeight);
                          return Listener(
                            onPointerDown: (e) => _onPointerDown(e, view),
                            onPointerMove: _onPointerMove,
                            onPointerUp: _onPointerUp,
                            onPointerCancel: _onPointerUp,
                            child: CustomPaint(
                              size: view,
                              painter: _RacePainter(
                                engine: engine,
                                theme: theme,
                                skids: _skids,
                                shake: _shake,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _hintBar(),
                  ],
                ),
                if (engine.phase == RacePhase.paused) _pauseOverlay(),
                if (finished && _resultsShown) _resultsOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: theme.panel,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              audio.click();
              if (engine.phase == RacePhase.racing ||
                  engine.phase == RacePhase.countdown) {
                engine.pause();
                audio.stopEngine();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.accent,
                border: Border.all(color: theme.panelEdge, width: 2),
              ),
              child: const Text('⏸',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            // Per-racer chips: every driver is visible with live lap/place.
            // The leader's chip pulses; humans get a thick border.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < engine.racers.length; i++)
                    _racerChip(engine.racers[i], i),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _racerChip(RacerState r, int i) {
    final isLeader = engine.mode == RaceMode.grandPrix && r.place == 1 && !r.finished ||
        (engine.mode == RaceMode.grandPrix && r.lastPlace == 1);
    final label = widget.mode == RaceMode.endless
        ? '${r.distance.round()}m${r.crashes > 0 ? ' 💥${r.crashes}' : ''}'
        : 'L${r.lap.clamp(1, RaceEngine.lapsToWin)}/${RaceEngine.lapsToWin}'
            '${r.finished ? ' 🏁P${r.place}' : (widget.mode == RaceMode.grandPrix ? ' P${r.place == 0 ? '–' : r.place}' : '')}';
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLeader ? theme.accent : theme.panel,
        border: Border.all(
            color: r.isBot ? theme.panelEdge : Colors.white,
            width: r.isBot ? 2 : 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 12,
              height: 12,
              color: theme.carColors[r.carColorIndex % 4]),
          const SizedBox(width: 6),
          Text(
            '${r.isBot ? '🤖 ' : ''}${r.name} $label',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintBar() {
    final text = widget.mode == RaceMode.endless
        ? 'Drag sideways to steer · 3 crashes ends the run!'
        : 'Drag sideways to steer · drift hard for boost! 💨';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: theme.panel,
      child: Text(text,
          textAlign: TextAlign.center,
          style: PixelUi.label(12, theme: theme)),
    );
  }

  Widget _pauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: PixelUi.panel(
          theme: theme,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PAUSED', style: PixelUi.display(34, theme: theme)),
              const SizedBox(height: 18),
              PixelUi.button(
                  theme: theme,
                  text: 'RESUME',
                  onTap: () {
                    audio.click();
                    engine.resume();
                    if (engine.phase == RacePhase.racing) {
                      audio.startEngine();
                    }
                  }),
              const SizedBox(height: 12),
              PixelUi.button(
                  theme: theme,
                  text: 'RESTART',
                  color: theme.panelEdge,
                  onTap: () {
                    audio.click();
                    _resultsShown = false;
                    _playerBestLapMs = 0;
                    _skids.clear();
                    engine.startRace(
                      configs: widget.configs,
                      mode: widget.mode,
                      trackStyle: widget.trackStyle,
                      difficulty: widget.difficulty,
                    );
                    audio.startGameMusic();
                  }),
              if (widget.mode == RaceMode.endless) ...[
                const SizedBox(height: 12),
                PixelUi.button(
                    theme: theme,
                    text: 'END RUN',
                    color: const Color(0xFFB98A2B),
                    onTap: () {
                      audio.click();
                      engine.endRun();
                    }),
              ],
              const SizedBox(height: 12),
              PixelUi.button(
                  theme: theme,
                  text: 'QUIT',
                  color: const Color(0xFF7A2E22),
                  onTap: () {
                    audio.click();
                    Navigator.of(context).pop();
                  }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultsOverlay() {
    final standings = engine.standings;
    final human = engine.humans.isNotEmpty ? engine.humans.first : null;
    String headline;
    if (widget.mode == RaceMode.endless) {
      headline = '🏁 RUN OVER — ${human?.distance.round() ?? 0}m!';
    } else if (widget.mode == RaceMode.timeTrial) {
      headline = '⏱️ TIME TRIAL DONE!';
    } else {
      final won = standings.isNotEmpty && !standings.first.isBot;
      final place = human?.place ?? 0;
      headline = won
          ? '🏆 YOU WIN!'
          : (place == 2
              ? '🥈 P2 — SO CLOSE!'
              : (place == 3 ? '🥉 P3 — PODIUM!' : '🏁 P$place — FINISH!'));
    }
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: SingleChildScrollView(
          child: PixelUi.panel(
            theme: theme,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(headline,
                    textAlign: TextAlign.center,
                    style: PixelUi.display(28, theme: theme)),
                const SizedBox(height: 12),
                for (final r in standings)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.place == 1
                              ? '🥇'
                              : (r.place == 2
                                  ? '🥈'
                                  : (r.place == 3 ? '🥉' : '  ${r.place}.')),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Container(
                            width: 16,
                            height: 16,
                            color:
                                theme.carColors[r.carColorIndex % 4]),
                        const SizedBox(width: 8),
                        Text(
                          '${r.isBot ? '🤖 ' : ''}${r.name}',
                          style: PixelUi.body(16,
                              theme: theme,
                              color: r.isBot
                                  ? theme.muted
                                  : theme.text),
                        ),
                        if (r.bestLap > 0)
                          Text('  ·  ${_fmtSecs(r.bestLap)}',
                              style: PixelUi.label(12, theme: theme)),
                      ],
                    ),
                  ),
                if (_playerBestLapMs > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Your best lap: ${_fmtMs(_playerBestLapMs)}'
                      '${s.bestLapMs > 0 ? '  (all-time ${_fmtMs(s.bestLapMs)})' : ''}',
                      style: PixelUi.label(13, theme: theme),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    PixelUi.button(
                        theme: theme,
                        text: 'RACE AGAIN',
                        small: true,
                        onTap: () {
                          audio.click();
                          _resultsShown = false;
                          _playerBestLapMs = 0;
                          _skids.clear();
                          engine.startRace(
                            configs: widget.configs,
                            mode: widget.mode,
                            trackStyle: widget.trackStyle,
                            difficulty: widget.difficulty,
                          );
                          audio.startGameMusic();
                        }),
                    PixelUi.button(
                        theme: theme,
                        text: 'SHARE',
                        small: true,
                        color: const Color(0xFF2B6CE0),
                        onTap: () {
                          audio.click();
                          Share.share(
                              'I just raced in Pixel Racer! Tiny cars, massive drifts — try to beat me: $_shareUrl');
                        }),
                    if (!s.isPro)
                      PixelUi.button(
                          theme: theme,
                          text: 'GET PRO',
                          small: true,
                          color: const Color(0xFFB98A2B),
                          onTap: () {
                            audio.click();
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ProScreen(
                                    audio: audio, settings: s)));
                          }),
                    PixelUi.button(
                        theme: theme,
                        text: 'MENU',
                        small: true,
                        color: theme.panelEdge,
                        onTap: () {
                          audio.click();
                          Navigator.of(context).pop();
                        }),
                  ],
                ),
              ],
            ),
          ),
        ),
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

String _fmtSecs(double secs) {
  return _fmtMs((secs * 1000).round());
}

/// Renders the track, skid marks, cars, countdown — in 1000x1000 virtual
/// space scaled to fit the canvas.
class _RacePainter extends CustomPainter {
  final RaceEngine engine;
  final PixelTheme theme;
  final List<_Skid> skids;
  final double shake;

  _RacePainter({
    required this.engine,
    required this.theme,
    required this.skids,
    required this.shake,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (engine.trackPoints.isEmpty) return;
    final scale = math.min(size.width, size.height) / 1000;
    canvas.save();
    // Screen shake on crashes / boosts.
    if (shake > 0.2) {
      canvas.translate(
        (math.Random().nextDouble() - 0.5) * shake,
        (math.Random().nextDouble() - 0.5) * shake,
      );
    }
    canvas.translate(
        (size.width - 1000 * scale) / 2, (size.height - 1000 * scale) / 2);
    canvas.scale(scale);

    // Grass: chunky pixel checkerboard.
    const cell = 62.5;
    for (var gx = 0; gx < 16; gx++) {
      for (var gy = 0; gy < 16; gy++) {
        canvas.drawRect(
          Rect.fromLTWH(gx * cell, gy * cell, cell, cell),
          Paint()
            ..color =
                (gx + gy).isEven ? theme.grass : theme.grassDark,
        );
      }
    }

    final loop = Path()..moveTo(
        engine.trackPoints[0].dx, engine.trackPoints[0].dy);
    for (var i = 1; i < engine.trackPoints.length; i++) {
      loop.lineTo(engine.trackPoints[i].dx, engine.trackPoints[i].dy);
    }
    loop.close();

    // Track: edge kerb, asphalt, center dashes.
    canvas.drawPath(
        loop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 128
          ..color = theme.trackEdge);
    canvas.drawPath(
        loop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 112
          ..color = theme.track);
    // Kerb stripes: short perpendicular ticks around the edge.
    for (var i = 0; i < engine.trackPoints.length; i += 14) {
      final p = engine.trackPoints[i];
      final q = engine.trackPoints[(i + 4) % engine.trackPoints.length];
      final dir = q - p;
      final len = dir.distance == 0 ? 1 : dir.distance;
      final n = Offset(-dir.dy / len, dir.dx / len);
      canvas.drawRect(
        Rect.fromCenter(center: p + n * 62, width: 14, height: 10),
        Paint()
          ..color = (i ~/ 14).isEven
              ? const Color(0xFFE0392B)
              : const Color(0xFFF5EFE0),
      );
      canvas.drawRect(
        Rect.fromCenter(center: p - n * 62, width: 14, height: 10),
        Paint()
          ..color = (i ~/ 14).isEven
              ? const Color(0xFFF5EFE0)
              : const Color(0xFFE0392B),
      );
    }
    // Start/finish checkered line.
    final s0 = engine.trackPoints[0];
    final s1 = engine.trackPoints[8];
    final dir = s1 - s0;
    final len = dir.distance == 0 ? 1 : dir.distance;
    final n = Offset(-dir.dy / len, dir.dx / len);
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(
        Rect.fromCenter(
            center: s0 + n * (-49 + i * 14), width: 14, height: 16),
        Paint()
          ..color = i.isEven ? theme.startLine : theme.track,
      );
    }

    // Skid marks (fading).
    for (final k in skids) {
      canvas.save();
      canvas.translate(k.pos.dx, k.pos.dy);
      canvas.rotate(k.heading);
      canvas.drawRect(
        const Rect.fromLTWH(-16, -20, 32, 7),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45 * k.life),
      );
      canvas.drawRect(
        const Rect.fromLTWH(-16, 13, 32, 7),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45 * k.life),
      );
      canvas.restore();
    }

    // Racers: shadow, pixel car, drift charge ring, name flag.
    for (final r in engine.racers) {
      canvas.save();
      canvas.translate(r.pos.dx, r.pos.dy);
      // Crash spin.
      final spin = r.crashTime > 0 ? (0.9 - r.crashTime) * 9 : 0;
      canvas.rotate(r.heading + spin);
      final body = theme.carColors[r.carColorIndex % 4];
      final dark = Color.lerp(body, Colors.black, 0.35)!;
      paintPixelCar(canvas, r.carStyle, body, dark,
          const Color(0xFFBFE0EA));
      // Drift charge ring.
      if (r.driftCharge > 0.15) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width: 64 + r.driftCharge * 10,
              height: 52 + r.driftCharge * 10),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = theme.accent.withValues(alpha: r.driftCharge),
        );
      }
      // Boost flames.
      if (r.boostTime > 0) {
        canvas.drawRect(
          const Rect.fromLTWH(-46, -10, 18, 20),
          Paint()..color = const Color(0xFFF2A03D),
        );
        canvas.drawRect(
          const Rect.fromLTWH(-38, -6, 12, 12),
          Paint()..color = const Color(0xFFFFD35E),
        );
      }
      canvas.restore();
      // Name flag above the car (bots always visible — bot visibility bar).
      final label = r.isBot
          ? '🤖 ${r.name}'
          : (r.finished ? '🏁 ${r.name}' : r.name);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(2, 2)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Counter-rotate not needed at this zoom; draw upright above car.
      tp.paint(canvas,
          Offset(r.pos.dx - tp.width / 2, r.pos.dy - 66));
    }

    // Countdown / GO overlay.
    if (engine.phase == RacePhase.countdown) {
      final label =
          engine.countdown > 0.4 ? '${engine.countdown.ceil()}' : 'GO!';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 150,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(8, 8)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(500 - tp.width / 2, 430 - tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RacePainter old) => true;
}
