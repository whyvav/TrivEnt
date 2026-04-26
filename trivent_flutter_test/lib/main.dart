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
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/login_screen.dart';

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
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasData) return const MainShell();
            return const LoginScreen();
          },
        ),
      );
}

// ── Screen index constants ─────────────────────────────────────────
const int _idxDashboard   = 0;
const int _idxInventory   = 1;
const int _idxSales       = 2;
const int _idxPurchases   = 3;
const int _idxExpenses    = 4;
const int _idxParties     = 5;
const int _idxBom         = 6;
const int _idxManufacture = 7;
const int _idxReports     = 8;

const _productionIndices = {_idxInventory, _idxBom, _idxManufacture};

const _screenLabels = [
  'Dashboard', 'Inventory', 'Sales', 'Purchases', 'Expenses',
  'Parties', 'BoM', 'Manufacture', 'Reports',
];

// Bottom-nav item order for mobile (no Inventory — it lives in Production)
const _bottomNavIndices = [
  _idxDashboard, _idxSales, _idxPurchases, _idxExpenses, _idxParties,
];

// ── Main shell ─────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  // Desktop sidebar: tracks whether Production group is open
  bool _productionExpanded = false;

  static const _screens = [
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

  void _selectScreen(int index) {
    setState(() {
      _selectedIndex = index;
      if (_productionIndices.contains(index)) _productionExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;
    return isWide ? _buildWide() : _buildNarrow();
  }

  // ── Desktop ──────────────────────────────────────────────────────

  Widget _buildWide() {
    return Scaffold(
      body: Row(children: [
        _DesktopSidebar(
          selectedIndex: _selectedIndex,
          productionExpanded: _productionExpanded,
          onSelect: _selectScreen,
          onToggleProduction: () =>
              setState(() => _productionExpanded = !_productionExpanded),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: _screens[_selectedIndex]),
      ]),
    );
  }

  // ── Mobile ───────────────────────────────────────────────────────

  Widget _buildNarrow() {
    final bottomNavIndex = _bottomNavIndices.indexOf(_selectedIndex);

    return Scaffold(
      body: _screens[_selectedIndex],
      appBar: AppBar(
        title: Text(_screenLabels[_selectedIndex]),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      drawer: _AppDrawer(
        selectedIndex: _selectedIndex,
        onSelect: (index) {
          _selectScreen(index);
          Navigator.pop(context);
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomNavIndex < 0 ? 0 : bottomNavIndex,
        onDestinationSelected: (i) => _selectScreen(_bottomNavIndices[i]),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Sales'),
          NavigationDestination(
              icon: Icon(Icons.shopping_basket_outlined),
              selectedIcon: Icon(Icons.shopping_basket),
              label: 'Purchases'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Expenses'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Parties'),
        ],
      ),
    );
  }
}

// ── Desktop sidebar ────────────────────────────────────────────────

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool productionExpanded;
  final void Function(int) onSelect;
  final VoidCallback onToggleProduction;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.productionExpanded,
    required this.onSelect,
    required this.onToggleProduction,
  });

  bool get _prodActive => _productionIndices.contains(selectedIndex);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      color: Theme.of(context).colorScheme.surface,
      child: Column(children: [
        // Branding
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            Icon(Icons.factory, color: AppTheme.primary, size: 32),
            SizedBox(height: 4),
            Text('TrivEnt',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ]),
        ),

        // Nav items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            children: [
              _item(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', _idxDashboard),
              const SizedBox(height: 4),

              // Production group
              _groupHeader(context),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: productionExpanded
                    ? Column(children: [
                        _subItem(Icons.inventory_2_outlined, Icons.inventory_2,
                            'Inventory', _idxInventory),
                        _subItem(Icons.list_alt_outlined, Icons.list_alt,
                            'BoM', _idxBom),
                        _subItem(Icons.precision_manufacturing_outlined,
                            Icons.precision_manufacturing,
                            'Manufacture', _idxManufacture),
                      ])
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 4),
              _item(Icons.receipt_long_outlined, Icons.receipt_long, 'Sales', _idxSales),
              _item(Icons.shopping_basket_outlined, Icons.shopping_basket, 'Purchases', _idxPurchases),
              _item(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Expenses', _idxExpenses),
              _item(Icons.people_outline, Icons.people, 'Parties', _idxParties),
              _item(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports', _idxReports),
            ],
          ),
        ),

        // Logout
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: IconButton(
            icon: Icon(Icons.logout, size: 20, color: Colors.grey.shade500),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ),
      ]),
    );
  }

  Widget _item(IconData icon, IconData selectedIcon, String label, int index) {
    final sel = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => onSelect(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: sel
              ? BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(children: [
            Icon(sel ? selectedIcon : icon,
                color: sel ? AppTheme.primary : Colors.grey.shade600, size: 22),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: sel ? AppTheme.primary : Colors.grey.shade600,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                )),
          ]),
        ),
      ),
    );
  }

  Widget _groupHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onToggleProduction,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: _prodActive
              ? BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(children: [
            Icon(
              _prodActive ? Icons.build_circle : Icons.build_circle_outlined,
              color: _prodActive ? AppTheme.primary : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Production',
                    style: TextStyle(
                      fontSize: 10,
                      color: _prodActive ? AppTheme.primary : Colors.grey.shade600,
                      fontWeight: _prodActive ? FontWeight.w600 : FontWeight.normal,
                    )),
                AnimatedRotation(
                  turns: productionExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more,
                      size: 13,
                      color: _prodActive ? AppTheme.primary : Colors.grey.shade600),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _subItem(IconData icon, IconData selectedIcon, String label, int index) {
    final sel = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 0, top: 1, bottom: 1),
      child: InkWell(
        onTap: () => onSelect(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: sel
              ? BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Column(children: [
            Icon(sel ? selectedIcon : icon,
                color: sel ? AppTheme.primary : Colors.grey.shade500, size: 18),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: sel ? AppTheme.primary : Colors.grey.shade500,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                )),
          ]),
        ),
      ),
    );
  }
}

// ── Mobile drawer ──────────────────────────────────────────────────

class _AppDrawer extends StatefulWidget {
  final int selectedIndex;
  final void Function(int) onSelect;
  const _AppDrawer({required this.selectedIndex, required this.onSelect});
  @override State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = _productionIndices.contains(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(_AppDrawer old) {
    super.didUpdateWidget(old);
    if (_productionIndices.contains(widget.selectedIndex) && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  bool get _prodActive => _productionIndices.contains(widget.selectedIndex);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: AppTheme.primary),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.factory, color: Colors.white, size: 40),
            SizedBox(height: 8),
            Text('TrivEnt',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        _drawerItem(_idxDashboard, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),

        // ── Production group ──────────────────────────────────────
        // Header tile — group icon in leading, chevron on the RIGHT (trailing)
        ListTile(
          leading: Icon(
            _prodActive ? Icons.build_circle : Icons.build_circle_outlined,
            color: _prodActive ? AppTheme.primary : Colors.grey.shade700,
            size: 22,
          ),
          title: Text('Production',
              style: TextStyle(
                  color: _prodActive ? AppTheme.primary : null,
                  fontWeight:
                      _prodActive ? FontWeight.w600 : FontWeight.normal)),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.expand_more,
                size: 20,
                color: _prodActive ? AppTheme.primary : Colors.grey.shade600),
          ),
          selected: _prodActive,
          selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
          onTap: () => setState(() => _expanded = !_expanded),
        ),

        // Sub-items with animated reveal
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _expanded
              ? Column(children: [
                  _drawerSubItem(_idxInventory, Icons.inventory_2_outlined,
                      Icons.inventory_2, 'Inventory'),
                  _drawerSubItem(
                      _idxBom, Icons.list_alt_outlined, Icons.list_alt, 'BoM'),
                  _drawerSubItem(_idxManufacture,
                      Icons.precision_manufacturing_outlined,
                      Icons.precision_manufacturing, 'Manufacture'),
                ])
              : const SizedBox.shrink(),
        ),
        // ─────────────────────────────────────────────────────────

        _drawerItem(_idxSales, Icons.receipt_long_outlined, Icons.receipt_long, 'Sales'),
        _drawerItem(_idxPurchases, Icons.shopping_basket_outlined, Icons.shopping_basket, 'Purchases'),
        _drawerItem(_idxExpenses, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Expenses'),
        _drawerItem(_idxParties, Icons.people_outline, Icons.people, 'Parties'),
        _drawerItem(_idxReports, Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),

        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          onTap: () => FirebaseAuth.instance.signOut(),
        ),
      ]),
    );
  }

  Widget _drawerItem(int index, IconData icon, IconData selectedIcon, String label) {
    final sel = widget.selectedIndex == index;
    return ListTile(
      leading: Icon(sel ? selectedIcon : icon,
          color: sel ? AppTheme.primary : Colors.grey.shade700),
      title: Text(label,
          style: TextStyle(
              color: sel ? AppTheme.primary : null,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      selected: sel,
      selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
      onTap: () => widget.onSelect(index),
    );
  }

  Widget _drawerSubItem(int index, IconData icon, IconData selectedIcon, String label) {
    final sel = widget.selectedIndex == index;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      dense: true,
      leading: Icon(sel ? selectedIcon : icon,
          color: sel ? AppTheme.primary : Colors.grey.shade600, size: 20),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              color: sel ? AppTheme.primary : Colors.grey.shade700,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      selected: sel,
      selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
      onTap: () => widget.onSelect(index),
    );
  }
}
