import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/records_page.dart';
import 'pages/report_page.dart';
import 'pages/settings_page.dart';

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '个人支出管理',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    RecordsPage(),
    ReportPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: '首页'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: '记账'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: '报表'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: '设置'),
        ],
      ),
    );
  }
}
