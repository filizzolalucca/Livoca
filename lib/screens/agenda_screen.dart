import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/panda.dart';
import '../widgets/task_widgets.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final appointments = state.appointmentsOn(_selected);
    final dueTasks = state.tasksDueOn(_selected);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.only(bottom: 8),
            child: TableCalendar<Object>(
              locale: 'pt_BR',
              firstDay: DateTime(2000),
              lastDay: DateTime(2100, 12, 31),
              focusedDay: _focused,
              calendarFormat: _format,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Mês',
                CalendarFormat.twoWeeks: '2 semanas',
                CalendarFormat.week: 'Semana',
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (d) => isSameDay(d, _selected),
              eventLoader: (day) => [...state.appointmentsOn(day), ...state.tasksDueOn(day)],
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              onFormatChanged: (f) => setState(() => _format = f),
              onPageChanged: (focused) => _focused = focused,
              headerStyle: HeaderStyle(
                titleCentered: true,
                // O botão mostra o formato atual (o padrão da biblioteca mostra o próximo).
                formatButtonShowsNext: false,
                titleTextFormatter: (date, locale) =>
                    capitalize(DateFormat('MMMM y', locale).format(date)),
                titleTextStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: LivocaColors.pinkDark,
                ),
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: LivocaColors.pink),
                  borderRadius: BorderRadius.circular(12),
                ),
                formatButtonTextStyle: const TextStyle(color: LivocaColors.pinkDark),
                leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: LivocaColors.pink),
                rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: LivocaColors.pink),
              ),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: LivocaColors.pinkLight,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: LivocaColors.pinkDark,
                  fontWeight: FontWeight.w800,
                ),
                selectedDecoration: BoxDecoration(color: LivocaColors.pink, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(
                  color: LivocaColors.pinkDark,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                weekendTextStyle: TextStyle(color: LivocaColors.pink),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            capitalize(DateFormat("EEEE, d 'de' MMMM").format(_selected)),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: LivocaColors.pinkDark,
            ),
          ),
          const SizedBox(height: 8),
          if (appointments.isEmpty && dueTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Opacity(opacity: 0.7, child: Panda(size: 90)),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhum compromisso neste dia.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          for (final a in appointments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AppointmentTile(appointment: a),
            ),
          if (dueTasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Prazo final de tarefas',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            for (final t in dueTasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      t.isDone ? Icons.check_circle_rounded : t.period.icon,
                      color: t.isDone ? Colors.green : LivocaColors.pink,
                    ),
                    title: Text(
                      t.title,
                      style: TextStyle(decoration: t.isDone ? TextDecoration.lineThrough : null),
                    ),
                    subtitle: Text('Tarefa • ${t.period.shortLabel}'),
                  ),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'agenda_fab',
        onPressed: () => showAppointmentEditor(context, initialDay: _selected),
        icon: const Icon(Icons.event_available_rounded),
        label: const Text('Compromisso', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Dismissible(
      key: ValueKey(a.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE57373),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir compromisso?'),
          content: Text('"${a.title}" será excluído.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
          ],
        ),
      ),
      onDismissed: (_) => AppScope.read(context).deleteAppointment(a),
      child: Card(
        child: ListTile(
          onTap: () => showAppointmentEditor(context, appointment: a),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: LivocaColors.pinkLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              DateFormat('HH:mm').format(a.dateTime),
              style: const TextStyle(fontWeight: FontWeight.w800, color: LivocaColors.pinkDark),
            ),
          ),
          title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: a.note.isEmpty ? null : Text(a.note),
          trailing: const Icon(Icons.chevron_right_rounded, color: LivocaColors.pinkLight),
        ),
      ),
    );
  }
}

/// Criar (appointment == null) ou editar um compromisso.
Future<void> showAppointmentEditor(
  BuildContext context, {
  Appointment? appointment,
  DateTime? initialDay,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _AppointmentEditor(appointment: appointment, initialDay: initialDay),
  );
}

class _AppointmentEditor extends StatefulWidget {
  const _AppointmentEditor({this.appointment, this.initialDay});

  final Appointment? appointment;
  final DateTime? initialDay;

  @override
  State<_AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<_AppointmentEditor> {
  late final _title = TextEditingController(text: widget.appointment?.title ?? '');
  late final _note = TextEditingController(text: widget.appointment?.note ?? '');
  late DateTime _date;
  late TimeOfDay _time;
  String? _error;

  @override
  void initState() {
    super.initState();
    final base = widget.appointment?.dateTime;
    if (base != null) {
      _date = DateTime(base.year, base.month, base.day);
      _time = TimeOfDay.fromDateTime(base);
    } else {
      final d = widget.initialDay ?? DateTime.now();
      _date = DateTime(d.year, d.month, d.day);
      _time = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Escreva o nome do compromisso');
      return;
    }
    final state = AppScope.read(context);
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final a = widget.appointment;
    if (a == null) {
      await state.addAppointment(_title.text, dt, _note.text);
    } else {
      await state.updateAppointment(a, _title.text, dt, _note.text);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.appointment != null;
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
                editing ? 'Editar compromisso' : 'Novo compromisso',
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
                  labelText: 'Compromisso',
                  errorText: _error,
                  counterText: '',
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PickerButton(
                      icon: Icons.calendar_today_rounded,
                      label: DateFormat('dd/MM/yyyy').format(_date),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickerButton(
                      icon: Icons.access_time_rounded,
                      label: _time.format(context),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Observação (opcional)'),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: Text(editing ? 'Salvar' : 'Adicionar')),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
