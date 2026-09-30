import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Disponibiliza o [AppState] para a árvore de widgets e reconstrói
/// quem depende dele sempre que algo muda.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Acesso sem registrar dependência (para callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
