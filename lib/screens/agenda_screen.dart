import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/panda.dart';
import '../widgets/task_widgets.dart';
import 'celebration_screen.dart';

/// Agenda: mostra os itens com dia marcado e as tarefas que ocupam um
/// período inteiro (barra contínua embaixo dos dias do período).
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  Future<void> _toggle(AppState state, Task task) async {
    final period = await state.toggleDone(task);
    if (period != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CelebrationScreen(period: period, name: state.profile?.name ?? ''),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final day = DateTime(_selected.year, _selected.month, _selected.day);
    final items = state.itemsOn(day);
    final spanning = state.spanningOn(day);
    final now = DateTime.now();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.only(bottom: 8),
            child: TableCalendar<Task>(
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
              eventLoader: state.itemsOn,
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              onFormatChanged: (f) => setState(() => _format = f),
              onPageChanged: (focused) => _focused = focused,
              calendarBuilders: CalendarBuilders<Task>(
                markerBuilder: (context, d, events) =>
                    _DayMarkers(dots: events.length, span: state.hasSpanOn(d)),
              ),
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
                weekendTextStyle: TextStyle(color: LivocaColors.pink),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _Legend(),
          const SizedBox(height: 12),
          Text(
            capitalize(DateFormat("EEEE, d 'de' MMMM").format(day)),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: LivocaColors.pinkDark,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty && spanning.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Opacity(opacity: 0.7, child: Panda(size: 90)),
                  const SizedBox(height: 8),
                  Text('Nada marcado neste dia.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AgendaTile(
                task: t,
                badge: t.timeMinutes == null ? 'Dia todo' : timeLabel(t.timeMinutes!),
                subtitle: t.isTask ? (t.note.isEmpty ? null : t.note) : _onlyAgenda(t),
                overdue: t.isOverdue(now),
                onToggle: () => _toggle(state, t),
              ),
            ),
          if (spanning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ocupando o período',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            for (final t in spanning)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AgendaTile(
                  task: t,
                  badge: t.period.shortLabel,
                  subtitle: periodRangeLabel(t.period, t.periodStart),
                  overdue: t.isOverdue(now),
                  onToggle: () => _toggle(state, t),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'agenda_fab',
        onPressed: () => showTaskEditor(context, initialDate: day),
        icon: const Icon(Icons.event_available_rounded),
        label: const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  static String _onlyAgenda(Task t) => t.note.isEmpty ? 'Só na agenda' : 'Só na agenda • ${t.note}';
}

/// Pontinhos para itens do dia e uma barra para tarefas que ocupam o período.
class _DayMarkers extends StatelessWidget {
  const _DayMarkers({required this.dots, required this.span});

  final int dots;
  final bool span;

  @override
  Widget build(BuildContext context) {
    if (dots == 0 && !span) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < dots.clamp(0, 3); i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: LivocaColors.pinkDark,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Encosta nas bordas da célula para formar uma faixa contínua.
          Container(height: 4, color: span ? LivocaColors.pinkLight : Colors.transparent),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, color: Colors.grey.shade700);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: LivocaColors.pinkDark, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('Marcado no dia', style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 18, height: 4, color: LivocaColors.pinkLight),
            const SizedBox(width: 6),
            Text('Tarefa do período', style: style),
          ],
        ),
      ],
    );
  }
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({
    required this.task,
    required this.badge,
    required this.subtitle,
    required this.overdue,
    required this.onToggle,
  });

  final Task task;
  final String badge;
  final String? subtitle;
  final bool overdue;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = task;
    return Dismissible(
      key: ValueKey('agenda_${t.id}'),
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
      confirmDismiss: (_) => confirmDelete(context, t),
      onDismissed: (_) => AppScope.read(context).deleteTask(t),
      child: Card(
        color: overdue ? const Color(0xFFFFEBEE) : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showTaskEditor(context, task: t),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 64),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.isTask ? LivocaColors.pinkLight : const Color(0xFFE1BEE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: LivocaColors.pinkDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          decoration: t.isDone ? TextDecoration.lineThrough : null,
                          color: t.isDone ? Colors.grey : Colors.black87,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                ),
                if (t.isTask)
                  Checkbox(
                    value: t.isDone,
                    activeColor: LivocaColors.pink,
                    side: const BorderSide(color: LivocaColors.pink, width: 2),
                    onChanged: (_) => onToggle(),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.chevron_right_rounded, color: LivocaColors.pinkLight),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
