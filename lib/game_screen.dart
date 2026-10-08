import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

const _lapsToWin = 3;
const _cpCount = 12;
const _samples = 240;

class _Car {
  final Player player;
  Offset pos;
  double heading;
  double speed = 0;
  int lap = 1;
  int cp = 1;
  double driftCharge = 0;
  double topSpeed = 285;
  bool finished = false;
  int place = 0;
  _Car(this.player, this.pos, this.heading);
}

class PixelRacerScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const PixelRacerScreen({super.key, required this.players, required this.callbacks});

  @override
  State<PixelRacerScreen> createState() => _PixelRacerScreenState();
}

class _PixelRacerScreenState extends State<PixelRacerScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final _cars = <_Car>[];
  List<Offset> _pts = [];
  Size _size = Size.zero;
  double _countdown = 3.2;
  bool _over = false;
  int _placesGiven = 0;
  final _steer = <int, int>{}; // pointerId -> carIndex (humans only)
  final _lastX = <int, double>{};
  final _rand = math.Random();

  List<_Car> get _humans => _cars.where((c) => !c.player.isBot).toList();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _buildTrack() {
    final v = (_rand.nextDouble() * 2 - 1);
    final cx = _size.width / 2, cy = _size.height / 2;
    final r = math.min(_size.width, _size.height) * 0.37;
    _pts = List.generate(_samples, (i) {
      final a = i / _samples * math.pi * 2;
      final rr = r * (1 + 0.2 * math.sin(2 * a + v) + 0.12 * math.sin(3 * a + 1.1));
      return Offset(cx + rr * math.cos(a), cy + rr * math.sin(a) * 0.88);
    });
    _cars.clear();
    final n = widget.players.length.clamp(1, 4);
    for (var i = 0; i < n; i++) {
      final back = (i * 26) % _samples;
      final idx = (_samples - back) % _samples;
      final p = _pts[idx];
      final ahead = _pts[(idx + 4) % _samples];
      _cars.add(_Car(widget.players[i], p + Offset(0, (i % 2) * 22 - 11),
          math.atan2(ahead.dy - p.dy, ahead.dx - p.dx)));
      if (widget.players[i].isBot) _cars.last.topSpeed = 262;
    }
    _countdown = 3.2;
    _over = false;
    _placesGiven = 0;
  }

  double _distToTrack(Offset p) {
    var best = 1e9;
    for (final q in _pts) {
      final d = (q - p).distanceSquared;
      if (d < best) best = d;
    }
    return math.sqrt(best);
  }

  int _progress(_Car c) => c.lap * 1000 + c.cp;

  void _tick(Duration _) {
    if (_pts.isEmpty || _over) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    const dt = 1 / 60;
    setState(() {
      if (_countdown > 0) {
        _countdown -= dt;
        return;
      }
      final lead = _cars.map(_progress).reduce(math.max);
      for (final c in _cars) {
        if (c.finished) continue;
        if (c.player.isBot) {
          _botDrive(c, lead, dt);
        }
        // physics
        c.speed += (c.topSpeed - c.speed) * math.min(1, 1.6 * dt);
        if (_distToTrack(c.pos) > 30) c.speed *= math.exp(-2.6 * dt);
        if (c.driftCharge > 0.4 && c.speed > 180) {
          // drifting bonus
          c.speed = math.min(c.topSpeed + 90, c.speed + 60 * dt);
        }
        c.pos += Offset(math.cos(c.heading), math.sin(c.heading)) * c.speed * dt;
        c.pos = Offset(c.pos.dx.clamp(8, _size.width - 8), c.pos.dy.clamp(8, _size.height - 8));
        // checkpoints
        final cpIdx = (c.cp % _cpCount) * _samples ~/ _cpCount;
        if ((c.pos - _pts[cpIdx]).distance < 46) {
          c.cp++;
          if (c.cp % _cpCount == 0) {
            c.lap++;
            if (c.lap > _lapsToWin && !c.finished) {
              c.finished = true;
              c.place = ++_placesGiven;
              if (!c.player.isBot) {
                _finishRace();
                return;
              }
            }
          }
        }
      }
      // all bots finished but a human hasn't? keep going; humans always finish eventually
    });
  }

  void _botDrive(_Car c, int lead, double dt) {
    final cpIdx = ((c.cp + 2) % _cpCount) * _samples ~/ _cpCount;
    final target = _pts[cpIdx];
    final want = math.atan2(target.dy - c.pos.dy, target.dx - c.pos.dx);
    var diff = want - c.heading;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    c.heading += diff.clamp(-1, 1) * 2.6 * dt;
    // rubber-band: speed up when far behind, ease off when leading
    final behind = (lead - _progress(c)).clamp(0, 4000);
    c.topSpeed = behind > 1500 ? 292 : (behind < 400 ? 248 : 262);
  }

  void _finishRace() {
    _over = true;
    _ticker.stop();
    final ordered = [..._cars]..sort((a, b) => a.place.compareTo(b.place));
    final me = _humans.first;
    final em = me.place == 1 ? '🏆' : (me.place == 2 ? '🥈' : (me.place == 3 ? '🥉' : '🏁'));
    Sfx.win();
    widget.callbacks.finish(
      headline: '$em You finished P${me.place}!',
      subline: ordered.map((c) => 'P${c.place} ${c.player.emoji} ${c.player.name}').join(' · '),
    );
  }

  void _steerHuman(int carIdx, double dx) {
    final c = _cars[carIdx];
    if (c.finished || _countdown > 0) return;
    c.heading += dx * 0.006;
    if (dx.abs() > 6 && c.speed > 170) {
      c.driftCharge = math.min(1, c.driftCharge + 0.03);
      if (c.driftCharge >= 1) {
        c.speed += 130;
        c.driftCharge = 0;
        Sfx.move();
      }
    } else {
      c.driftCharge = math.max(0, c.driftCharge - 0.02);
    }
  }

  void _onPointerDown(PointerDownEvent e, Size s) {
    if (_countdown > 0 || _over) return;
    final humans = _humans;
    if (humans.isEmpty) return;
    int carIdx;
    if (humans.length == 1) {
      carIdx = _cars.indexOf(humans.first);
    } else {
      // left half -> first human car, right half -> second
      carIdx = _cars.indexOf(e.localPosition.dx < s.width / 2 ? humans[0] : humans[1]);
    }
    _steer[e.pointer] = carIdx;
    _lastX[e.pointer] = e.localPosition.dx;
    Sfx.tap();
  }

  void _onPointerMove(PointerMoveEvent e) {
    final carIdx = _steer[e.pointer];
    if (carIdx == null) return;
    final dx = e.localPosition.dx - (_lastX[e.pointer] ?? e.localPosition.dx);
    _lastX[e.pointer] = e.localPosition.dx;
    _steerHuman(carIdx, dx);
  }

  void _onPointerUp(PointerEvent e) {
    _steer.remove(e.pointer);
    _lastX.remove(e.pointer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _cars.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${_cars[i].player.emoji} L${_cars[i].lap.clamp(1, _lapsToWin)}/$_lapsToWin',
                    style: TextStyle(
                        color: _cars[i].player.color,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              final s = Size(c.maxWidth, c.maxHeight);
              if ((s != _size || _pts.isEmpty) && s.width > 0) {
                _size = s;
                _buildTrack();
              }
              return Listener(
                onPointerDown: (e) => _onPointerDown(e, s),
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerUp,
                child: CustomPaint(
                  size: s,
                  painter: _RacePainter(
                    pts: _pts,
                    cars: _cars,
                    theme: theme,
                    countdown: _countdown,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('Drag sideways to steer — drift hard for boost! 💨',
              style: TextStyle(color: theme.muted)),
        ),
      ],
    );
  }
}

class _RacePainter extends CustomPainter {
  final List<Offset> pts;
  final List<_Car> cars;
  final GameTheme theme;
  final double countdown;

  _RacePainter({required this.pts, required this.cars, required this.theme, required this.countdown});

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;
    final loop = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      loop.lineTo(pts[i].dx, pts[i].dy);
    }
    loop.close();
    canvas.drawPath(loop, Paint()..style = PaintingStyle.stroke..strokeWidth = 62..color = theme.muted.withValues(alpha: 0.3));
    canvas.drawPath(loop, Paint()..style = PaintingStyle.stroke..strokeWidth = 52..color = theme.surface);
    // start line
    final s0 = pts[0];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(Rect.fromCenter(center: s0 + Offset(0, -18 + i * 12), width: 30, height: 10),
          Paint()..color = i.isEven ? theme.text : theme.muted);
    }
    // pixel cars (chunky rects)
    for (final c in cars) {
      canvas.save();
      canvas.translate(c.pos.dx, c.pos.dy);
      canvas.rotate(c.heading);
      final col = c.player.color;
      // shadow
      canvas.drawRect(const Rect.fromLTWH(-9, -6, 20, 14), Paint()..color = const Color(0x55000000));
      // body (pixel blocks)
      canvas.drawRect(const Rect.fromLTWH(-10, -7, 20, 14), Paint()..color = col);
      canvas.drawRect(const Rect.fromLTWH(-2, -7, 10, 14), Paint()..color = col.withValues(alpha: 0.75));
      // cockpit
      canvas.drawRect(const Rect.fromLTWH(-1, -4, 7, 8), Paint()..color = theme.text);
      // nose stripe
      canvas.drawRect(const Rect.fromLTWH(7, -7, 3, 14), Paint()..color = theme.accent);
      // wheels
      final w = Paint()..color = const Color(0xFF222222);
      canvas.drawRect(const Rect.fromLTWH(-8, -10, 6, 4), w);
      canvas.drawRect(const Rect.fromLTWH(-8, 6, 6, 4), w);
      canvas.drawRect(const Rect.fromLTWH(3, -10, 6, 4), w);
      canvas.drawRect(const Rect.fromLTWH(3, 6, 6, 4), w);
      // drift charge glow
      if (c.driftCharge > 0.15) {
        canvas.drawCircle(Offset.zero, 16 + c.driftCharge * 8,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = theme.accent.withValues(alpha: c.driftCharge));
      }
      canvas.restore();
    }
    // countdown
    if (countdown > 0) {
      final label = countdown > 0.2 ? '${countdown.ceil()}' : 'GO!';
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(
                color: theme.text, fontSize: 72, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RacePainter old) => true;
}
