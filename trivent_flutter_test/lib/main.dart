import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/sales/sales_screen.dart';
import 'screens/purchases/purchases_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/parties/parties_screen.dart';
import 'screens/manufacturing/bom_screen.dart';
import 'screens/manufacturing/manufacture_screen.dart';
import 'screens/reports/reports_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BrickErpApp());
}

class BrickErpApp extends StatelessWidget {
  const BrickErpApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TrivEnt',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: const MainShell(),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final _screens = const [
    DashboardScreen(),
    InventoryScreen(),
    SalesScreen(),
    PurchasesScreen(),
    ExpensesScreen(),
    PartiesScreen(),
    BomScreen(),
    ManufactureScreen(),
    ReportsScreen(),
  ];

  final _navItems = const [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory'),
    _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Sales'),
    _NavItem(Icons.shopping_basket_outlined, Icons.shopping_basket, 'Purchases'),
    _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Expenses'),
    _NavItem(Icons.people_outline, Icons.people, 'Parties'),
    _NavItem(Icons.list_alt_outlined, Icons.list_alt, 'BoM'),
    _NavItem(Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, 'Manufacture'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    if (isWide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                Icon(Icons.factory, color: AppTheme.primary, size: 32),
                SizedBox(height: 4),
                Text('TrivEnt', style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            ),
            destinations: _navItems.map((n) => NavigationRailDestination(
              icon: Icon(n.icon),
              selectedIcon: Icon(n.selectedIcon),
              label: Text(n.label, style: const TextStyle(fontSize: 11)),
            )).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _screens[_selectedIndex]),
        ]),
      );
    }

    // Mobile: bottom nav shows first 5, rest in "More" drawer
    return Scaffold(
      body: _screens[_selectedIndex],
      drawer: _selectedIndex >= 5
          ? null
          : Drawer(
              child: ListView(children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: AppTheme.primary),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.factory, color: Colors.white, size: 40),
                    SizedBox(height: 8),
                    Text('Brick ERP', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                ),
                ..._navItems.asMap().entries.map((e) => ListTile(
                  leading: Icon(e.value.icon, color: _selectedIndex == e.key ? AppTheme.primary : null),
                  title: Text(e.value.label),
                  selected: _selectedIndex == e.key,
                  onTap: () { setState(() => _selectedIndex = e.key); Navigator.pop(context); },
                )),
              ]),
            ),
      appBar: AppBar(
        title: Text(_navItems[_selectedIndex].label),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex < 5 ? _selectedIndex : 0,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: _navItems.take(5).map((n) => NavigationDestination(
          icon: Icon(n.icon),
          selectedIcon: Icon(n.selectedIcon),
          label: n.label,
        )).toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}