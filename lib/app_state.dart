import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Estado global do app. Tudo é salvo localmente com SharedPreferences.
class AppState extends ChangeNotifier {
  AppState._(this._prefs);

  static const _kProfile = 'profile';
  static const _kTasks = 'tasks';
  static const _kAppointments = 'appointments';
  static const _kLastBriefing = 'lastBriefing';

  final SharedPreferences _prefs;

  UserProfile? profile;
  final List<Task> _tasks = [];
  final List<Appointment> _appointments = [];
  int _idCounter = 0;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppState._(prefs);
    state._read();
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
    try {
      final a = _prefs.getString(_kAppointments);
      if (a != null) {
        _appointments.addAll(
          (jsonDecode(a) as List).map((e) => Appointment.fromJson(e as Map<String, dynamic>)),
        );
      }
    } catch (_) {
      _appointments.clear();
    }
  }

  Future<void> _saveTasks() =>
      _prefs.setString(_kTasks, jsonEncode(_tasks.map((t) => t.toJson()).toList()));

  Future<void> _saveAppointments() =>
      _prefs.setString(_kAppointments, jsonEncode(_appointments.map((a) => a.toJson()).toList()));

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

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

  // ---------------------------------------------------------------- Tarefas

  List<Task> currentTasks(PeriodType period) {
    final now = DateTime.now();
    final list = _tasks.where((t) => t.period == period && t.isCurrent(now)).toList();
    // Pendentes primeiro, depois concluídas.
    list.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  List<Task> get overdueTasks {
    final now = DateTime.now();
    return _tasks.where((t) => t.isOverdue(now)).toList()
      ..sort((a, b) => a.periodEnd.compareTo(b.periodEnd));
  }

  List<Task> get pausedTasks =>
      _tasks.where((t) => t.isPaused).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Tarefas ativas cujo prazo (último dia do período) cai em [day].
  List<Task> tasksDueOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _tasks.where((t) {
      if (t.isPaused) return false;
      final end = t.periodEnd;
      final lastDay = DateTime(end.year, end.month, end.day - 1);
      return lastDay == d;
    }).toList();
  }

  Future<void> addTask(String title, PeriodType period) async {
    final now = DateTime.now();
    _tasks.add(
      Task(
        id: _newId(),
        title: title.trim(),
        period: period,
        periodStart: period.startOf(now),
        createdAt: now,
      ),
    );
    notifyListeners();
    await _saveTasks();
  }

  Future<void> renameTask(Task task, String title) async {
    task.title = title.trim();
    notifyListeners();
    await _saveTasks();
  }

  /// Marca/desmarca a tarefa. Retorna o período que acabou de ser
  /// totalmente concluído (para mostrar a tela de parabéns), ou null.
  Future<PeriodType?> toggleDone(Task task) async {
    final now = DateTime.now();
    task.completedAt = task.isDone ? null : now;
    PeriodType? celebrate;
    if (task.isDone && task.isCurrent(now)) {
      final all = currentTasks(task.period);
      if (all.isNotEmpty && all.every((t) => t.isDone)) celebrate = task.period;
    }
    notifyListeners();
    await _saveTasks();
    return celebrate;
  }

  /// Move a tarefa para o período atual de [period] (e retoma se estava pausada).
  Future<void> moveTo(Task task, PeriodType period) async {
    task
      ..period = period
      ..periodStart = period.startOf(DateTime.now())
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

  // ---------------------------------------------------------------- Agenda

  List<Appointment> appointmentsOn(DateTime day) =>
      _appointments
          .where(
            (a) =>
                a.dateTime.year == day.year &&
                a.dateTime.month == day.month &&
                a.dateTime.day == day.day,
          )
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  Future<void> addAppointment(String title, DateTime dateTime, String note) async {
    _appointments.add(
      Appointment(id: _newId(), title: title.trim(), dateTime: dateTime, note: note.trim()),
    );
    notifyListeners();
    await _saveAppointments();
  }

  Future<void> updateAppointment(
    Appointment a,
    String title,
    DateTime dateTime,
    String note,
  ) async {
    a
      ..title = title.trim()
      ..dateTime = dateTime
      ..note = note.trim();
    notifyListeners();
    await _saveAppointments();
  }

  Future<void> deleteAppointment(Appointment a) async {
    _appointments.removeWhere((x) => x.id == a.id);
    notifyListeners();
    await _saveAppointments();
  }
}
