import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const PixelRacerApp());

class PixelRacerApp extends StatelessWidget {
  const PixelRacerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.midnightNeon,
      title: 'Pixel Racer',
      tagline: 'Tiny cars. Massive drifts. Zero mercy.',
      emoji: '🏁',
      slug: 'pixelracer',
      howToPlay:
          '• Your car accelerates on its own — drag sideways to steer.\n• 3 laps, first across the line wins. Watch the bots!\n• Drift hard through corners to charge a speed boost.\n• 2 players? Left half steers car 1, right half steers car 2.',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => PixelRacerScreen(players: players, callbacks: cb),
    );
  }
}
