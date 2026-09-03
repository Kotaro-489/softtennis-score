import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'views/analytics_view.dart';
import 'views/create_match_view.dart';
import 'views/history_view.dart';
import 'views/score_view.dart';

void main() => runApp(const ProviderScope(child: SoftTennisScoreApp()));

class SoftTennisScoreApp extends StatelessWidget {
  const SoftTennisScoreApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SoftTennis Score',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    themeMode: ThemeMode.system,
    home: const AppHome(),
  );
}

class AppHome extends ConsumerStatefulWidget {
  const AppHome({super.key});
  @override
  ConsumerState<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<AppHome> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(matchControllerProvider);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          active.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('記録を保存できませんでした。\n$error', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.read(matchControllerProvider.notifier).load(),
                      child: const Text('再試行'),
                    ),
                  ],
                ),
              ),
            ),
            data: (record) => record == null
                ? const CreateMatchView()
                : ScoreView(record: record),
          ),
          const MatchHistoryView(),
          const AnalyticsView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sports_tennis), label: '試合'),
          NavigationDestination(icon: Icon(Icons.history), label: '履歴'),
          NavigationDestination(icon: Icon(Icons.insights), label: '集計'),
        ],
      ),
    );
  }
}
