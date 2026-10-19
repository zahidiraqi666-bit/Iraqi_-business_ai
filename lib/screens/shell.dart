import 'package:flutter/material.dart';

import '../data/repo.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';

class AppShell extends StatefulWidget {
  final Business business;
  final List<Business> allBusinesses;
  final ValueChanged<String> onSwitch;
  final VoidCallback onChanged;

  const AppShell({
    super.key,
    required this.business,
    required this.allBusinesses,
    required this.onSwitch,
    required this.onChanged,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  // Bumped after any change so the dashboard refreshes when revisited.
  int _version = 0;

  void _bump() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final pages = [
      HomeScreen(
          key: ValueKey('home$_version'),
          business: b,
          onOpenTab: (i) => setState(() => _tab = i)),
      ProductsScreen(business: b, onChanged: _bump),
      OrdersScreen(business: b, onChanged: _bump),
      MoreScreen(
        business: b,
        allBusinesses: widget.allBusinesses,
        onSwitch: widget.onSwitch,
        onChanged: widget.onChanged,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          if (i == 0) _version++;
        }),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'المنتجات'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'الطلبات'),
          NavigationDestination(
              icon: Icon(Icons.more_horiz), label: 'المزيد'),
        ],
      ),
    );
  }
}
