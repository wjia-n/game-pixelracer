import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pixel_themes.dart';
import 'menu_screen.dart';

/// Single splash route, two moments:
/// 1. Company moment — the official WAJIHA logo, briefly.
/// 2. Game splash — logo + name + animated loading line + "Credits: WAJIHA".
/// Audio clips are pre-warmed during the company moment; menu music starts
/// with the game splash.
class SplashScreen extends StatefulWidget {
  final RacerAudio audio;
  final RacerSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyMoment = true;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Company moment: pre-warm audio off the critical path.
    widget.audio.prewarm();
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _companyMoment = false);
    // Game splash: loading line + menu music.
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = PixelThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    if (_companyMoment) return const _CompanySplash();
    return Scaffold(
      backgroundColor: theme.grassDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: theme.panelEdge, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(6, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.asset(
                'assets/pixelracer_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: theme.track,
                  child: const Center(
                      child: Text('🏁', style: TextStyle(fontSize: 64))),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('PIXEL RACER', style: PixelUi.display(44, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'TINY CARS · MASSIVE DRIFTS',
              style: PixelUi.label(13, theme: theme),
            ),
            const SizedBox(height: 32),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: _loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(color: theme.panelEdge, width: 3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _loader.value.clamp(0.04, 1.0),
                        child: Container(color: theme.accent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _loader.value < 1 ? 'Warming up the engines…' : 'Ready!',
                      style: PixelUi.body(13,
                          theme: theme,
                          color: theme.text.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(width: 30),
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: PixelUi.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Company moment: the official WAJIHA logo (copied unchanged into assets),
/// full-bleed dark stage. Shown briefly before the game splash.
class _CompanySplash extends StatelessWidget {
  const _CompanySplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/wajiha_logo.png',
              width: 130,
              height: 130,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'WAJIHA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'WAJIHA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
