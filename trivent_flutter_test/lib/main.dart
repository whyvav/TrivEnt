import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/sales/sales_screen.dart';
import 'screens/sales/payment_in_screen.dart';
import 'screens/purchases/purchases_screen.dart';
import 'screens/purchases/payment_out_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/parties/parties_screen.dart';
import 'screens/manufacturing/bom_screen.dart';
import 'screens/manufacturing/manufacture_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/coming_soon_screen.dart';
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
const int _idxDashboard      = 0;
const int _idxInventory      = 1;
const int _idxSales          = 2;   // Sale Invoices
const int _idxPurchases      = 3;   // Purchase Bills
const int _idxExpenses       = 4;
const int _idxParties        = 5;
const int _idxBom            = 6;
const int _idxManufacture    = 7;
const int _idxReports        = 8;
// Sales sub-screens
const int _idxPaymentIn      = 9;
const int _idxSaleReturn     = 10;
const int _idxEstimate       = 11;
const int _idxSaleOrder      = 12;
const int _idxDeliveryChallan = 13;
// Purchases sub-screens
const int _idxPaymentOut     = 14;
const int _idxPurchaseReturn = 15;
const int _idxPurchaseOrder  = 16;

const _productionIndices = {_idxInventory, _idxBom, _idxManufacture};
const _salesIndices      = {_idxSales, _idxPaymentIn, _idxSaleReturn,
                             _idxEstimate, _idxSaleOrder, _idxDeliveryChallan};
const _purchasesIndices  = {_idxPurchases, _idxPaymentOut,
                             _idxPurchaseReturn, _idxPurchaseOrder};

const _screenLabels = [
  'Dashboard',           // 0
  'Inventory',           // 1
  'Sale Invoices',       // 2
  'Purchase Bills',      // 3
  'Expenses',            // 4
  'Parties',             // 5
  'BoM',                 // 6
  'Manufacture',         // 7
  'Reports',             // 8
  'Payment In',          // 9
  'Sale Return',         // 10
  'Estimate / Quotation',// 11
  'Sale Order',          // 12
  'Delivery Challan',    // 13
  'Payment Out',         // 14
  'Purchase Return',     // 15
  'Purchase Order',      // 16
];

// Bottom-nav index → screen index (Dashboard, Sales, Purchases, Expenses, Parties)
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
  bool _productionExpanded = false;
  bool _salesExpanded      = false;
  bool _purchasesExpanded  = false;

  static const _screens = [
    DashboardScreen(),                                        // 0
    InventoryScreen(),                                        // 1
    SalesScreen(),                                            // 2
    PurchasesScreen(),                                        // 3
    ExpensesScreen(),                                         // 4
    PartiesScreen(),                                          // 5
    BomScreen(),                                              // 6
    ManufactureScreen(),                                      // 7
    ReportsScreen(),                                          // 8
    PaymentInScreen(),                                        // 9
    ComingSoonScreen(title: 'Sale Return'),                   // 10
    ComingSoonScreen(title: 'Estimate / Quotation'),          // 11
    ComingSoonScreen(title: 'Sale Order'),                    // 12
    ComingSoonScreen(title: 'Delivery Challan'),              // 13
    PaymentOutScreen(),                                       // 14
    ComingSoonScreen(title: 'Purchase Return'),               // 15
    ComingSoonScreen(title: 'Purchase Order'),                // 16
  ];

  void _selectScreen(int index) {
    setState(() {
      _selectedIndex = index;
      if (_productionIndices.contains(index)) _productionExpanded = true;
      if (_salesIndices.contains(index))      _salesExpanded = true;
      if (_purchasesIndices.contains(index))  _purchasesExpanded = true;
    });
  }

  int get _bottomNavIndex {
    if (_salesIndices.contains(_selectedIndex)) return 1;
    if (_purchasesIndices.contains(_selectedIndex)) return 2;
    final idx = _bottomNavIndices.indexOf(_selectedIndex);
    return idx < 0 ? 0 : idx;
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
          salesExpanded: _salesExpanded,
          purchasesExpanded: _purchasesExpanded,
          onSelect: _selectScreen,
          onToggleProduction: () =>
              setState(() => _productionExpanded = !_productionExpanded),
          onToggleSales: () =>
              setState(() => _salesExpanded = !_salesExpanded),
          onTogglePurchases: () =>
              setState(() => _purchasesExpanded = !_purchasesExpanded),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: _screens[_selectedIndex]),
      ]),
    );
  }

  // ── Mobile ───────────────────────────────────────────────────────

  Widget _buildNarrow() {
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
        selectedIndex: _bottomNavIndex,
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
  final bool salesExpanded;
  final bool purchasesExpanded;
  final void Function(int) onSelect;
  final VoidCallback onToggleProduction;
  final VoidCallback onToggleSales;
  final VoidCallback onTogglePurchases;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.productionExpanded,
    required this.salesExpanded,
    required this.purchasesExpanded,
    required this.onSelect,
    required this.onToggleProduction,
    required this.onToggleSales,
    required this.onTogglePurchases,
  });

  bool get _prodActive => _productionIndices.contains(selectedIndex);
  bool get _salesActive => _salesIndices.contains(selectedIndex);
  bool get _purchasesActive => _purchasesIndices.contains(selectedIndex);

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
              _groupHeader(
                icon: Icons.build_circle_outlined,
                selectedIcon: Icons.build_circle,
                label: 'Production',
                isActive: _prodActive,
                isExpanded: productionExpanded,
                onTap: onToggleProduction,
              ),
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

              // Sales group
              _groupHeader(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Sales',
                isActive: _salesActive,
                isExpanded: salesExpanded,
                onTap: onToggleSales,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: salesExpanded
                    ? Column(children: [
                        _subItem(Icons.receipt_long_outlined, Icons.receipt_long,
                            'Invoices', _idxSales),
                        _subItem(Icons.move_to_inbox_outlined, Icons.move_to_inbox,
                            'Pay In', _idxPaymentIn),
                        _subItem(Icons.assignment_return_outlined, Icons.assignment_return,
                            'Sale Return', _idxSaleReturn),
                        _subItem(Icons.request_quote_outlined, Icons.request_quote,
                            'Estimate', _idxEstimate),
                        _subItem(Icons.shopping_cart_outlined, Icons.shopping_cart,
                            'Sale Order', _idxSaleOrder),
                        _subItem(Icons.local_shipping_outlined, Icons.local_shipping,
                            'Challan', _idxDeliveryChallan),
                      ])
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 4),

              // Purchases group
              _groupHeader(
                icon: Icons.shopping_basket_outlined,
                selectedIcon: Icons.shopping_basket,
                label: 'Purchases',
                isActive: _purchasesActive,
                isExpanded: purchasesExpanded,
                onTap: onTogglePurchases,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: purchasesExpanded
                    ? Column(children: [
                        _subItem(Icons.shopping_basket_outlined, Icons.shopping_basket,
                            'Bills', _idxPurchases),
                        _subItem(Icons.outbox_outlined, Icons.outbox,
                            'Pay Out', _idxPaymentOut),
                        _subItem(Icons.keyboard_return_outlined, Icons.keyboard_return,
                            'Pur. Return', _idxPurchaseReturn),
                        _subItem(Icons.add_shopping_cart_outlined, Icons.add_shopping_cart,
                            'Pur. Order', _idxPurchaseOrder),
                      ])
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 4),
              _item(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet,
                  'Expenses', _idxExpenses),
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

  Widget _groupHeader({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isActive,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: isActive
              ? BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(children: [
            Icon(
              isActive ? selectedIcon : icon,
              color: isActive ? AppTheme.primary : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? AppTheme.primary : Colors.grey.shade600,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ))),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more,
                      size: 13,
                      color: isActive ? AppTheme.primary : Colors.grey.shade600),
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
  late bool _productionExpanded;
  late bool _salesExpanded;
  late bool _purchasesExpanded;

  @override
  void initState() {
    super.initState();
    _productionExpanded = _productionIndices.contains(widget.selectedIndex);
    _salesExpanded      = _salesIndices.contains(widget.selectedIndex);
    _purchasesExpanded  = _purchasesIndices.contains(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(_AppDrawer old) {
    super.didUpdateWidget(old);
    if (_productionIndices.contains(widget.selectedIndex) && !_productionExpanded) {
      setState(() => _productionExpanded = true);
    }
    if (_salesIndices.contains(widget.selectedIndex) && !_salesExpanded) {
      setState(() => _salesExpanded = true);
    }
    if (_purchasesIndices.contains(widget.selectedIndex) && !_purchasesExpanded) {
      setState(() => _purchasesExpanded = true);
    }
  }

  bool get _prodActive => _productionIndices.contains(widget.selectedIndex);
  bool get _salesActive => _salesIndices.contains(widget.selectedIndex);
  bool get _purchasesActive => _purchasesIndices.contains(widget.selectedIndex);

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

        // ── Production group ──────────────────────────────────
        _drawerGroupHeader(
          icon: _prodActive ? Icons.build_circle : Icons.build_circle_outlined,
          label: 'Production',
          isActive: _prodActive,
          isExpanded: _productionExpanded,
          onTap: () => setState(() => _productionExpanded = !_productionExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _productionExpanded
              ? Column(children: [
                  _drawerSubItem(_idxInventory, Icons.inventory_2_outlined,
                      Icons.inventory_2, 'Inventory'),
                  _drawerSubItem(_idxBom, Icons.list_alt_outlined, Icons.list_alt, 'BoM'),
                  _drawerSubItem(_idxManufacture,
                      Icons.precision_manufacturing_outlined,
                      Icons.precision_manufacturing, 'Manufacture'),
                ])
              : const SizedBox.shrink(),
        ),

        // ── Sales group ───────────────────────────────────────
        _drawerGroupHeader(
          icon: _salesActive ? Icons.receipt_long : Icons.receipt_long_outlined,
          label: 'Sales',
          isActive: _salesActive,
          isExpanded: _salesExpanded,
          onTap: () => setState(() => _salesExpanded = !_salesExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _salesExpanded
              ? Column(children: [
                  _drawerSubItem(_idxSales, Icons.receipt_long_outlined,
                      Icons.receipt_long, 'Sale Invoices'),
                  _drawerSubItem(_idxPaymentIn, Icons.move_to_inbox_outlined,
                      Icons.move_to_inbox, 'Payment In'),
                  _drawerSubItem(_idxSaleReturn, Icons.assignment_return_outlined,
                      Icons.assignment_return, 'Sale Return'),
                  _drawerSubItem(_idxEstimate, Icons.request_quote_outlined,
                      Icons.request_quote, 'Estimate / Quotation'),
                  _drawerSubItem(_idxSaleOrder, Icons.shopping_cart_outlined,
                      Icons.shopping_cart, 'Sale Order'),
                  _drawerSubItem(_idxDeliveryChallan, Icons.local_shipping_outlined,
                      Icons.local_shipping, 'Delivery Challan'),
                ])
              : const SizedBox.shrink(),
        ),

        // ── Purchases group ───────────────────────────────────
        _drawerGroupHeader(
          icon: _purchasesActive ? Icons.shopping_basket : Icons.shopping_basket_outlined,
          label: 'Purchases',
          isActive: _purchasesActive,
          isExpanded: _purchasesExpanded,
          onTap: () => setState(() => _purchasesExpanded = !_purchasesExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _purchasesExpanded
              ? Column(children: [
                  _drawerSubItem(_idxPurchases, Icons.shopping_basket_outlined,
                      Icons.shopping_basket, 'Purchase Bills'),
                  _drawerSubItem(_idxPaymentOut, Icons.outbox_outlined,
                      Icons.outbox, 'Payment Out'),
                  _drawerSubItem(_idxPurchaseReturn, Icons.keyboard_return_outlined,
                      Icons.keyboard_return, 'Purchase Return'),
                  _drawerSubItem(_idxPurchaseOrder, Icons.add_shopping_cart_outlined,
                      Icons.add_shopping_cart, 'Purchase Order'),
                ])
              : const SizedBox.shrink(),
        ),

        _drawerItem(_idxExpenses, Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet, 'Expenses'),
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

  Widget _drawerGroupHeader({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: isActive ? AppTheme.primary : Colors.grey.shade700, size: 22),
      title: Text(label,
          style: TextStyle(
              color: isActive ? AppTheme.primary : null,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
      trailing: AnimatedRotation(
        turns: isExpanded ? 0.5 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(Icons.expand_more,
            size: 20,
            color: isActive ? AppTheme.primary : Colors.grey.shade600),
      ),
      selected: isActive,
      selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
      onTap: onTap,
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
