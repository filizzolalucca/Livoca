import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/panda.dart';
import '../widgets/task_widgets.dart';
import 'celebration_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  /// Enquanto uma tarefa está sendo arrastada, mostramos a barra de destinos.
  bool _dragging = false;

  void _startDrag() {
    // Um aviso na parte de baixo cobriria a barra de destinos.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _dragging = true);
  }

  void _endDrag() {
    if (mounted) setState(() => _dragging = false);
  }

  Future<void> _toggle(Task task) async {
    final state = AppScope.read(context);
    final period = await state.toggleDone(task);
    if (period != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CelebrationScreen(period: period, name: state.profile?.name ?? ''),
        ),
      );
    }
  }

  Future<void> _dropOnPeriod(Task task, PeriodType period) async {
    _endDrag();
    final state = AppScope.read(context);
    await state.moveTo(task, period);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${task.title}" foi para ${period.label.toLowerCase()}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _dropOnPause(Task task) async {
    _endDrag();
    await AppScope.read(context).pause(task);
  }

  TaskCard _card(Task task, {bool overdue = false}) => TaskCard(
    key: ValueKey(task.id),
    task: task,
    overdue: overdue,
    onToggle: () => _toggle(task),
    onDragStarted: _startDrag,
    onDragEnd: _endDrag,
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final overdue = state.overdueTasks;
    final paused = state.pausedTasks;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _Header(state: state),
              const SizedBox(height: 12),
              _StatsCard(state: state),
              const SizedBox(height: 16),
              for (final p in PeriodType.values) ...[
                _PeriodSection(
                  period: p,
                  tasks: state.currentTasks(p),
                  cardBuilder: _card,
                  onDrop: (t) => _dropOnPeriod(t, p),
                ),
                const SizedBox(height: 14),
              ],
              _SpecialSection(
                title: 'Não realizadas a tempo',
                icon: Icons.history_rounded,
                color: const Color(0xFFE57373),
                emptyText: 'Nenhuma tarefa atrasada. Arraste daqui para um novo período!',
                tasks: overdue,
                cardBuilder: (t) => _card(t, overdue: true),
              ),
              const SizedBox(height: 14),
              _SpecialSection(
                title: 'Em pausa',
                icon: Icons.pause_circle_outline_rounded,
                color: Colors.blueGrey,
                emptyText:
                    'Arraste uma tarefa para cá para pausar. '
                    'Para retomar, arraste de volta para uma fileira.',
                tasks: paused,
                cardBuilder: _card,
                onDrop: _dropOnPause,
              ),
            ],
          ),
          // Barra de destinos que aparece durante o arraste, para não precisar rolar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_dragging,
              child: AnimatedSlide(
                offset: _dragging ? Offset.zero : const Offset(0, 1.2),
                duration: const Duration(milliseconds: 200),
                child: _DropBar(onDropPeriod: _dropOnPeriod, onDropPause: _dropOnPause),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _dragging
          ? null
          : FloatingActionButton.extended(
              heroTag: 'tasks_fab',
              onPressed: () => showTaskEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tarefa', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final today = state.currentTasks(PeriodType.daily);
    final done = today.where((t) => t.isDone).length;
    final String message;
    if (today.isEmpty) {
      message = 'Que tal adicionar uma tarefa para hoje?';
    } else if (done == today.length) {
      message = 'Você concluiu tudo de hoje! 🎉';
    } else {
      message = 'Hoje: $done de ${today.length} tarefas concluídas';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [LivocaColors.pinkLight, Color(0xFFFCE4EC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Data de hoje, sempre visível.
          Row(
            children: [
              const Icon(Icons.today_rounded, size: 18, color: LivocaColors.pinkDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  capitalize(DateFormat("EEEE, d 'de' MMMM 'de' y").format(DateTime.now())),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LivocaColors.pinkDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Panda(size: 84),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oi, ${state.profile?.name ?? ''}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: LivocaColors.pinkDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    if (today.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: done / today.length,
                          minHeight: 8,
                          color: LivocaColors.pink,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Contador de tarefas concluídas, com filtro por período.
class _StatsCard extends StatefulWidget {
  const _StatsCard({required this.state});

  final AppState state;

  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard> {
  /// null = desde o início.
  PeriodType? _filter = PeriodType.daily;

  static String _caption(PeriodType? p) => switch (p) {
    null => 'desde o início',
    PeriodType.daily => 'hoje',
    PeriodType.weekly => 'nesta semana',
    PeriodType.monthly => 'neste mês',
    PeriodType.quarterly => 'neste trimestre',
    PeriodType.semiannual => 'neste semestre',
    PeriodType.yearly => 'neste ano',
  };

  Widget _chip(PeriodType? p, String label) {
    final selected = _filter == p;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selectedColor: LivocaColors.pink,
        backgroundColor: LivocaColors.blush,
        side: const BorderSide(color: LivocaColors.pinkLight),
        labelStyle: TextStyle(
          color: selected ? Colors.white : LivocaColors.pinkDark,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _filter = p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.state.completedCount(_filter);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: LivocaColors.pinkLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: LivocaColors.pinkDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tarefas concluídas',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    Text(
                      _caption(_filter),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: LivocaColors.pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in PeriodType.values) _chip(p, p.shortLabel),
                _chip(null, 'Total'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma fileira de período (Hoje, Esta semana, ...). Recebe tarefas arrastadas.
class _PeriodSection extends StatelessWidget {
  const _PeriodSection({
    required this.period,
    required this.tasks,
    required this.cardBuilder,
    required this.onDrop,
  });

  final PeriodType period;
  final List<Task> tasks;
  final Widget Function(Task) cardBuilder;
  final void Function(Task) onDrop;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) =>
          !(d.data.period == period && d.data.isCurrent(DateTime.now())),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final highlight = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlight ? LivocaColors.pinkLight : const Color(0xFFFCE4EC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: highlight ? LivocaColors.pink : Colors.transparent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(period.icon, color: LivocaColors.pink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          period.label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: LivocaColors.pinkDark,
                          ),
                        ),
                        Text(
                          periodRangeLabel(period, period.startOf(DateTime.now())),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$done/${tasks.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: LivocaColors.pinkDark,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Adicionar em ${period.label.toLowerCase()}',
                    icon: const Icon(Icons.add_circle_rounded, color: LivocaColors.pink),
                    onPressed: () => showTaskEditor(context, initialPeriod: period),
                  ),
                ],
              ),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                  child: Text(
                    highlight ? 'Solte aqui!' : 'Nenhuma tarefa ainda.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                for (final t in tasks)
                  Padding(padding: const EdgeInsets.only(top: 8), child: cardBuilder(t)),
            ],
          ),
        );
      },
    );
  }
}

/// Seções "Não realizadas a tempo" e "Em pausa".
class _SpecialSection extends StatelessWidget {
  const _SpecialSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.emptyText,
    required this.tasks,
    required this.cardBuilder,
    this.onDrop,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String emptyText;
  final List<Task> tasks;
  final Widget Function(Task) cardBuilder;
  final void Function(Task)? onDrop;

  @override
  Widget build(BuildContext context) {
    Widget content(bool highlight) => AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: highlight ? color : color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                ),
              ),
              if (tasks.isNotEmpty)
                Text(
                  '${tasks.length}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
            ],
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(emptyText, style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            for (final t in tasks)
              Padding(padding: const EdgeInsets.only(top: 8), child: cardBuilder(t)),
        ],
      ),
    );

    final drop = onDrop;
    if (drop == null) return content(false);
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => !d.data.isPaused,
      onAcceptWithDetails: (d) => drop(d.data),
      builder: (context, candidates, _) => content(candidates.isNotEmpty),
    );
  }
}

/// Destinos rápidos exibidos na parte de baixo durante o arraste.
class _DropBar extends StatelessWidget {
  const _DropBar({required this.onDropPeriod, required this.onDropPause});

  final void Function(Task, PeriodType) onDropPeriod;
  final void Function(Task) onDropPause;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Solte a tarefa em um período',
                style: TextStyle(fontWeight: FontWeight.w700, color: LivocaColors.pinkDark),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in PeriodType.values)
                    _DropChip(
                      label: p.shortLabel,
                      icon: p.icon,
                      color: LivocaColors.pink,
                      willAccept: (t) => !(t.period == p && t.isCurrent(DateTime.now())),
                      onAccept: (t) => onDropPeriod(t, p),
                    ),
                  _DropChip(
                    label: 'Pausar',
                    icon: Icons.pause_rounded,
                    color: Colors.blueGrey,
                    willAccept: (t) => !t.isPaused,
                    onAccept: onDropPause,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropChip extends StatelessWidget {
  const _DropChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.willAccept,
    required this.onAccept,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool Function(Task) willAccept;
  final void Function(Task) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => willAccept(d.data),
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, _) {
        final hover = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(horizontal: hover ? 18 : 14, vertical: hover ? 14 : 10),
          decoration: BoxDecoration(
            color: hover ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: hover ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, color: hover ? Colors.white : color),
              ),
            ],
          ),
        );
      },
    );
  }
}
