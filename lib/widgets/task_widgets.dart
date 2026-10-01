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

String timeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// "hoje", "amanhã", "sex, 03/10" ou "03/02/2027".
String dayLabel(DateTime day) {
  final today = PeriodType.daily.startOf(DateTime.now());
  final d = DateTime(day.year, day.month, day.day);
  if (d == today) return 'hoje';
  if (d == DateTime(today.year, today.month, today.day + 1)) return 'amanhã';
  if (d.year != today.year) return DateFormat('dd/MM/yyyy').format(d);
  return DateFormat('EEE, dd/MM').format(d).replaceAll('.', '');
}

/// Quando o item acontece, em texto curto.
String whenLabel(Task t) {
  final d = t.date;
  if (d == null) return '${t.period.shortLabel} • ${periodRangeLabel(t.period, t.periodStart)}';
  final time = t.timeMinutes;
  return time == null ? dayLabel(d) : '${dayLabel(d)} • ${timeLabel(time)}';
}

/// Cartão de tarefa. Pode ser arrastado para outra fileira de dois jeitos:
/// pelo ⠿ (na hora) ou segurando o cartão.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
    this.overdue = false,
    this.dimmed = false,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onDragStarted;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final bool overdue;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final handle = Draggable<Task>(
      data: task,
      feedback: _DragFeedback(task: task),
      dragAnchorStrategy: _DragFeedback.anchor,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => onDragEnd?.call(),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(6, 14, 12, 14),
        child: Icon(Icons.drag_indicator_rounded, color: LivocaColors.pink),
      ),
    );

    return LongPressDraggable<Task>(
      data: task,
      delay: const Duration(milliseconds: 300),
      hapticFeedbackOnStart: true,
      feedback: _DragFeedback(task: task),
      dragAnchorStrategy: _DragFeedback.anchor,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => onDragEnd?.call(),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dimmed ? 0.35 : 1,
        child: _TaskCardBody(task: task, onToggle: onToggle, overdue: overdue, handle: handle),
      ),
    );
  }
}

/// Etiqueta compacta que segue o dedo durante o arraste. Fica acima do dedo
/// para não esconder o destino onde a tarefa vai ser solta.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.task});

  final Task task;

  static const _width = 240.0;
  static const _height = 48.0;

  static Offset anchor(Draggable<Object> _, BuildContext _, Offset _) =>
      const Offset(_width / 2, _height + 28);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x88C2185B),
      shape: const StadiumBorder(side: BorderSide(color: LivocaColors.pink, width: 2)),
      child: SizedBox(
        width: _width,
        height: _height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator_rounded, color: LivocaColors.pink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: LivocaColors.pinkDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCardBody extends StatelessWidget {
  const _TaskCardBody({
    required this.task,
    required this.onToggle,
    required this.overdue,
    required this.handle,
  });

  final Task task;
  final VoidCallback? onToggle;
  final bool overdue;
  final Widget handle;

  @override
  Widget build(BuildContext context) {
    final String? subtitle;
    if (overdue) {
      subtitle = 'Era para: ${whenLabel(task)}';
    } else if (task.isPaused) {
      subtitle = 'Em pausa';
    } else if (task.hasDate) {
      subtitle = whenLabel(task);
    } else {
      subtitle = null;
    }

    return Card(
      color: overdue ? const Color(0xFFFFEBEE) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
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
                        child: Row(
                          children: [
                            if (task.hasDate && !overdue)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.event_rounded,
                                  size: 13,
                                  color: LivocaColors.pinkDark,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                subtitle,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (task.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (onToggle != null) _TaskMenu(task: task),
            handle,
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
            if (await confirmDelete(context, task)) await state.deleteTask(task);
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

Future<bool> confirmDelete(BuildContext context, Task task) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Excluir?'),
      content: Text('"${task.title}" será excluído da lista e da agenda.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
      ],
    ),
  );
  return ok ?? false;
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

/// Criar (task == null) ou editar um item. O mesmo editor serve para tarefas
/// e compromissos: escolha um período inteiro ou um dia específico.
Future<void> showTaskEditor(
  BuildContext context, {
  Task? task,
  PeriodType? initialPeriod,
  DateTime? initialDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _TaskEditor(
      task: task,
      initialPeriod: initialPeriod ?? PeriodType.daily,
      initialDate: initialDate,
    ),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task, required this.initialPeriod, this.initialDate});

  final Task? task;
  final PeriodType initialPeriod;
  final DateTime? initialDate;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _note = TextEditingController(text: widget.task?.note ?? '');
  late PeriodType _period;
  DateTime? _date;
  int? _time;
  late bool _isTask;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _period = t.hasDate ? PeriodType.daily : t.period;
      _date = t.date;
      _time = t.timeMinutes;
      _isTask = t.isTask;
    } else {
      _period = widget.initialPeriod;
      _date = widget.initialDate;
      _isTask = true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Fecha o teclado antes de abrir o calendário/relógio; senão o foco volta
  /// para o campo de texto e o teclado reabre quando o seletor fecha.
  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _pickDate() async {
    _dismissKeyboard();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    _dismissKeyboard();
    final t = _time;
    final picked = await showTimePicker(
      context: context,
      initialTime: t == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: t ~/ 60, minute: t % 60),
    );
    if (picked != null) setState(() => _time = picked.hour * 60 + picked.minute);
  }

  Future<void> _save() async {
    final text = _title.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escreva o nome');
      return;
    }
    await AppScope.read(context).saveTask(
      task: widget.task,
      title: text,
      period: _period,
      date: _date,
      timeMinutes: _time,
      note: _note.text,
      isTask: _isTask,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final task = widget.task!;
    if (!await confirmDelete(context, task)) return;
    if (!mounted) return;
    await AppScope.read(context).deleteTask(task);
    if (mounted) Navigator.pop(context);
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 18, color: selected ? Colors.white : LivocaColors.pink),
      selected: selected,
      showCheckmark: false,
      selectedColor: LivocaColors.pink,
      backgroundColor: LivocaColors.blush,
      labelStyle: TextStyle(
        color: selected ? Colors.white : LivocaColors.pinkDark,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: LivocaColors.pinkLight),
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    final date = _date;
    final time = _time;
    final String heading;
    if (editing) {
      heading = 'Editar';
    } else {
      heading = date == null ? 'Nova tarefa' : 'Novo compromisso';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: LivocaColors.pinkDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: !editing,
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
              ),
              const SizedBox(height: 16),
              const Text('Quando?', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in PeriodType.values)
                    _chip(
                      label: p.shortLabel,
                      icon: p.icon,
                      selected: date == null && _period == p,
                      onTap: () => setState(() {
                        _period = p;
                        _date = null;
                        _time = null;
                      }),
                    ),
                  _chip(
                    label: 'Dia específico',
                    icon: Icons.event_rounded,
                    selected: date != null,
                    onTap: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (date == null)
                Text(
                  'Aparece na agenda ocupando o período todo: '
                  '${periodRangeLabel(_period, _period.startOf(DateTime.now()))}.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.calendar_today_rounded,
                        label: DateFormat('EEE, dd/MM/yyyy').format(date).replaceAll('.', ''),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.access_time_rounded,
                        label: time == null ? 'Horário' : timeLabel(time),
                        onTap: _pickTime,
                      ),
                    ),
                    if (time != null)
                      IconButton(
                        tooltip: 'Tirar horário',
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => setState(() => _time = null),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: LivocaColors.pink,
                  value: _isTask,
                  onChanged: (v) => setState(() => _isTask = v),
                  title: const Text(
                    'Mostrar na lista de tarefas',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Desligue se for só um compromisso da agenda'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Observação (opcional)'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (editing) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFD32F2F)),
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Excluir'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(editing ? 'Salvar' : 'Adicionar'),
                    ),
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

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: LivocaColors.pinkDark,
        side: const BorderSide(color: LivocaColors.pinkLight, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
