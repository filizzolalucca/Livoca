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

class Task {
  Task({
    required this.id,
    required this.title,
    required this.period,
    required this.periodStart,
    this.status = TaskStatus.active,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  String title;
  PeriodType period;
  DateTime periodStart;
  TaskStatus status;
  DateTime? completedAt;
  final DateTime createdAt;

  bool get isDone => completedAt != null;
  bool get isPaused => status == TaskStatus.paused;
  DateTime get periodEnd => period.endOf(periodStart);

  /// Ativa, não concluída e cujo período já terminou.
  bool isOverdue(DateTime now) => !isPaused && !isDone && !now.isBefore(periodEnd);

  /// Pertence ao período atual do seu tipo.
  bool isCurrent(DateTime now) => !isPaused && periodStart == period.startOf(now);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'period': period.name,
    'periodStart': periodStart.toIso8601String(),
    'status': status.name,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    title: j['title'] as String,
    period: PeriodType.fromName(j['period'] as String),
    periodStart: DateTime.parse(j['periodStart'] as String),
    status: j['status'] == TaskStatus.paused.name ? TaskStatus.paused : TaskStatus.active,
    completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

/// Compromisso da agenda.
class Appointment {
  Appointment({required this.id, required this.title, required this.dateTime, this.note = ''});

  final String id;
  String title;
  DateTime dateTime;
  String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateTime': dateTime.toIso8601String(),
    'note': note,
  };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
    id: j['id'] as String,
    title: j['title'] as String,
    dateTime: DateTime.parse(j['dateTime'] as String),
    note: (j['note'] as String?) ?? '',
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
