import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Estado global do app. Tudo é salvo localmente com SharedPreferences.
class AppState extends ChangeNotifier {
  AppState._(this._prefs);

  static const _kProfile = 'profile';
  static const _kTasks = 'tasks';
  static const _kLegacyAppointments = 'appointments';
  static const _kLastBriefing = 'lastBriefing';
  static const _kDragTipSeen = 'dragTipSeen';

  final SharedPreferences _prefs;

  UserProfile? profile;
  final List<Task> _tasks = [];
  int _idCounter = 0;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppState._(prefs);
    state._read();
    await state._migrateLegacyAppointments();
    return state;
  }

  void _read() {
    try {
      final p = _prefs.getString(_kProfile);
      if (p != null) profile = UserProfile.fromJson(jsonDecode(p) as Map<String, dynamic>);
    } catch (_) {
      profile = null;
    }
    try {
      final t = _prefs.getString(_kTasks);
      if (t != null) {
        _tasks.addAll((jsonDecode(t) as List).map((e) => Task.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      _tasks.clear();
    }
  }

  /// Na v1 os compromissos eram guardados separados das tarefas.
  /// Agora viram itens com dia marcado; os que ainda não passaram também
  /// aparecem na lista de tarefas.
  Future<void> _migrateLegacyAppointments() async {
    final raw = _prefs.getString(_kLegacyAppointments);
    if (raw == null) return;
    try {
      final today = _today();
      for (final e in jsonDecode(raw) as List) {
        final j = e as Map<String, dynamic>;
        final dt = DateTime.parse(j['dateTime'] as String);
        final day = DateTime(dt.year, dt.month, dt.day);
        _tasks.add(
          Task(
            id: j['id'] as String,
            title: j['title'] as String,
            period: PeriodType.daily,
            periodStart: day,
            date: day,
            timeMinutes: dt.hour * 60 + dt.minute,
            note: (j['note'] as String?) ?? '',
            isTask: !day.isBefore(today),
            createdAt: DateTime.now(),
          ),
        );
      }
      await _saveTasks();
    } catch (_) {
      // Dados antigos ilegíveis: ignorados.
    }
    await _prefs.remove(_kLegacyAppointments);
  }

  Future<void> _saveTasks() =>
      _prefs.setString(_kTasks, jsonEncode(_tasks.map((t) => t.toJson()).toList()));

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  static DateTime _today() => PeriodType.daily.startOf(DateTime.now());

  /// Força a reconstrução da interface (ex.: ao voltar para o app depois da meia-noite).
  void refresh() => notifyListeners();

  // ---------------------------------------------------------------- Perfil

  Future<void> saveProfile(String name, int age) async {
    final firstAccess = profile == null;
    profile = UserProfile(name: name.trim(), age: age);
    await _prefs.setString(_kProfile, jsonEncode(profile!.toJson()));
    // No primeiro acesso não há nada para resumir hoje.
    if (firstAccess) await markBriefingSeen();
    notifyListeners();
  }

  // ---------------------------------------------------------------- Resumo diário

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// True na primeira vez que o app é aberto em cada dia.
  bool get needsDailyBriefing =>
      profile != null && _prefs.getString(_kLastBriefing) != _dayKey(DateTime.now());

  Future<void> markBriefingSeen() => _prefs.setString(_kLastBriefing, _dayKey(DateTime.now()));

  // ---------------------------------------------------------------- Dica de arrastar

  bool get dragTipSeen => _prefs.getBool(_kDragTipSeen) ?? false;

  Future<void> markDragTipSeen() async {
    if (dragTipSeen) return;
    await _prefs.setBool(_kDragTipSeen, true);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Estatísticas

  /// Quantidade de tarefas concluídas no período atual de [period]
  /// (ex.: nesta semana). Com [period] nulo, conta todas desde sempre.
  int completedCount(PeriodType? period) {
    if (period == null) return _tasks.where((t) => t.isDone).length;
    final start = period.startOf(DateTime.now());
    final end = period.endOf(start);
    return _tasks.where((t) {
      final c = t.completedAt;
      return c != null && !c.isBefore(start) && c.isBefore(end);
    }).length;
  }

  // ---------------------------------------------------------------- Lista de tarefas

  static int _compareTasks(Task a, Task b) {
    // Pendentes primeiro; depois os de dia marcado em ordem de data/hora.
    if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
    if (a.hasDate != b.hasDate) return a.hasDate ? -1 : 1;
    final da = a.dateTime, db = b.dateTime;
    if (da != null && db != null && da != db) return da.compareTo(db);
    return a.createdAt.compareTo(b.createdAt);
  }

  /// Itens da fileira [period] (ex.: "Esta semana") neste momento.
  List<Task> currentTasks(PeriodType period) {
    final now = DateTime.now();
    return _tasks.where((t) => t.bucket(now) == period).toList()..sort(_compareTasks);
  }

  List<Task> get overdueTasks {
    final now = DateTime.now();
    return _tasks.where((t) => t.isOverdue(now)).toList()
      ..sort((a, b) => a.periodEnd.compareTo(b.periodEnd));
  }

  /// Tarefas marcadas para depois do ano atual.
  List<Task> get upcomingTasks {
    final now = DateTime.now();
    return _tasks.where((t) => t.isUpcoming(now)).toList()..sort(_compareTasks);
  }

  List<Task> get pausedTasks =>
      _tasks.where((t) => t.isPaused).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // ---------------------------------------------------------------- Agenda

  /// O calendário entrega dias em UTC; as comparações são feitas no dia local.
  static DateTime _localDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Itens marcados no dia [day] (sem horário primeiro, depois por horário).
  List<Task> itemsOn(DateTime day) =>
      _tasks.where((t) => t.isOnDay(_localDay(day))).toList()..sort((a, b) {
        final ta = a.timeMinutes ?? -1, tb = b.timeMinutes ?? -1;
        if (ta != tb) return ta.compareTo(tb);
        return a.createdAt.compareTo(b.createdAt);
      });

  /// Tarefas sem dia marcado cujo período ocupa o dia [day].
  List<Task> spanningOn(DateTime day) =>
      _tasks.where((t) => t.coversDay(_localDay(day))).toList()..sort((a, b) {
        if (a.period != b.period) return a.period.index.compareTo(b.period.index);
        return a.createdAt.compareTo(b.createdAt);
      });

  bool hasSpanOn(DateTime day) {
    final d = _localDay(day);
    return _tasks.any((t) => t.coversDay(d));
  }

  // ---------------------------------------------------------------- Criar / editar

  /// Cria ([task] nulo) ou atualiza um item.
  /// Com [date], o item é de um dia específico; sem [date], ocupa o período
  /// atual de [period] inteiro. Itens sem dia marcado são sempre tarefas.
  Future<Task> saveTask({
    Task? task,
    required String title,
    PeriodType period = PeriodType.daily,
    DateTime? date,
    int? timeMinutes,
    String note = '',
    bool isTask = true,
  }) async {
    final now = DateTime.now();
    final day = date == null ? null : DateTime(date.year, date.month, date.day);
    final time = day == null ? null : timeMinutes;

    final target =
        task ??
        Task(
          id: _newId(),
          title: '',
          period: period,
          periodStart: period.startOf(now),
          createdAt: now,
        );

    final scheduleChanged =
        task == null ||
        day != task.date ||
        time != task.timeMinutes ||
        (day == null && period != task.period);

    target
      ..title = title.trim()
      ..note = note.trim()
      ..isTask = day == null ? true : isTask;

    if (scheduleChanged) {
      target
        ..date = day
        ..timeMinutes = time
        ..period = day == null ? period : PeriodType.daily
        ..periodStart = day ?? period.startOf(now)
        ..status = TaskStatus.active;
      if (task != null) target.completedAt = null;
    }

    if (task == null) _tasks.add(target);
    notifyListeners();
    await _saveTasks();
    return target;
  }

  /// Marca/desmarca a tarefa. Retorna o período que acabou de ser
  /// totalmente concluído (para mostrar a tela de parabéns), ou null.
  Future<PeriodType?> toggleDone(Task task) async {
    if (!task.isTask) return null;
    final now = DateTime.now();
    task.completedAt = task.isDone ? null : now;
    PeriodType? celebrate;
    final bucket = task.bucket(now);
    if (task.isDone && bucket != null) {
      final all = currentTasks(bucket);
      if (all.isNotEmpty && all.every((t) => t.isDone)) celebrate = bucket;
    }
    notifyListeners();
    await _saveTasks();
    return celebrate;
  }

  /// Move a tarefa para o período atual de [period], ocupando o período todo
  /// (remove o dia marcado) e retomando se estava pausada.
  Future<void> moveTo(Task task, PeriodType period) async {
    task
      ..period = period
      ..periodStart = period.startOf(DateTime.now())
      ..date = null
      ..timeMinutes = null
      ..isTask = true
      ..status = TaskStatus.active
      ..completedAt = null;
    notifyListeners();
    await _saveTasks();
  }

  Future<void> pause(Task task) async {
    task
      ..status = TaskStatus.paused
      ..completedAt = null;
    notifyListeners();
    await _saveTasks();
  }

  Future<void> deleteTask(Task task) async {
    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();
    await _saveTasks();
  }
}
