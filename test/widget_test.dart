import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:livoca/app_state.dart';
import 'package:livoca/main.dart';
import 'package:livoca/models.dart';
import 'package:livoca/screens/celebration_screen.dart';
import 'package:livoca/screens/daily_briefing_screen.dart';
import 'package:livoca/screens/tasks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

String todayKey() {
  final d = DateTime.now();
  return '${d.year}-${d.month}-${d.day}';
}

/// Tela de celular (390 x 844).
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

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

    test('tarefa de período passado fica atrasada', () {
      final t = Task(
        id: '1',
        title: 'x',
        period: PeriodType.daily,
        periodStart: DateTime(2026, 9, 29),
        createdAt: DateTime(2026, 9, 29),
      );
      expect(t.isOverdue(d), isTrue);
      expect(t.isCurrent(d), isFalse);
      t.status = TaskStatus.paused;
      expect(t.isOverdue(d), isFalse);
    });

    test('json ida e volta', () {
      final t = Task(
        id: '1',
        title: 'Ler',
        period: PeriodType.monthly,
        periodStart: DateTime(2026, 9),
        createdAt: DateTime(2026, 9, 2),
        completedAt: DateTime(2026, 9, 3),
      );
      final back = Task.fromJson(t.toJson());
      expect(back.title, 'Ler');
      expect(back.period, PeriodType.monthly);
      expect(back.isDone, isTrue);
    });
  });

  group('AppState', () {
    test('mover, pausar e comemorar', () async {
      SharedPreferences.setMockInitialValues({});
      final state = await AppState.load();
      await state.addTask('A', PeriodType.daily);
      await state.addTask('B', PeriodType.daily);
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
  });

  testWidgets('primeiro acesso, criar tarefa e ver parabéns', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    await tester.pumpWidget(LivocaApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Começar'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(1), '25');
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();

    expect(find.text('Oi, Ana!'), findsOneWidget);

    await tester.tap(find.text('Tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Beber água');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Beber água'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: find
          .descendant(of: find.byType(TasksScreen), matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CelebrationScreen), findsOneWidget);
    expect(find.text('Parabéns, Ana!'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(CelebrationScreen), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Em pausa'),
      300,
      scrollable: find
          .descendant(of: find.byType(TasksScreen), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Não realizadas a tempo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agenda abre', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues({
      'profile': '{"name":"Ana","age":25}',
      'lastBriefing': todayKey(),
    });
    final state = await AppState.load();
    await tester.pumpWidget(LivocaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Compromisso'), findsOneWidget);
    await tester.tap(find.text('Compromisso'));
    await tester.pumpAndSettle();
    expect(find.text('Novo compromisso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumo do dia: tarefas de hoje e atrasadas', (tester) async {
    usePhoneScreen(tester);
    final now = DateTime.now();
    final today = PeriodType.daily.startOf(now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    Map<String, dynamic> task(String id, String title, DateTime start) => Task(
      id: id,
      title: title,
      period: PeriodType.daily,
      periodStart: start,
      createdAt: start,
    ).toJson();
    SharedPreferences.setMockInitialValues({
      'profile': '{"name":"Ana","age":25}',
      'tasks': jsonEncode([task('1', 'Estudar', today), task('2', 'Correr', yesterday)]),
    });
    final state = await AppState.load();
    await tester.pumpWidget(LivocaApp(state: state));
    await tester.pumpAndSettle();

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

  testWidgets('arrastar tarefas entre períodos, pausa e atrasadas', (tester) async {
    usePhoneScreen(tester);
    final now = DateTime.now();
    final today = PeriodType.daily.startOf(now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    Map<String, dynamic> task(
      String id,
      String title,
      DateTime start, {
      TaskStatus status = TaskStatus.active,
    }) => Task(
      id: id,
      title: title,
      period: PeriodType.daily,
      periodStart: start,
      createdAt: start,
      status: status,
    ).toJson();
    SharedPreferences.setMockInitialValues({
      'profile': '{"name":"Ana","age":25}',
      'lastBriefing': todayKey(),
      'tasks': jsonEncode([
        task('1', 'Estudar', today),
        task('2', 'Correr', yesterday),
        task('3', 'Violão', today, status: TaskStatus.paused),
      ]),
    });
    final state = await AppState.load();
    await tester.pumpWidget(LivocaApp(state: state));
    await tester.pumpAndSettle();

    final mainList = find
        .descendant(of: find.byType(TasksScreen), matching: find.byType(Scrollable))
        .first;

    Future<void> dragTo(String taskTitle, String chip) async {
      tester.state<ScrollableState>(mainList).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(taskTitle), 150, scrollable: mainList);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(find.text(taskTitle)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // A barra de destinos aparece durante o arraste.
      expect(find.text('Solte a tarefa em um período'), findsOneWidget);
      await gesture.moveTo(tester.getCenter(find.text(chip).last));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    Task byId(String id) => [
      ...state.currentTasks(PeriodType.daily),
      ...state.currentTasks(PeriodType.weekly),
      ...state.currentTasks(PeriodType.yearly),
      ...state.overdueTasks,
      ...state.pausedTasks,
    ].firstWhere((t) => t.id == id);

    // Hoje -> Semana
    await dragTo('Estudar', 'Semana');
    expect(byId('1').period, PeriodType.weekly);
    expect(state.currentTasks(PeriodType.weekly).map((t) => t.id), contains('1'));

    // Atrasada -> Dia (volta a ser uma tarefa de hoje)
    await dragTo('Correr', 'Dia');
    expect(state.overdueTasks, isEmpty);
    expect(state.currentTasks(PeriodType.daily).map((t) => t.id), contains('2'));

    // Hoje -> Pausar
    await dragTo('Correr', 'Pausar');
    expect(state.pausedTasks.map((t) => t.id), containsAll(['2', '3']));

    // Pausada -> Ano (retoma)
    await dragTo('Violão', 'Ano');
    expect(byId('3').isPaused, isFalse);
    expect(state.currentTasks(PeriodType.yearly).map((t) => t.id), contains('3'));

    // A barra sai da área visível depois de soltar e o botão de nova tarefa volta.
    final visibleBottom = tester.getRect(find.byType(TasksScreen)).bottom;
    expect(
      tester.getTopLeft(find.text('Solte a tarefa em um período')).dy,
      greaterThanOrEqualTo(visibleBottom),
    );
    expect(find.text('Tarefa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
