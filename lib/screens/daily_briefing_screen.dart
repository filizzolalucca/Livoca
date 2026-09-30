import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/panda.dart';
import '../widgets/task_widgets.dart';

/// Resumo exibido na primeira vez que o app é aberto no dia:
/// 1ª página: tarefas e compromissos de hoje (panda pensativo);
/// 2ª página: tarefas não concluídas a tempo (panda triste), se houver.
class DailyBriefingScreen extends StatefulWidget {
  const DailyBriefingScreen({super.key});

  @override
  State<DailyBriefingScreen> createState() => _DailyBriefingScreenState();
}

class _DailyBriefingScreenState extends State<DailyBriefingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final today = state.currentTasks(PeriodType.daily);
    final appointments = state.appointmentsOn(now);
    final overdue = state.overdueTasks;
    final hasOverdue = overdue.isNotEmpty;
    final name = state.profile?.name ?? '';

    final pages = [
      _BriefingPage(
        panda: PandaMood.thinking,
        title: '${_greeting()}, $name!',
        subtitle: capitalize(DateFormat("EEEE, d 'de' MMMM").format(now)),
        body: [
          _SectionTitle(
            today.isEmpty
                ? 'Nenhuma tarefa para hoje ainda'
                : today.length == 1
                ? 'Hoje você tem 1 tarefa'
                : 'Hoje você tem ${today.length} tarefas',
          ),
          if (today.isEmpty)
            const _Hint('Que tal planejar o seu dia? Toque em "+ Tarefa" na tela principal.')
          else
            for (final t in today)
              _Item(
                icon: t.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                iconColor: t.isDone ? Colors.green : LivocaColors.pink,
                text: t.title,
                done: t.isDone,
              ),
          if (appointments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(
              appointments.length == 1
                  ? '1 compromisso na agenda'
                  : '${appointments.length} compromissos na agenda',
            ),
            for (final a in appointments)
              _Item(
                icon: Icons.event_rounded,
                iconColor: LivocaColors.pinkDark,
                text: '${DateFormat('HH:mm').format(a.dateTime)} • ${a.title}',
              ),
          ],
        ],
        buttonLabel: hasOverdue ? 'Próximo' : 'Vamos lá!',
        onButton: hasOverdue
            ? () => _pages.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              )
            : () => Navigator.of(context).pop(),
      ),
      if (hasOverdue)
        _BriefingPage(
          panda: PandaMood.sad,
          title: 'Ficaram para trás...',
          subtitle: overdue.length == 1
              ? '1 tarefa não foi concluída a tempo'
              : '${overdue.length} tarefas não foram concluídas a tempo',
          body: [
            for (final t in overdue)
              _Item(
                icon: Icons.history_rounded,
                iconColor: const Color(0xFFE57373),
                text: t.title,
                detail: '${t.period.shortLabel} • ${periodRangeLabel(t.period, t.periodStart)}',
              ),
            const SizedBox(height: 12),
            const _Hint(
              'Não tem problema! Na tela principal, segure a tarefa e arraste para '
              'um novo período, ou deixe em pausa.',
            ),
          ],
          buttonLabel: 'Entendi',
          onButton: () => Navigator.of(context).pop(),
        ),
    ];

    return Scaffold(
      backgroundColor: LivocaColors.blush,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Pular', style: TextStyle(color: LivocaColors.pinkDark)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            if (pages.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i ? LivocaColors.pink : LivocaColors.pinkLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BriefingPage extends StatelessWidget {
  const _BriefingPage({
    required this.panda,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.buttonLabel,
    required this.onButton,
  });

  final PandaMood panda;
  final String title;
  final String subtitle;
  final List<Widget> body;
  final String buttonLabel;
  final VoidCallback onButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Center(child: Panda(size: 170, mood: panda)),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: LivocaColors.pinkDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onButton, child: Text(buttonLabel)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: LivocaColors.pinkDark,
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: Colors.grey.shade700, height: 1.3));
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.detail,
    this.done = false,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final String? detail;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? Colors.grey : Colors.black87,
                  ),
                ),
                if (detail != null)
                  Text(detail!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
