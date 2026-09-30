import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme.dart';
import 'agenda_screen.dart';
import 'daily_briefing_screen.dart';
import 'onboarding_screen.dart';
import 'tasks_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _dayTimer;
  DateTime _lastDay = DateUtils.dateOnly(DateTime.now());
  bool _briefingOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Se o dia virar com o app aberto, as fileiras são atualizadas.
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) => _refreshIfNewDay());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowBriefing());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppScope.read(context).refresh();
      _maybeShowBriefing();
    }
  }

  /// Na primeira abertura do dia, mostra o resumo do dia.
  Future<void> _maybeShowBriefing() async {
    if (!mounted || _briefingOpen) return;
    final state = AppScope.read(context);
    if (!state.needsDailyBriefing) return;
    _briefingOpen = true;
    await state.markBriefingSeen();
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const DailyBriefingScreen(),
        ),
      );
    }
    _briefingOpen = false;
  }

  void _refreshIfNewDay() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (today != _lastDay) {
      _lastDay = today;
      if (mounted) AppScope.read(context).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Livoca'),
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Center(child: Text('🐼', style: TextStyle(fontSize: 26))),
        ),
        actions: [
          IconButton(
            tooltip: 'Meu perfil',
            icon: const Icon(Icons.person_rounded),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const OnboardingScreen(editing: true))),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: const [TasksScreen(), AgendaScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded, color: LivocaColors.pink),
            selectedIcon: Icon(Icons.checklist_rounded, color: LivocaColors.pinkDark),
            label: 'Tarefas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, color: LivocaColors.pink),
            selectedIcon: Icon(Icons.calendar_month_rounded, color: LivocaColors.pinkDark),
            label: 'Agenda',
          ),
        ],
      ),
    );
  }
}
