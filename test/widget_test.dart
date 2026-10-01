import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:livoca/app_state.dart';
import 'package:livoca/main.dart';
import 'package:livoca/models.dart';
import 'package:livoca/screens/agenda_screen.dart';
import 'package:livoca/screens/celebration_screen.dart';
import 'package:livoca/screens/daily_briefing_screen.dart';
import 'package:livoca/screens/tasks_screen.dart';
import 'package:livoca/widgets/task_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

String todayKey() {
  final d = DateTime.now();
  return '${d.year}-${d.month}-${d.day}';
}

DateTime today() => PeriodType.daily.startOf(DateTime.now());

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// O calendário entrega os dias em UTC.
DateTime utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Tela de celular (390 x 844).
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> taskJson(
  String id,
  String title, {
  PeriodType period = PeriodType.daily,
  DateTime? start,
  DateTime? date,
  TaskStatus status = TaskStatus.active,
}) {
  final s = date ?? start ?? period.startOf(DateTime.now());
  return Task(
    id: id,
    title: title,
    period: date == null ? period : PeriodType.daily,
    periodStart: s,
    date: date,
    createdAt: s,
    status: status,
  ).toJson();
}

Future<AppState> pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
  usePhoneScreen(tester);
  SharedPreferences.setMockInitialValues(prefs);
  final state = await AppState.load();
  await tester.pumpWidget(LivocaApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Finder get mainList =>
    find.descendant(of: find.byType(TasksScreen), matching: find.byType(Scrollable)).first;

Finder get dropPanelOpacity => find
    .ancestor(of: find.text('Solte a tarefa em um período'), matching: find.byType(AnimatedOpacity))
    .first;

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
  });

  group('PeriodType', () {
    final d = DateTime(2026, 9, 30, 15, 20); // quarta-feira

    test('início dos períodos', () {
      expect(PeriodType.daily.startOf(d), DateTime(2026, 9, 30));
      expect(PeriodType.weekly.startOf(d), DateTime(2026, 9, 28));
      expect(PeriodType.monthly.startOf(d), DateTime(2026, 9));
      expect(PeriodType.quarterly.startOf(d), DateTime(2026, 7));
      expect(PeriodType.semiannual.startOf(d), DateTime(2026, 7));
      expect(PeriodType.yearly.startOf(d), DateTime(2026));
    });

    test('fim dos períodos', () {
      expect(PeriodType.weekly.endOf(DateTime(2026, 9, 28)), DateTime(2026, 10, 5));
      expect(PeriodType.quarterly.endOf(DateTime(2026, 10)), DateTime(2027));
      expect(PeriodType.semiannual.endOf(DateTime(2026, 7)), DateTime(2027));
    });
  });

  group('Task', () {
    final d = DateTime(2026, 9, 30, 15, 20); // quarta-feira

    Task dated(DateTime day, {bool isTask = true}) => Task(
      id: 'x',
      title: 'x',
      period: PeriodType.daily,
      periodStart: day,
      date: day,
      isTask: isTask,
      createdAt: day,
    );

    test('tarefa de período passado fica atrasada', () {
      final t = Task(
        id: '1',
        title: 'x',
        period: PeriodType.daily,
        periodStart: DateTime(2026, 9, 29),
        createdAt: DateTime(2026, 9, 29),
      );
      expect(t.isOverdue(d), isTrue);
      expect(t.bucket(d), isNull);
      t.status = TaskStatus.paused;
      expect(t.isOverdue(d), isFalse);
    });

    test('item com dia marcado vai para a menor fileira atual que contém o dia', () {
      expect(dated(DateTime(2026, 9, 30)).bucket(d), PeriodType.daily);
      expect(dated(DateTime(2026, 10, 2)).bucket(d), PeriodType.weekly);
      expect(dated(DateTime(2026, 9, 12)).isOverdue(d), isTrue);
      expect(dated(DateTime(2026, 10, 15)).bucket(d), PeriodType.semiannual);
      expect(dated(DateTime(2027, 2, 1)).bucket(d), isNull);
      expect(dated(DateTime(2027, 2, 1)).isUpcoming(d), isTrue);
    });

    test('compromisso que não é tarefa fica só na agenda', () {
      final t = dated(DateTime(2026, 9, 30), isTask: false);
      expect(t.bucket(d), isNull);
      expect(t.isOnDay(DateTime(2026, 9, 30)), isTrue);
      expect(dated(DateTime(2026, 9, 29), isTask: false).isOverdue(d), isFalse);
    });

    test('tarefa sem dia ocupa o período todo', () {
      final t = Task(
        id: 'w',
        title: 'w',
        period: PeriodType.weekly,
        periodStart: DateTime(2026, 9, 28),
        createdAt: d,
      );
      expect(t.coversDay(DateTime(2026, 9, 27)), isFalse);
      expect(t.coversDay(DateTime(2026, 9, 28)), isTrue);
      expect(t.coversDay(DateTime(2026, 10, 4)), isTrue);
      expect(t.coversDay(DateTime(2026, 10, 5)), isFalse);
    });

    test('json ida e volta', () {
      final t = Task(
        id: '1',
        title: 'Dentista',
        period: PeriodType.daily,
        periodStart: DateTime(2026, 10, 2),
        date: DateTime(2026, 10, 2),
        timeMinutes: 14 * 60 + 30,
        note: 'levar exame',
        isTask: false,
        createdAt: DateTime(2026, 9, 2),
        completedAt: DateTime(2026, 9, 3),
      );
      final back = Task.fromJson(t.toJson());
      expect(back.title, 'Dentista');
      expect(back.date, DateTime(2026, 10, 2));
      expect(back.timeMinutes, 870);
      expect(back.note, 'levar exame');
      expect(back.isTask, isFalse);
      expect(back.isDone, isTrue);
    });

    test('json da v1 (sem os campos novos) continua funcionando', () {
      final back = Task.fromJson({
        'id': '1',
        'title': 'Ler',
        'period': 'monthly',
        'periodStart': DateTime(2026, 9).toIso8601String(),
        'status': 'active',
        'completedAt': null,
        'createdAt': DateTime(2026, 9, 2).toIso8601String(),
      });
      expect(back.hasDate, isFalse);
      expect(back.isTask, isTrue);
      expect(back.note, '');
    });

    test('textos de data', () {
      expect(timeLabel(9 * 60 + 5), '09:05');
      expect(dayLabel(today()), 'hoje');
      expect(dayLabel(addDays(today(), 1)), 'amanhã');
    });
  });

  group('AppState', () {
    test('mover, pausar e comemorar', () async {
      SharedPreferences.setMockInitialValues({});
      final state = await AppState.load();
      await state.saveTask(title: 'A', period: PeriodType.daily);
      await state.saveTask(title: 'B', period: PeriodType.daily);
      final a = state.currentTasks(PeriodType.daily).first;
      final b = state.currentTasks(PeriodType.daily).last;

      expect(await state.toggleDone(a), isNull);
      await state.pause(b);
      expect(state.pausedTasks.length, 1);
      // Com B pausada, só resta A (já feita). Desmarca e marca de novo -> parabéns.
      await state.toggleDone(a);
      expect(await state.toggleDone(a), PeriodType.daily);
      expect(state.completedCount(PeriodType.daily), 1);
      expect(state.completedCount(PeriodType.yearly), 1);
      expect(state.completedCount(null), 1);

      await state.moveTo(b, PeriodType.weekly);
      expect(state.pausedTasks, isEmpty);
      expect(state.currentTasks(PeriodType.weekly).single.title, 'B');

      // Persistência.
      final reloaded = await AppState.load();
      expect(reloaded.currentTasks(PeriodType.weekly).single.title, 'B');
    });

    test('tarefas e compromissos são o mesmo item', () async {
      SharedPreferences.setMockInitialValues({});
      final state = await AppState.load();
      final t0 = today();

      // Compromisso de hoje: aparece na agenda e na lista de tarefas.
      final dentist = await state.saveTask(
        title: 'Dentista',
        date: t0,
        timeMinutes: 14 * 60 + 30,
        note: 'levar exame',
      );
      expect(state.itemsOn(utcDay(t0)), [dentist]);
      expect(state.currentTasks(PeriodType.daily), [dentist]);

      // Desligar "mostrar na lista de tarefas": continua só na agenda.
      await state.saveTask(
        task: dentist,
        title: 'Dentista',
        date: t0,
        timeMinutes: 14 * 60 + 30,
        note: 'levar exame',
        isTask: false,
      );
      expect(state.currentTasks(PeriodType.daily), isEmpty);
      expect(state.itemsOn(utcDay(t0)).single.isTask, isFalse);
      expect(await state.toggleDone(dentist), isNull);
      expect(dentist.isDone, isFalse);

      // E religar a qualquer momento.
      await state.saveTask(task: dentist, title: 'Dentista', date: t0, timeMinutes: 870);
      expect(state.currentTasks(PeriodType.daily), [dentist]);

      // Tarefa da semana sem dia: ocupa a semana inteira na agenda.
      await state.saveTask(title: 'Faxina', period: PeriodType.weekly);
      final ws = PeriodType.weekly.startOf(DateTime.now());
      expect(state.hasSpanOn(utcDay(addDays(ws, -1))), isFalse);
      for (var i = 0; i < 7; i++) {
        expect(state.hasSpanOn(utcDay(addDays(ws, i))), isTrue, reason: 'dia $i');
      }
      expect(state.hasSpanOn(utcDay(addDays(ws, 7))), isFalse);
      expect(state.spanningOn(utcDay(ws)).single.title, 'Faxina');
    });

    test('editar o nome de uma tarefa atrasada não a tira de "atrasadas"', () async {
      SharedPreferences.setMockInitialValues({});
      final state = await AppState.load();
      final yesterday = addDays(today(), -1);
      final t = await state.saveTask(title: 'Velha', date: yesterday);
      expect(state.overdueTasks, [t]);
      await state.saveTask(task: t, title: 'Velha 2', date: yesterday);
      expect(state.overdueTasks.single.title, 'Velha 2');

      // Mover para um período tira o dia marcado.
      await state.moveTo(t, PeriodType.monthly);
      expect(t.hasDate, isFalse);
      expect(state.currentTasks(PeriodType.monthly), [t]);
    });

    test('compromissos da v1 viram itens da agenda', () async {
      final tomorrow = addDays(today(), 1);
      final lastWeek = addDays(today(), -7);
      SharedPreferences.setMockInitialValues({
        'appointments': jsonEncode([
          {
            'id': 'a',
            'title': 'Médico',
            'dateTime': DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10).toIso8601String(),
            'note': '',
          },
          {'id': 'b', 'title': 'Antigo', 'dateTime': lastWeek.toIso8601String(), 'note': 'x'},
        ]),
      });
      final state = await AppState.load();
      final medico = state.itemsOn(utcDay(tomorrow)).single;
      expect(medico.title, 'Médico');
      expect(medico.timeMinutes, 600);
      expect(medico.isTask, isTrue);
      // O que já passou fica só na agenda (não vira tarefa atrasada).
      expect(state.itemsOn(utcDay(lastWeek)).single.isTask, isFalse);
      expect(state.overdueTasks, isEmpty);

      final reloaded = await AppState.load();
      expect(reloaded.itemsOn(utcDay(tomorrow)).length, 1);

      // Os da v1 podem ser marcados como feitos (os de hoje/futuros já são tarefas).
      await state.toggleDone(medico);
      expect(medico.isDone, isTrue);

      // Um compromisso antigo pode virar tarefa: ligando "mostrar na lista de tarefas".
      final antigo = state.itemsOn(utcDay(lastWeek)).single;
      await state.saveTask(
        task: antigo,
        title: antigo.title,
        date: antigo.date,
        timeMinutes: antigo.timeMinutes,
        note: antigo.note,
        isTask: true,
      );
      expect(state.overdueTasks, [antigo]);
      await state.toggleDone(antigo);
      expect(antigo.isDone, isTrue);
      expect(state.overdueTasks, isEmpty);
    });
  });

  testWidgets('primeiro acesso, criar tarefa e ver parabéns', (tester) async {
    await pumpApp(tester, {});

    expect(find.text('Começar'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(1), '25');
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();

    expect(find.text('Oi, Ana!'), findsOneWidget);

    await tester.tap(find.text('Tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'O que você quer fazer?'), 'Beber água');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Beber água'), findsOneWidget);

    await tester.scrollUntilVisible(find.byType(Checkbox), 200, scrollable: mainList);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CelebrationScreen), findsOneWidget);
    expect(find.text('Parabéns, Ana!'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(CelebrationScreen), findsNothing);

    await tester.scrollUntilVisible(find.text('Em pausa'), 300, scrollable: mainList);
    expect(find.text('Não realizadas a tempo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agenda: tarefas do período, compromissos e "mostrar na lista"', (tester) async {
    await pumpApp(tester, {
      'profile': '{"name":"Ana","age":25}',
      'lastBriefing': todayKey(),
      'tasks': jsonEncode([taskJson('w', 'Faxina', period: PeriodType.weekly)]),
    });
    final inTasks = find.descendant(of: find.byType(TasksScreen), matching: find.text('Dentista'));
    final inAgenda = find.descendant(
      of: find.byType(AgendaScreen),
      matching: find.text('Dentista'),
    );

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    // A tarefa da semana aparece ocupando o período.
    expect(find.text('Ocupando o período'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AgendaScreen), matching: find.text('Faxina')),
      findsOneWidget,
    );

    // Novo compromisso na agenda, no dia selecionado (hoje).
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Novo compromisso'), findsOneWidget);
    expect(find.text('Mostrar na lista de tarefas'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'O que você quer fazer?'), 'Dentista');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();
    expect(inAgenda, findsOneWidget);

    // Também aparece na lista de tarefas, em "Hoje".
    await tester.tap(find.text('Tarefas'));
    await tester.pumpAndSettle();
    expect(inTasks, findsOneWidget);

    // Desliga "mostrar na lista de tarefas" pela agenda.
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    await tester.tap(inAgenda);
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    await tester.tap(find.text('Mostrar na lista de tarefas'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Só na agenda'), findsOneWidget);

    await tester.tap(find.text('Tarefas'));
    await tester.pumpAndSettle();
    expect(inTasks, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumo do dia: tarefas de hoje e atrasadas', (tester) async {
    final state = await pumpApp(tester, {
      'profile': '{"name":"Ana","age":25}',
      'tasks': jsonEncode([
        taskJson('1', 'Estudar'),
        taskJson('2', 'Correr', start: addDays(today(), -1)),
      ]),
    });

    expect(find.byType(DailyBriefingScreen), findsOneWidget);
    expect(find.text('Hoje você tem 1 tarefa'), findsOneWidget);
    expect(find.text('Estudar'), findsOneWidget);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Ficaram para trás...'), findsOneWidget);
    expect(find.text('Correr'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyBriefingScreen), findsNothing);
    expect(find.text('Tarefas concluídas'), findsOneWidget);
    expect(state.needsDailyBriefing, isFalse);

    // Filtro do contador.
    await tester.ensureVisible(find.text('Total'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total'));
    await tester.pumpAndSettle();
    expect(find.text('desde o início'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('arrastar', () {
    Future<AppState> setUp(WidgetTester tester) => pumpApp(tester, {
      'profile': '{"name":"Ana","age":25}',
      'lastBriefing': todayKey(),
      'tasks': jsonEncode([
        taskJson('1', 'Estudar'),
        taskJson('2', 'Correr', start: addDays(today(), -1)),
        taskJson('3', 'Violão', status: TaskStatus.paused),
      ]),
    });

    Future<void> showTask(WidgetTester tester, String title) async {
      tester.state<ScrollableState>(mainList).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(title), 150, scrollable: mainList);
      await tester.pumpAndSettle();
    }

    Future<void> dropOn(WidgetTester tester, TestGesture gesture, String chip) async {
      // O painel de destinos aparece na hora, no topo.
      expect(tester.widget<AnimatedOpacity>(dropPanelOpacity).opacity, 1);
      await gesture.moveTo(tester.getCenter(find.text(chip).last));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    /// Segurando o cartão.
    Future<void> longPressDrag(WidgetTester tester, String title, String chip) async {
      await showTask(tester, title);
      final gesture = await tester.startGesture(tester.getCenter(find.text(title)));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await dropOn(tester, gesture, chip);
    }

    /// Pelo ⠿, sem esperar.
    Future<void> handleDrag(WidgetTester tester, String title, String chip) async {
      await showTask(tester, title);
      final handle = find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(TaskCard)),
        matching: find.byIcon(Icons.drag_indicator_rounded),
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await dropOn(tester, gesture, chip);
    }

    Task byId(AppState state, String id) => [
      for (final p in PeriodType.values) ...state.currentTasks(p),
      ...state.overdueTasks,
      ...state.pausedTasks,
    ].firstWhere((t) => t.id == id);

    testWidgets('pelo ⠿ e segurando: períodos, pausa e atrasadas', (tester) async {
      final state = await setUp(tester);
      expect(tester.widget<AnimatedOpacity>(dropPanelOpacity).opacity, 0);

      // Hoje -> Semana, pelo ⠿.
      await handleDrag(tester, 'Estudar', 'Semana');
      expect(byId(state, '1').bucket(DateTime.now()), PeriodType.weekly);

      // Atrasada -> Dia, segurando.
      await longPressDrag(tester, 'Correr', 'Dia');
      expect(state.overdueTasks, isEmpty);
      expect(state.currentTasks(PeriodType.daily).map((t) => t.id), contains('2'));

      // Hoje -> Pausar, pelo ⠿.
      await handleDrag(tester, 'Correr', 'Pausar');
      expect(state.pausedTasks.map((t) => t.id), containsAll(['2', '3']));

      // Pausada -> Ano (retoma), segurando.
      await longPressDrag(tester, 'Violão', 'Ano');
      expect(byId(state, '3').isPaused, isFalse);
      expect(state.currentTasks(PeriodType.yearly).map((t) => t.id), contains('3'));

      // O painel some e o botão de nova tarefa volta; a dica some depois do 1º arraste.
      expect(tester.widget<AnimatedOpacity>(dropPanelOpacity).opacity, 0);
      expect(find.text('Tarefa'), findsOneWidget);
      expect(state.dragTipSeen, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a lista rola sozinha e dá para soltar direto numa fileira', (tester) async {
      final state = await setUp(tester);
      await showTask(tester, 'Estudar');
      final scroll = tester.state<ScrollableState>(mainList).position;
      final before = scroll.pixels;

      final handle = find.descendant(
        of: find.ancestor(of: find.text('Estudar'), matching: find.byType(TaskCard)),
        matching: find.byIcon(Icons.drag_indicator_rounded),
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      // Leva o dedo para perto da borda de baixo e espera a lista rolar.
      final listRect = tester.getRect(mainList);
      await gesture.moveTo(Offset(listRect.center.dx, listRect.bottom - 10));
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scroll.pixels, greaterThan(before));
      expect(scroll.pixels, scroll.maxScrollExtent);

      // Solta na fileira "Em pausa", que apareceu com a rolagem.
      await gesture.moveTo(tester.getCenter(find.text('Em pausa').first));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(state.pausedTasks.map((t) => t.id), contains('1'));
      expect(tester.takeException(), isNull);
    });
  });
}
