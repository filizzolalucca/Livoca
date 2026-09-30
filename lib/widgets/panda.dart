import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PandaMood { happy, heart, thinking, sad }

/// Mascote do Livoca. Ilustrações em domínio público (OpenClipart, CC0).
class Panda extends StatelessWidget {
  const Panda({super.key, this.size = 120, this.mood = PandaMood.happy});

  final double size;
  final PandaMood mood;

  String get _asset => switch (mood) {
    PandaMood.happy => 'assets/images/panda.svg',
    PandaMood.heart => 'assets/images/panda_heart.svg',
    PandaMood.thinking => 'assets/images/panda_thinking.svg',
    PandaMood.sad => 'assets/images/panda_sad.svg',
  };

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(_asset, height: size, semanticsLabel: 'Panda do Livoca');
  }
}
