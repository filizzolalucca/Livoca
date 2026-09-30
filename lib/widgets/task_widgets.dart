import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Texto que descreve o intervalo de datas de um período.
String periodRangeLabel(PeriodType period, DateTime start) {
  final end = period.endOf(start);
  final lastDay = DateTime(end.year, end.month, end.day - 1);
  final dm = DateFormat('dd/MM');
  final mon = DateFormat('MMM');
  return switch (period) {
    PeriodType.daily => DateFormat("EEEE, d 'de' MMMM").format(start),
    PeriodType.weekly => '${dm.format(start)} – ${dm.format(lastDay)}',
    PeriodType.monthly => DateFormat("MMMM 'de' y").format(start),
    PeriodType.quarterly ||
    PeriodType.semiannual => '${mon.format(start)} – ${mon.format(lastDay)} ${start.year}',
    PeriodType.yearly => '${start.year}',
  };
}

/// Cartão de tarefa. Pode ser arrastado (toque longo) para outra fileira.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onDragStarted,
    this.onDragEnd,
    this.overdue = false,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final card = _TaskCardBody(task: task, onToggle: onToggle, overdue: overdue);
    return LongPressDraggable<Task>(
      data: task,
      hapticFeedbackOnStart: true,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd?.call(),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 48),
          child: Opacity(
            opacity: 0.9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x33C2185B), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              child: _TaskCardBody(task: task, onToggle: null, overdue: overdue),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _TaskCardBody extends StatelessWidget {
  const _TaskCardBody({required this.task, required this.onToggle, required this.overdue});

  final Task task;
  final VoidCallback? onToggle;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final subtitle = overdue
        ? 'Era para: ${task.period.shortLabel.toLowerCase()} • ${periodRangeLabel(task.period, task.periodStart)}'
        : task.isPaused
        ? 'Em pausa • era de: ${task.period.shortLabel.toLowerCase()}'
        : null;

    return Card(
      color: overdue ? const Color(0xFFFFEBEE) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            if (task.isPaused)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.pause_circle_rounded, color: LivocaColors.pinkLight),
              )
            else
              Checkbox(
                value: task.isDone,
                activeColor: LivocaColors.pink,
                side: const BorderSide(color: LivocaColors.pink, width: 2),
                onChanged: onToggle == null ? null : (_) => onToggle!(),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        color: task.isDone ? Colors.grey : Colors.black87,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (onToggle != null) _TaskMenu(task: task),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_indicator_rounded, color: LivocaColors.pinkLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskMenu extends StatelessWidget {
  const _TaskMenu({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
      tooltip: 'Opções',
      onSelected: (value) async {
        final state = AppScope.read(context);
        switch (value) {
          case 'edit':
            await showTaskEditor(context, task: task);
          case 'move':
            final period = await showPeriodPicker(
              context,
              title: task.isPaused ? 'Retomar em qual período?' : 'Mover para qual período?',
            );
            if (period != null) await state.moveTo(task, period);
          case 'pause':
            await state.pause(task);
          case 'delete':
            if (!context.mounted) return;
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Excluir tarefa?'),
                content: Text('"${task.title}" será excluída.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Excluir'),
                  ),
                ],
              ),
            );
            if (ok == true) await state.deleteTask(task);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: _MenuRow(Icons.edit_rounded, 'Editar')),
        PopupMenuItem(
          value: 'move',
          child: task.isPaused
              ? const _MenuRow(Icons.play_arrow_rounded, 'Retomar')
              : const _MenuRow(Icons.swap_vert_rounded, 'Mover para...'),
        ),
        if (!task.isPaused)
          const PopupMenuItem(value: 'pause', child: _MenuRow(Icons.pause_rounded, 'Pausar')),
        const PopupMenuItem(
          value: 'delete',
          child: _MenuRow(Icons.delete_outline_rounded, 'Excluir'),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: LivocaColors.pinkDark),
      const SizedBox(width: 12),
      Text(label),
    ],
  );
}

/// Escolher um período (usado para mover/retomar tarefas).
Future<PeriodType?> showPeriodPicker(BuildContext context, {required String title}) {
  return showModalBottomSheet<PeriodType>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: LivocaColors.pinkDark,
                ),
              ),
            ),
            for (final p in PeriodType.values)
              ListTile(
                leading: Icon(p.icon, color: LivocaColors.pink),
                title: Text(p.label),
                subtitle: Text(periodRangeLabel(p, p.startOf(DateTime.now()))),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Criar (task == null) ou editar uma tarefa.
Future<void> showTaskEditor(BuildContext context, {Task? task, PeriodType? initialPeriod}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _TaskEditor(task: task, initialPeriod: initialPeriod ?? PeriodType.daily),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task, required this.initialPeriod});

  final Task? task;
  final PeriodType initialPeriod;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late PeriodType _period = widget.task?.period ?? widget.initialPeriod;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _title.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escreva o nome da tarefa');
      return;
    }
    final state = AppScope.read(context);
    final task = widget.task;
    if (task == null) {
      await state.addTask(text, _period);
    } else {
      await state.renameTask(task, text);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Editar tarefa' : 'Nova tarefa',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: LivocaColors.pinkDark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'O que você quer fazer?',
                errorText: _error,
                counterText: '',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            if (!editing) ...[
              const SizedBox(height: 16),
              const Text('Quando?', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in PeriodType.values)
                    ChoiceChip(
                      label: Text(p.shortLabel),
                      avatar: Icon(
                        p.icon,
                        size: 18,
                        color: _period == p ? Colors.white : LivocaColors.pink,
                      ),
                      selected: _period == p,
                      showCheckmark: false,
                      selectedColor: LivocaColors.pink,
                      backgroundColor: LivocaColors.blush,
                      labelStyle: TextStyle(
                        color: _period == p ? Colors.white : LivocaColors.pinkDark,
                        fontWeight: FontWeight.w600,
                      ),
                      side: const BorderSide(color: LivocaColors.pinkLight),
                      onSelected: (_) => setState(() => _period = p),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(editing ? 'Salvar' : 'Adicionar')),
          ],
        ),
      ),
    );
  }
}
