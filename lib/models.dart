import 'package:flutter/material.dart';

/// Períodos de tempo em que uma tarefa pode ser organizada.
enum PeriodType {
  daily,
  weekly,
  monthly,
  quarterly,
  semiannual,
  yearly;

  String get label => switch (this) {
    PeriodType.daily => 'Hoje',
    PeriodType.weekly => 'Esta semana',
    PeriodType.monthly => 'Este mês',
    PeriodType.quarterly => 'Este trimestre',
    PeriodType.semiannual => 'Este semestre',
    PeriodType.yearly => 'Este ano',
  };

  String get shortLabel => switch (this) {
    PeriodType.daily => 'Dia',
    PeriodType.weekly => 'Semana',
    PeriodType.monthly => 'Mês',
    PeriodType.quarterly => 'Trimestre',
    PeriodType.semiannual => 'Semestre',
    PeriodType.yearly => 'Ano',
  };

  /// Texto usado na tela de parabéns: "todas as tarefas ___".
  String get celebrationLabel => switch (this) {
    PeriodType.daily => 'do dia',
    PeriodType.weekly => 'da semana',
    PeriodType.monthly => 'do mês',
    PeriodType.quarterly => 'do trimestre',
    PeriodType.semiannual => 'do semestre',
    PeriodType.yearly => 'do ano',
  };

  IconData get icon => switch (this) {
    PeriodType.daily => Icons.wb_sunny_rounded,
    PeriodType.weekly => Icons.view_week_rounded,
    PeriodType.monthly => Icons.calendar_month_rounded,
    PeriodType.quarterly => Icons.filter_3_rounded,
    PeriodType.semiannual => Icons.filter_6_rounded,
    PeriodType.yearly => Icons.celebration_rounded,
  };

  /// Início do período que contém [date].
  DateTime startOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return switch (this) {
      PeriodType.daily => d,
      // Construtor em vez de subtract() para não sofrer com horário de verão.
      PeriodType.weekly => DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday)),
      PeriodType.monthly => DateTime(d.year, d.month),
      PeriodType.quarterly => DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1),
      PeriodType.semiannual => DateTime(d.year, d.month <= 6 ? 1 : 7),
      PeriodType.yearly => DateTime(d.year),
    };
  }

  /// Início do período seguinte (ou seja, o fim exclusivo do período).
  DateTime endOf(DateTime periodStart) {
    final s = periodStart;
    return switch (this) {
      PeriodType.daily => DateTime(s.year, s.month, s.day + 1),
      PeriodType.weekly => DateTime(s.year, s.month, s.day + 7),
      PeriodType.monthly => DateTime(s.year, s.month + 1),
      PeriodType.quarterly => DateTime(s.year, s.month + 3),
      PeriodType.semiannual => DateTime(s.year, s.month + 6),
      PeriodType.yearly => DateTime(s.year + 1),
    };
  }

  static PeriodType fromName(String name) =>
      PeriodType.values.firstWhere((p) => p.name == name, orElse: () => PeriodType.daily);
}

enum TaskStatus { active, paused }

/// Um item do Livoca. Tarefas e compromissos são a mesma coisa:
/// - sem [date]: tarefa de um período inteiro (ocupa o período todo na agenda);
/// - com [date]: item de um dia específico (opcionalmente com horário). Aparece
///   nesse dia na agenda e, se [isTask], também na lista de tarefas.
///
/// Itens com dia marcado guardam `period = daily` e `periodStart = date`.
class Task {
  Task({
    required this.id,
    required this.title,
    required this.period,
    required this.periodStart,
    this.date,
    this.timeMinutes,
    this.note = '',
    this.isTask = true,
    this.status = TaskStatus.active,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  String title;
  PeriodType period;
  DateTime periodStart;
  DateTime? date;
  int? timeMinutes;
  String note;
  bool isTask;
  TaskStatus status;
  DateTime? completedAt;
  final DateTime createdAt;

  bool get isDone => completedAt != null;
  bool get isPaused => status == TaskStatus.paused;
  bool get hasDate => date != null;
  DateTime get periodEnd => period.endOf(periodStart);

  /// Data e hora completas (meia-noite quando não há horário).
  DateTime? get dateTime {
    final d = date;
    if (d == null) return null;
    final m = timeMinutes ?? 0;
    return DateTime(d.year, d.month, d.day, m ~/ 60, m % 60);
  }

  /// Tarefa ativa, não concluída e cujo prazo já passou.
  bool isOverdue(DateTime now) => isTask && !isPaused && !isDone && !now.isBefore(periodEnd);

  /// Fileira da lista de tarefas em que o item aparece agora, ou null.
  /// Itens com dia marcado vão para o menor período atual que contém o dia
  /// (ex.: sexta desta semana -> "Esta semana"; no próprio dia -> "Hoje").
  PeriodType? bucket(DateTime now) {
    if (!isTask || isPaused || !now.isBefore(periodEnd)) return null;
    final d = date;
    if (d == null) return periodStart == period.startOf(now) ? period : null;
    for (final p in PeriodType.values) {
      if (p.startOf(d) == p.startOf(now)) return p;
    }
    return null;
  }

  /// Tarefa com dia marcado depois do ano atual.
  bool isUpcoming(DateTime now) =>
      isTask && !isPaused && hasDate && now.isBefore(periodEnd) && bucket(now) == null;

  /// Tarefa sem dia marcado cujo período inclui [day].
  bool coversDay(DateTime day) =>
      !hasDate && !isPaused && !day.isBefore(periodStart) && day.isBefore(periodEnd);

  /// Item marcado exatamente em [day].
  bool isOnDay(DateTime day) {
    final d = date;
    return d != null && !isPaused && d.year == day.year && d.month == day.month && d.day == day.day;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'period': period.name,
    'periodStart': periodStart.toIso8601String(),
    'date': date?.toIso8601String(),
    'time': timeMinutes,
    'note': note,
    'isTask': isTask,
    'status': status.name,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    title: j['title'] as String,
    period: PeriodType.fromName(j['period'] as String),
    periodStart: DateTime.parse(j['periodStart'] as String),
    date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
    timeMinutes: (j['time'] as num?)?.toInt(),
    note: (j['note'] as String?) ?? '',
    isTask: (j['isTask'] as bool?) ?? true,
    status: j['status'] == TaskStatus.paused.name ? TaskStatus.paused : TaskStatus.active,
    completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

class UserProfile {
  const UserProfile({required this.name, required this.age});

  final String name;
  final int age;

  Map<String, dynamic> toJson() => {'name': name, 'age': age};

  factory UserProfile.fromJson(Map<String, dynamic> j) =>
      UserProfile(name: j['name'] as String, age: (j['age'] as num).toInt());
}
