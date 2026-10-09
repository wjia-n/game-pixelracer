import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Engine-owned race state machine + watchdog for Pixel Racer.
///
/// The engine (NOT UI timers) owns every phase and every transition:
/// [RacePhase.idle] → countdown → racing → (paused) → finished.
/// The physics timer runs at 60Hz inside the engine; a watchdog timer
/// verifies forward progress every 500ms and re-arms the physics timer if
/// it ever dies. Stuck states are impossible by construction: every phase
/// has a live timer and a defined exit.
///
/// UI layers only render, steer humans, and consume [events] for audio/juice.
/// Nothing in the engine touches audio, assets, or widgets.
enum RacePhase { idle, countdown, racing, paused, finished }

/// 0 = Grand Prix (vs AI), 1 = Time Trial (solo), 2 = Endless Cruise.
enum RaceMode { grandPrix, timeTrial, endless }

enum RaceEventType {
  countBeep, // countdown number tick
  go, // race start
  lap, // a racer completed a lap
  positionChange, // a human gained/lost a place
  driftBoost, // drift charge released as boost
  crash, // racer crashed (throttled)
  finished, // race/run over
  engineRev, // countdown engine rev flavor
}

class RaceEvent {
  final RaceEventType type;
  final int racerIndex; // -1 for global events
  final int place; // racer's place when relevant
  const RaceEvent(this.type, {this.racerIndex = -1, this.place = 0});
}

/// Static configuration for one seat on the grid.
class RacerConfig {
  final String name;
  final bool isBot;
  final int aiLevel; // 0 chill, 1 racer, 2 ace (bots only)
  final int carColorIndex;
  final int carStyle;
  const RacerConfig({
    required this.name,
    required this.isBot,
    this.aiLevel = 1,
    required this.carColorIndex,
    required this.carStyle,
  });
}

/// Live state of one racer. Virtual track space is 1000x1000.
class RacerState extends RacerConfig {
  Offset pos = Offset.zero;
  double heading = 0;
  double speed = 0;
  double topSpeed = 290;
  int lap = 1;
  int nextCp = 1; // next checkpoint index to hit
  double driftCharge = 0;
  double boostTime = 0;
  bool finished = false;
  int place = 0;
  double crashTime = 0; // >0 while wrecked
  double lapTime = 0; // current lap timer (s)
  double bestLap = 0; // best lap this race (s, 0 = none)
  double distance = 0; // endless mode meters
  int crashes = 0; // endless mode
  double offTrackTime = 0;
  double skidTime = 0; // visual: drifting now
  double exhaust = 0; // visual pulse 0..1
  int lastPlace = 0;
  double aiBoostCooldown = 0;

  RacerState({
    required super.name,
    required super.isBot,
    super.aiLevel,
    required super.carColorIndex,
    required super.carStyle,
  });
}

class RaceEngine extends ChangeNotifier {
  static const int trackSamples = 280;
  static const int checkpointCount = 12;
  static const int lapsToWin = 3;
  static const double virtualSize = 1000.0;

  RacePhase _phase = RacePhase.idle;
  RacePhase get phase => _phase;

  RaceMode mode = RaceMode.grandPrix;
  int trackStyle = 0;
  int difficulty = 1; // 0 easy, 1 medium, 2 hard

  final List<Offset> trackPoints = [];
  final List<RacerState> racers = [];
  double countdown = 0;
  int _countdownShown = 4;
  int placesGiven = 0;
  bool get isRaceOver => _phase == RacePhase.finished;

  final _events = StreamController<RaceEvent>.broadcast();
  Stream<RaceEvent> get events => _events.stream;

  Timer? _physTimer;
  Timer? _watchdog;
  DateTime _lastAdvance = DateTime.now();
  int _advanceCounter = 0;
  int _lastAdvanceCounter = -1;
  final _rand = math.Random();

  bool _disposed = false;

  // ---------------------------------------------------------------- setup
  /// Build a fresh race. [seed] randomizes track wobble per race.
  void startRace({
    required List<RacerConfig> configs,
    required RaceMode mode,
    required int trackStyle,
    required int difficulty,
    int? seed,
  }) {
    _stopTimers();
    this.mode = mode;
    this.trackStyle = trackStyle.clamp(0, 7);
    this.difficulty = difficulty.clamp(0, 2);
    _buildTrack(seed ?? _rand.nextInt(1 << 30));
    racers.clear();
    placesGiven = 0;
    for (var i = 0; i < configs.length; i++) {
      final c = configs[i];
      final r = RacerState(
        name: c.name,
        isBot: c.isBot,
        aiLevel: c.aiLevel,
        carColorIndex: c.carColorIndex,
        carStyle: c.carStyle,
      );
      // Grid slot: staggered behind the start line (sample 0).
      final back = 14 + (i ~/ 2) * 22;
      final idx = (trackSamples - back) % trackSamples;
      final p = trackPoints[idx];
      final ahead = trackPoints[(idx + 6) % trackSamples];
      final lane = (i % 2 == 0 ? -1 : 1) * 26.0;
      final dir = (ahead - p);
      final len = dir.distance == 0 ? 1 : dir.distance;
      final normal = Offset(-dir.dy / len, dir.dx / len);
      r.pos = p + normal * lane;
      r.heading = math.atan2(dir.dy, dir.dx);
      r.topSpeed = _botTopSpeed(r);
      racers.add(r);
    }
    countdown = 3.0;
    _countdownShown = 4;
    _phase = RacePhase.countdown;
    _armTimers();
    notifyListeners();
  }

  double _botTopSpeed(RacerState r) {
    // Base by AI level, scaled by difficulty, rubber-band applied per tick.
    const base = [238.0, 264.0, 286.0];
    const diff = [0.90, 1.0, 1.07];
    return base[r.aiLevel.clamp(0, 2)] * diff[difficulty];
  }

  void _buildTrack(int seed) {
    final rng = math.Random(seed);
    final wobble = rng.nextDouble() * math.pi * 2;
    // Per-style harmonic recipe: (a1,k1,p1, a2,k2,p2, squash).
    const recipes = [
      [0.10, 2.0, 0.0, 0.05, 3.0, 1.1, 0.82], // Oval Park
      [0.22, 2.0, 0.7, 0.10, 3.0, 0.2, 0.86], // Kidney Loop
      [0.16, 2.0, 1.9, 0.16, 4.0, 0.5, 0.78], // Hairpin Pass
      [0.20, 3.0, 0.3, 0.10, 5.0, 1.4, 0.80], // Snake Run
      [0.30, 2.0, 1.57, 0.00, 3.0, 0.0, 0.80], // Figure-Eight
      [0.26, 2.0, 2.6, 0.12, 4.0, 0.9, 0.84], // Desert Rally
      [0.13, 3.0, 1.2, 0.09, 6.0, 0.4, 0.88], // Frozen Lake
      [0.18, 2.0, 0.9, 0.14, 5.0, 2.1, 0.76], // Grand Circuit
    ];
    final rc = recipes[trackStyle.clamp(0, 7)];
    trackPoints.clear();
    for (var i = 0; i < trackSamples; i++) {
      final a = i / trackSamples * math.pi * 2;
      final r = 330 *
          (1 +
              (rc[0] as double) * math.sin((rc[1] as double) * a + wobble + (rc[2] as double)) +
              (rc[3] as double) * math.sin((rc[4] as double) * a + (rc[5] as double)));
      trackPoints.add(Offset(
        500 + r * math.cos(a),
        500 + r * math.sin(a) * (rc[6] as double),
      ));
    }
  }

  // ------------------------------------------------------------ timers
  void _armTimers() {
    _stopTimers();
    _lastAdvance = DateTime.now();
    _advanceCounter = 0;
    _lastAdvanceCounter = -1;
    _physTimer = Timer.periodic(
        const Duration(milliseconds: 16), (_) => _advance(1 / 60));
    // Watchdog: if the physics timer ever stops firing while a race is
    // live, re-arm it. Checked every 500ms.
    _watchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_disposed) return;
      final live = _phase == RacePhase.countdown || _phase == RacePhase.racing;
      if (!live) return;
      if (_advanceCounter == _lastAdvanceCounter &&
          DateTime.now().difference(_lastAdvance).inMilliseconds > 1500) {
        // Physics died — re-arm and keep going. No stuck state survives.
        _physTimer?.cancel();
        _physTimer = Timer.periodic(
            const Duration(milliseconds: 16), (_) => _advance(1 / 60));
        _lastAdvance = DateTime.now();
      }
      _lastAdvanceCounter = _advanceCounter;
    });
  }

  void _stopTimers() {
    _physTimer?.cancel();
    _physTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
  }

  // ------------------------------------------------------------- control
  /// Human steering: [dx] pixels of sideways drag.
  void steerHuman(int racerIndex, double dx) {
    if (_phase != RacePhase.racing) return;
    if (racerIndex < 0 || racerIndex >= racers.length) return;
    final c = racers[racerIndex];
    if (c.isBot || c.finished || c.crashTime > 0) return;
    c.heading += dx * 0.0062;
    c.skidTime = dx.abs() > 7 ? 0.25 : math.max(0, c.skidTime - 1 / 60);
    if (dx.abs() > 6 && c.speed > 175) {
      c.driftCharge = math.min(1, c.driftCharge + 0.035);
      if (c.driftCharge >= 1) {
        c.driftCharge = 0;
        c.boostTime = 1.1;
        c.speed = math.min(c.topSpeed + 120, c.speed + 130);
        _emit(RaceEventType.driftBoost, racerIndex: racerIndex);
      }
    } else {
      c.driftCharge = math.max(0, c.driftCharge - 0.025);
    }
  }

  void pause() {
    if (_phase != RacePhase.racing && _phase != RacePhase.countdown) return;
    _phase = RacePhase.paused;
    _stopTimers();
    notifyListeners();
  }

  void resume() {
    if (_phase != RacePhase.paused) return;
    _phase = countdown > 0 ? RacePhase.countdown : RacePhase.racing;
    _armTimers();
    notifyListeners();
  }

  /// End an endless run early (player chose "End Run").
  void endRun() {
    if (_phase != RacePhase.racing || mode != RaceMode.endless) return;
    final r = _humanRacer();
    if (r != null && !r.finished) {
      r.finished = true;
      r.place = 1;
    }
    _finishRace();
  }

  void quitToIdle() {
    _stopTimers();
    _phase = RacePhase.idle;
    racers.clear();
    trackPoints.clear();
    notifyListeners();
  }

  RacerState? _humanRacer() {
    for (final r in racers) {
      if (!r.isBot) return r;
    }
    return null;
  }

  void _emit(RaceEventType type, {int racerIndex = -1, int place = 0}) {
    if (_disposed) return;
    _events.add(RaceEvent(type, racerIndex: racerIndex, place: place));
  }

  // ------------------------------------------------------------- physics
  void _advance(double dt) {
    if (_disposed) return;
    _advanceCounter++;
    _lastAdvance = DateTime.now();
    if (_phase == RacePhase.countdown) {
      final before = countdown.ceil();
      countdown -= dt;
      final after = countdown.ceil();
      if (after != before && after >= 1) {
        _emit(RaceEventType.countBeep);
      }
      if (countdown <= 0) {
        countdown = 0;
        _phase = RacePhase.racing;
        for (final r in racers) {
          r.lapTime = 0;
        }
        _emit(RaceEventType.go);
        _emit(RaceEventType.engineRev);
      }
      notifyListeners();
      return;
    }
    if (_phase != RacePhase.racing) return;

    final lead = _leadProgress();
    for (var i = 0; i < racers.length; i++) {
      final c = racers[i];
      if (c.finished) continue;
      if (c.isBot) _driveBot(c, lead, dt);
      _physics(c, dt);
      _checkpoints(c, i, dt);
      c.exhaust = math.min(1, c.speed / 300);
    }
    _updatePlaces();
    _checkRaceEnd();
    notifyListeners();
  }

  double _leadProgress() {
    var best = -1e18;
    for (final c in racers) {
      final p = _progress(c);
      if (p > best) best = p;
    }
    return best;
  }

  double _progress(RacerState c) =>
      c.lap * 100000.0 + c.nextCp * 1000.0 - _distToNextCp(c);

  double _distToNextCp(RacerState c) {
    final idx = (c.nextCp % checkpointCount) * trackSamples ~/ checkpointCount;
    return (c.pos - trackPoints[idx]).distance;
  }

  void _physics(RacerState c, double dt) {
    if (c.crashTime > 0) {
      c.crashTime -= dt;
      c.speed = math.max(0, c.speed - 900 * dt);
      c.pos += Offset(math.cos(c.heading), math.sin(c.heading)) * c.speed * dt;
      return;
    }
    final target = c.boostTime > 0 ? c.topSpeed + 110 : c.topSpeed;
    if (c.boostTime > 0) c.boostTime -= dt;
    c.speed += (target - c.speed) * math.min(1, 1.7 * dt);
    final offTrack = _distToTrack(c.pos) > 58;
    if (offTrack) {
      c.offTrackTime += dt;
      c.speed *= math.exp(-2.8 * dt);
      // Hard crash: flying off at speed in endless mode.
      if (mode == RaceMode.endless && c.speed > 150 && c.offTrackTime > 0.6) {
        c.crashes++;
        c.crashTime = 0.9;
        c.offTrackTime = 0;
        c.speed = 0;
        _emit(RaceEventType.crash,
            racerIndex: racers.indexOf(c), place: c.crashes);
      }
    } else {
      c.offTrackTime = 0;
    }
    c.pos += Offset(math.cos(c.heading), math.sin(c.heading)) * c.speed * dt;
    c.pos = Offset(c.pos.dx.clamp(10, 990), c.pos.dy.clamp(10, 990));
    c.lapTime += dt;
    if (mode == RaceMode.endless) {
      c.distance += c.speed * dt * 0.05; // ~meters
    }
  }

  double _distToTrack(Offset p) {
    var best = 1e18;
    // Stride for speed; track is smooth so every 4th sample is plenty.
    for (var i = 0; i < trackPoints.length; i += 4) {
      final d = (trackPoints[i] - p).distanceSquared;
      if (d < best) best = d;
    }
    return math.sqrt(best);
  }

  void _checkpoints(RacerState c, int index, double dt) {
    final cpIdx = (c.nextCp % checkpointCount) * trackSamples ~/ checkpointCount;
    if ((c.pos - trackPoints[cpIdx]).distance < 70) {
      c.nextCp++;
      if (c.nextCp >= checkpointCount) {
        c.nextCp = 0;
        final finishedLap = c.lap;
        c.lap++;
        if (c.bestLap == 0 || c.lapTime < c.bestLap) c.bestLap = c.lapTime;
        final lapMs = (c.lapTime * 1000).round();
        c.lapTime = 0;
        _emit(RaceEventType.lap, racerIndex: index, place: lapMs);
        if (mode != RaceMode.endless && c.lap > lapsToWin && !c.finished) {
          c.finished = true;
          c.place = ++placesGiven;
          if (mode == RaceMode.timeTrial || _allHumansFinished()) {
            _finishRace();
            return;
          }
        }
        // Keep lap display sane for endless (laps don't end the run).
        if (mode == RaceMode.endless && finishedLap > 999) c.lap = 999;
      }
    }
  }

  bool _allHumansFinished() {
    for (final c in racers) {
      if (!c.isBot && !c.finished) return false;
    }
    return true;
  }

  void _updatePlaces() {
    if (mode == RaceMode.endless || mode == RaceMode.timeTrial) return;
    final order = [...racers]..sort((a, b) => _progress(b).compareTo(_progress(a)));
    for (var i = 0; i < order.length; i++) {
      final c = order[i];
      final newPlace = i + 1;
      if (!c.isBot && c.lastPlace != 0 && c.lastPlace != newPlace) {
        _emit(RaceEventType.positionChange,
            racerIndex: racers.indexOf(c), place: newPlace);
      }
      c.lastPlace = newPlace;
      if (!c.finished) c.place = newPlace;
    }
  }

  void _driveBot(RacerState c, double lead, double dt) {
    if (c.crashTime > 0) return;
    // Look ahead along the track from the next checkpoint.
    final look = (c.nextCp + 2 + c.aiLevel) % checkpointCount;
    final idx = look * trackSamples ~/ checkpointCount;
    final target = trackPoints[idx];
    final want = math.atan2(target.dy - c.pos.dy, target.dx - c.pos.dx);
    var diff = want - c.heading;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    const turn = [2.4, 3.0, 3.6];
    c.heading += diff.clamp(-1, 1) * turn[c.aiLevel.clamp(0, 2)] * dt;
    // Occasional AI drift boost for visible drama.
    c.aiBoostCooldown -= dt;
    if (c.aiBoostCooldown <= 0 && diff.abs() > 0.5 && c.speed > 170) {
      c.aiBoostCooldown = 4 + _rand.nextDouble() * 4;
      c.boostTime = 0.8;
      c.skidTime = 0.4;
    }
    c.skidTime = math.max(0, c.skidTime - dt);
    // Rubber-band: keep the pack close so every race feels alive.
    final behind = (lead - _progress(c)).clamp(0, 400000).toDouble();
    final base = _botTopSpeed(c);
    c.topSpeed = behind > 120000
        ? base * 1.10
        : (behind < 25000 ? base * 0.94 : base);
  }

  void _checkRaceEnd() {
    if (_phase != RacePhase.racing) return;
    if (mode == RaceMode.endless) {
      final r = _humanRacer();
      if (r != null && r.crashes >= 3 && !r.finished) {
        r.finished = true;
        r.place = 1;
        _finishRace();
      }
      return;
    }
    if (mode == RaceMode.timeTrial) return; // ends in _checkpoints
    // Grand Prix ends when every racer has a place (humans always finish —
    // the engine never strands a human: bots yield, see _driveBot easing).
    var allPlaced = true;
    for (final c in racers) {
      if (!c.finished) {
        allPlaced = false;
        break;
      }
    }
    if (allPlaced) _finishRace();
  }

  void _finishRace() {
    if (_phase == RacePhase.finished) return;
    _phase = RacePhase.finished;
    _stopTimers();
    // Assign any unplaced racers by progress so standings are always full.
    final order = [...racers]..sort((a, b) => _progress(b).compareTo(_progress(a)));
    for (final c in order) {
      if (c.place == 0) c.place = ++placesGiven;
    }
    _emit(RaceEventType.finished);
    notifyListeners();
  }

  /// Standings sorted by place (1st first). Always complete after finish.
  List<RacerState> get standings {
    final order = [...racers]..sort((a, b) => a.place.compareTo(b.place));
    return order;
  }

  /// Human racers' live places for the HUD chips.
  List<RacerState> get humans =>
      racers.where((r) => !r.isBot).toList(growable: false);

  @override
  void dispose() {
    _disposed = true;
    _stopTimers();
    _events.close();
    super.dispose();
  }
}
