import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/pixel_themes.dart';

/// Pro screen: Free-vs-Pro comparison, Pro purchase, tip jar, restore.
/// Honest states throughout: until the products exist in Play Console the
/// store shows "available after store setup" — never a fake buy button.
class ProScreen extends StatefulWidget {
  final RacerAudio audio;
  final RacerSettings settings;
  const ProScreen({super.key, required this.audio, required this.settings});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  late final RacerStore _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _store = RacerStore();
    _init();
  }

  Future<void> _init() async {
    await _store.init();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = PixelThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.grassDark,
      appBar: AppBar(
        backgroundColor: theme.panel,
        foregroundColor: theme.text,
        title:
            Text('PIXEL RACER PRO', style: PixelUi.display(20, theme: theme)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _freeVsPro(theme),
                  const SizedBox(height: 14),
                  _proBuyCard(theme),
                  const SizedBox(height: 14),
                  _tipJar(theme),
                  const SizedBox(height: 14),
                  _restoreRow(theme),
                ],
              ),
            ),
    );
  }

  Widget _freeVsPro(PixelTheme theme) {
    const rows = [
      ['All race modes', '✅', '✅'],
      ['6 free themes', '✅', '✅'],
      ['4 car styles', '✅', '✅'],
      ['4 tracks', '✅', '✅'],
      ['Easy + Medium AI', '✅', '✅'],
      ['Hard difficulty', '🔒', '✅'],
      ['Ace AI rivals', '🔒', '✅'],
      ['6 extra Pro themes', '🔒', '✅'],
      ['Custom theme creator', '🔒', '✅'],
      ['4 extra car styles', '🔒', '✅'],
      ['4 extra tracks', '🔒', '✅'],
      ['No ads, ever', '✅', '✅'],
    ];
    return PixelUi.panel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FREE vs PRO', style: PixelUi.display(20, theme: theme)),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  Center(
                      child: Text('FREE',
                          style: PixelUi.label(13, theme: theme))),
                  Center(
                      child: Text('PRO',
                          style: PixelUi.label(13,
                              theme: theme,
                              color: const Color(0xFFFFD35E)))),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 5),
                      child: Text(r[0],
                          style: PixelUi.body(13, theme: theme)),
                    ),
                    Center(
                        child: Text(r[1],
                            style: const TextStyle(fontSize: 15))),
                    Center(
                        child: Text(r[2],
                            style: const TextStyle(fontSize: 15))),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _proBuyCard(PixelTheme theme) {
    if (widget.settings.isPro) {
      return PixelUi.panel(
        theme: theme,
        child: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are PRO! Every theme, car, track and Hard mode is unlocked. Thank you for supporting indie games!',
                style: PixelUi.body(14, theme: theme),
              ),
            ),
          ],
        ),
      );
    }
    final product = _store.proProduct;
    return PixelUi.panel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('UNLOCK PRO — ONE TIME',
              style: PixelUi.display(18, theme: theme)),
          const SizedBox(height: 6),
          Text(
            'A single purchase unlocks everything Pro, forever, on every device with your account.',
            style: PixelUi.body(13, theme: theme, color: theme.muted),
          ),
          const SizedBox(height: 12),
          if (!_store.storeReady)
            Text(
              '🛠️ ${_store.error ?? 'Available after store setup'} — the Pro upgrade appears here once it is configured in Play Console.',
              style: PixelUi.body(13,
                  theme: theme, color: theme.muted),
            )
          else if (product != null)
            PixelUi.button(
              theme: theme,
              text: _store.purchaseInProgress.value
                  ? 'WORKING…'
                  : 'GET PRO — ${product.price}',
              color: const Color(0xFFB98A2B),
              onTap: _store.purchaseInProgress.value
                  ? null
                  : () {
                      widget.audio.click();
                      _store.buyPro();
                      setState(() {});
                    },
            ),
          ValueListenableBuilder<String?>(
            valueListenable: _store.purchaseError,
            builder: (_, err, _) => err == null
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(err,
                        style: TextStyle(color: theme.danger)),
                  ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _store.lastThanks,
            builder: (_, thanks, _) => thanks == null
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(thanks,
                        style: TextStyle(
                            color: theme.accent,
                            fontWeight: FontWeight.w800)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tipJar(PixelTheme theme) {
    return PixelUi.panel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('☕ TIP JAR', style: PixelUi.display(18, theme: theme)),
          const SizedBox(height: 6),
          Text(
            'Pixel Racer is free forever. If it made you smile, a tiny tip keeps the engines running!',
            style: PixelUi.body(13, theme: theme, color: theme.muted),
          ),
          const SizedBox(height: 12),
          if (!_store.storeReady)
            Text(
              '🛠️ Tips appear here once they are configured in Play Console.',
              style:
                  PixelUi.body(13, theme: theme, color: theme.muted),
            )
          else
            Row(
              children: [
                Expanded(
                    child: _tipButton(
                        theme, _store.coffeeProduct, '☕ Coffee')),
                const SizedBox(width: 10),
                Expanded(
                    child: _tipButton(theme,
                        _store.chocolateProduct, '🍫 Chocolate')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tipButton(
      PixelTheme theme, ProductDetails? product, String label) {
    if (product == null) {
      return PixelUi.button(
          theme: theme, text: label, small: true, onTap: null);
    }
    return PixelUi.button(
      theme: theme,
      text: '$label\n${product.price}',
      small: true,
      color: theme.panelEdge,
      onTap: _store.purchaseInProgress.value
          ? null
          : () {
              widget.audio.click();
              _store.buyTip(product);
              setState(() {});
            },
    );
  }

  Widget _restoreRow(PixelTheme theme) {
    return Center(
      child: TextButton(
        onPressed: () {
          widget.audio.click();
          _store.restore();
        },
        child: Text(
          'Restore purchases',
          style: PixelUi.label(14, theme: theme,
              color: theme.accent),
        ),
      ),
    );
  }
}