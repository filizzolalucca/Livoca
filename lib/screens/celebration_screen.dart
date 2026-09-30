import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/panda.dart';

/// Tela de parabéns exibida quando todas as tarefas de um período são concluídas.
class CelebrationScreen extends StatefulWidget {
  const CelebrationScreen({super.key, required this.period, required this.name});

  final PeriodType period;
  final String name;

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 4));
  final _shareKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  bool _sharing = false;

  static const _confettiColors = [
    Color(0xFFEC407A),
    Color(0xFFF8BBD0),
    Color(0xFFFFD54F),
    Color(0xFF81D4FA),
    Color(0xFFA5D6A7),
    Color(0xFFCE93D8),
  ];

  String get _title => widget.name.isEmpty ? 'Parabéns!' : 'Parabéns, ${widget.name}!';
  String get _message => 'Você concluiu todas as tarefas ${widget.period.celebrationLabel}! 🎉';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _shareKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw Exception('Falha ao gerar imagem');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/livoca_parabens.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      // Necessário no iPad para posicionar o menu de compartilhamento.
      Rect? origin;
      final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '$_message Organizando minha vida com o Livoca 🐼💖',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível compartilhar agora. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LivocaColors.blush,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Esta parte vira a imagem compartilhada.
                    RepaintBoundary(
                      key: _shareKey,
                      child: _ShareCard(title: _title, message: _message),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: _shareButtonKey,
                        onPressed: _sharing ? null : _share,
                        icon: _sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.share_rounded),
                        label: const Text('Compartilhar'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LivocaColors.pinkDark,
                          side: const BorderSide(color: LivocaColors.pink, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: pi / 4,
              emissionFrequency: 0.06,
              numberOfParticles: 12,
              maxBlastForce: 30,
              gravity: 0.25,
              colors: _confettiColors,
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: 3 * pi / 4,
              emissionFrequency: 0.06,
              numberOfParticles: 12,
              maxBlastForce: 30,
              gravity: 0.25,
              colors: _confettiColors,
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.04,
              numberOfParticles: 15,
              gravity: 0.2,
              colors: _confettiColors,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCE4EC), LivocaColors.pinkLight],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          const Panda(size: 200, mood: PandaMood.heart),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: LivocaColors.pinkDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.3),
          ),
          const SizedBox(height: 20),
          const Text(
            'Livoca 🐼',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: LivocaColors.pink,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
