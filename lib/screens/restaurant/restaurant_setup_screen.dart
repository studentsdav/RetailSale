import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/restaurant/restaurant_controller.dart';
import '../../core/theme/app_theme.dart';

class RestaurantSetupScreen extends StatefulWidget {
  const RestaurantSetupScreen({super.key});

  @override
  State<RestaurantSetupScreen> createState() => _RestaurantSetupScreenState();
}

class _RestaurantSetupScreenState extends State<RestaurantSetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isSplitRoutingEnabled = true;
  int posCopies = 1;
  int tokenCopies = 2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<RestaurantController>(context, listen: false);
      controller.loadFloors();
      controller.loadDiningAreas();
      controller.loadTableTypes();
      controller.loadTables();
      controller.loadPrinters();
      controller.loadKitchenStations();
      controller.loadEmailConfig();
      controller.loadTemplates();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RestaurantController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Master Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorWeight: 3,
          indicatorColor: colorScheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.table_bar, size: 20), text: 'Tables & Floors'),
            Tab(icon: Icon(Icons.print, size: 20), text: 'Printers & Kitchens'),
            Tab(icon: Icon(Icons.email, size: 20), text: 'SMTP Email Setup'),
            Tab(icon: Icon(Icons.settings, size: 20), text: 'Token & Printing Options'),
            Tab(icon: Icon(Icons.calendar_month, size: 20), text: 'Reservations'),
          ],
        ),
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTablesFloorsTab(context, controller, colorScheme),
                _buildPrintersKitchensTab(context, controller, colorScheme),
                _buildEmailSetupTab(context, controller, colorScheme),
                _buildTokenOptionsTab(context, controller, colorScheme),
                _buildReservationsTab(context, controller, colorScheme),
              ],
            ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? action,
    required ColorScheme scheme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
          ],
        ),
        if (action != null) action,
      ],
    );
  }

  // ==========================================
  // TAB 1: TABLES, FLOORS & AREAS
  // ==========================================
  Widget _buildTablesFloorsTab(BuildContext context, RestaurantController ctrl, ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Floors Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: 'Floors List',
                      subtitle: 'Manage dining floors & layouts',
                      icon: Icons.layers,
                      scheme: scheme,
                      action: IconButton.filledTonal(
                        onPressed: () => _showAddFloorDialog(context, ctrl),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: scheme.outlineVariant, width: 0.8),
                      ),
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: ctrl.floors.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No floors added yet.', style: TextStyle(color: Colors.grey))),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ctrl.floors.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
                              itemBuilder: (context, index) {
                                final floor = ctrl.floors[index];
                                final bool isActive = floor['status'] == 'ACTIVE';
                                return ListTile(
                                  title: Text(floor['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          floor['status'] ?? 'ACTIVE',
                                          style: TextStyle(color: isActive ? Colors.green.shade800 : Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                        onPressed: () => _showAddFloorDialog(context, ctrl, floor: floor),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => ctrl.deleteFloor(floor['id']),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Dining Areas Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: 'Dining Areas',
                      subtitle: 'Seating zones (e.g. AC, Garden)',
                      icon: Icons.storefront,
                      scheme: scheme,
                      action: IconButton.filledTonal(
                        onPressed: () => _showAddDiningAreaDialog(context, ctrl),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: scheme.outlineVariant, width: 0.8),
                      ),
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: ctrl.diningAreas.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No dining areas added yet.', style: TextStyle(color: Colors.grey))),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ctrl.diningAreas.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
                              itemBuilder: (context, index) {
                                final area = ctrl.diningAreas[index];
                                return ListTile(
                                  title: Text(area['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(area['description'] ?? 'No description', style: TextStyle(color: scheme.outline, fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                        onPressed: () => _showAddDiningAreaDialog(context, ctrl, area: area),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => ctrl.deleteDiningArea(area['id']),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(
            title: 'Dining Tables List',
            subtitle: 'Configure physical layout and seat count',
            icon: Icons.table_restaurant,
            scheme: scheme,
            action: ElevatedButton.icon(
              onPressed: () => _showAddTableDialog(context, ctrl),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Table'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant, width: 0.8),
            ),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: ctrl.tables.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No dining tables added yet.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ctrl.tables.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final table = ctrl.tables[index];
                      return ListTile(
                        title: Text(
                          'Table: ${table['table_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text('Seats: ${table['capacity']}'),
                              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text('Floor: ${table['floor']?['name'] ?? 'N/A'}'),
                              labelStyle: const TextStyle(fontSize: 10),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text('Area: ${table['dining_area']?['name'] ?? 'N/A'}'),
                              labelStyle: const TextStyle(fontSize: 10),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showAddTableDialog(context, ctrl, table: table),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => ctrl.deleteTable(table['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PRINTERS & KITCHEN STATIONS
  // ==========================================
  Widget _buildPrintersKitchensTab(BuildContext context, RestaurantController ctrl, ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Outlet Printers',
            subtitle: 'Configure ticket thermal printers',
            icon: Icons.print,
            scheme: scheme,
            action: ElevatedButton.icon(
              onPressed: () => _showAddPrinterDialog(context, ctrl),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Printer'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant, width: 0.8),
            ),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: ctrl.printers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No printers configured.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ctrl.printers.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final printer = ctrl.printers[index];
                      return ListTile(
                        title: Text(printer['printer_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Connection: ${printer['printer_type']} | Path: ${printer['ip_address'] ?? 'Local USB'}:${printer['port'] ?? ''}',
                          style: TextStyle(color: scheme.outline, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showAddPrinterDialog(context, ctrl, printer: printer),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => ctrl.deletePrinter(printer['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(
            title: 'Kitchen & Counter Stations',
            subtitle: 'Map orders to separate prep lines',
            icon: Icons.restaurant,
            scheme: scheme,
            action: ElevatedButton.icon(
              onPressed: () => _showAddStationDialog(context, ctrl),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Station'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant, width: 0.8),
            ),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: ctrl.kitchenStations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No counter stations mapped.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ctrl.kitchenStations.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final station = ctrl.kitchenStations[index];
                      return ListTile(
                        title: Text(station['station_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Mapped Printer: ${station['printer']?['printer_name'] ?? 'None'}', style: TextStyle(color: scheme.outline, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showAddStationDialog(context, ctrl, station: station),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => ctrl.deleteKitchenStation(station['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: EMAIL / SMTP CONFIGURATION
  // ==========================================
  Widget _buildEmailSetupTab(BuildContext context, RestaurantController ctrl, ColorScheme scheme) {
    final hostController = TextEditingController(text: ctrl.emailConfig?['smtp_host'] ?? '');
    final portController = TextEditingController(text: ctrl.emailConfig?['smtp_port']?.toString() ?? '');
    final userController = TextEditingController(text: ctrl.emailConfig?['smtp_user'] ?? '');
    final passController = TextEditingController(text: ctrl.emailConfig?['smtp_pass'] ?? '');
    final nameController = TextEditingController(text: ctrl.emailConfig?['from_name'] ?? '');
    final emailController = TextEditingController(text: ctrl.emailConfig?['from_email'] ?? '');
    final testController = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'SMTP Dispatcher Configuration',
            subtitle: 'Configure automated receipt mailing',
            icon: Icons.mail_outline,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant, width: 0.8),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hostController,
                          decoration: const InputDecoration(
                            labelText: 'SMTP Server Host',
                            hintText: 'smtp.gmail.com',
                            prefixIcon: Icon(Icons.dns_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '587',
                            prefixIcon: Icon(Icons.settings_ethernet),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: userController,
                          decoration: const InputDecoration(
                            labelText: 'SMTP Username',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: passController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'SMTP App Password',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Sender Name',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Sender Email Address',
                            prefixIcon: Icon(Icons.alternate_email),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Parameters'),
                onPressed: () async {
                  final success = await ctrl.saveEmailConfig({
                    'smtp_host': hostController.text,
                    'smtp_port': int.tryParse(portController.text) ?? 587,
                    'smtp_user': userController.text,
                    'smtp_pass': passController.text,
                    'from_name': nameController.text,
                    'from_email': emailController.text,
                    'encryption_type': 'TLS'
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'SMTP parameters saved!' : 'Error saving parameters'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: testController,
                    decoration: const InputDecoration(
                      labelText: 'Test Email Destination Address',
                      hintText: 'john@example.com',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Send Test'),
                onPressed: () async {
                  if (testController.text.isEmpty) return;
                  final success = await ctrl.sendTestEmail(testController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Test message sent successfully!' : 'Delivery failure.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: TOKEN SYSTEM & PRINT COPIES CONFIG
  // ==========================================
  Widget _buildTokenOptionsTab(BuildContext context, RestaurantController ctrl, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Receipt Configurations & Splits',
            subtitle: 'Control tickets printing copy counts',
            icon: Icons.print_disabled_outlined,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant, width: 0.8),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Split Invoice Items by Mapped Station', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Prints separate kitchen tickets automatically for sweets, beverages, bar, and chef counters.'),
                    value: isSplitRoutingEnabled,
                    onChanged: (val) {
                      setState(() {
                        isSplitRoutingEnabled = val;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(val ? 'Multi-counter routing enabled' : 'Counter item split disabled')),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Main Bill Printer Copies'),
                    subtitle: const Text('Default number of copies for customer checkout invoices.'),
                    trailing: DropdownButton<int>(
                      value: posCopies,
                      items: List.generate(5, (i) => i + 1)
                          .map((val) => DropdownMenuItem(value: val, child: Text('$val Cop${val > 1 ? "ies" : "y"}')))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          posCopies = val ?? 1;
                        });
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Kitchen Running Ticket (KOT) Copies'),
                    subtitle: const Text('Default number of copies dispatched to preparation lines.'),
                    trailing: DropdownButton<int>(
                      value: tokenCopies,
                      items: List.generate(5, (i) => i + 1)
                          .map((val) => DropdownMenuItem(value: val, child: Text('$val Cop${val > 1 ? "ies" : "y"}')))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          tokenCopies = val ?? 2;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: RESERVATIONS
  // ==========================================
  Widget _buildReservationsTab(BuildContext context, RestaurantController ctrl, ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Table Bookings',
            subtitle: 'Schedule reservations and guest seating',
            icon: Icons.calendar_month,
            scheme: scheme,
            action: ElevatedButton.icon(
              onPressed: () => _showAddReservationDialog(context, ctrl),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Booking'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant, width: 0.8),
            ),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: ctrl.reservations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No reservations recorded.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ctrl.reservations.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final resv = ctrl.reservations[index];
                      final bool isPending = resv['status'] == 'Pending';
                      final bool isSeated = resv['status'] == 'Seated';
                      return ListTile(
                        title: Text(
                          '${resv['customer_name']} (Guests: ${resv['guest_count']})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Table: ${resv['table']?['table_name'] ?? 'N/A'} | Time: ${resv['reservation_time']}',
                              style: TextStyle(color: scheme.outline, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSeated
                                    ? Colors.green.shade50
                                    : (isPending ? Colors.amber.shade50 : Colors.red.shade50),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                resv['status'] ?? 'Pending',
                                style: TextStyle(
                                  color: isSeated
                                      ? Colors.green.shade800
                                      : (isPending ? Colors.amber.shade800 : Colors.red.shade800),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: isPending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => ctrl.updateReservationStatus(resv['id'], 'Seated'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Seat Guest'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () => ctrl.updateReservationStatus(resv['id'], 'Cancelled'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // POPUP DIALOGS DEFINITIONS WITH PREMIUM UI
  // ==========================================
  void _showAddFloorDialog(BuildContext context, RestaurantController ctrl, {Map<String, dynamic>? floor}) {
    final nameCtrl = TextEditingController(text: floor?['name'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(floor == null ? 'Create Zone Floor' : 'Modify Zone Floor', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Zone Floor Name',
              hintText: 'e.g. Ground Floor, Terrace',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ctrl.saveFloor({
                  if (floor != null) 'id': floor['id'],
                  'name': nameCtrl.text,
                });
                Navigator.pop(context);
              },
              child: const Text('Save Zone'),
            )
          ],
        );
      },
    );
  }

  void _showAddDiningAreaDialog(BuildContext context, RestaurantController ctrl, {Map<String, dynamic>? area}) {
    final nameCtrl = TextEditingController(text: area?['name'] ?? '');
    final descCtrl = TextEditingController(text: area?['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(area == null ? 'Create Dining Area' : 'Modify Dining Area', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Area Name',
                  hintText: 'e.g. AC Lounge, Poolside',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ctrl.saveDiningArea({
                  if (area != null) 'id': area['id'],
                  'name': nameCtrl.text,
                  'description': descCtrl.text,
                });
                Navigator.pop(context);
              },
              child: const Text('Save Area'),
            )
          ],
        );
      },
    );
  }

  void _showAddTableDialog(BuildContext context, RestaurantController ctrl, {Map<String, dynamic>? table}) {
    final nameCtrl = TextEditingController(text: table?['table_name'] ?? '');
    final capacityCtrl = TextEditingController(text: table?['capacity']?.toString() ?? '4');
    int? selectedFloor = table?['floor_id'];
    int? selectedArea = table?['dining_area_id'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(table == null ? 'Create Dining Table' : 'Modify Dining Table', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Table Identifier',
                      hintText: 'e.g. Table 12',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Seating Capacity',
                      hintText: '4',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedFloor,
                    decoration: const InputDecoration(labelText: 'Floor Zone', border: OutlineInputBorder()),
                    items: ctrl.floors.map<DropdownMenuItem<int>>((f) {
                      return DropdownMenuItem<int>(value: f['id'], child: Text(f['name']));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedFloor = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedArea,
                    decoration: const InputDecoration(labelText: 'Dining Area', border: OutlineInputBorder()),
                    items: ctrl.diningAreas.map<DropdownMenuItem<int>>((a) {
                      return DropdownMenuItem<int>(value: a['id'], child: Text(a['name']));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedArea = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    ctrl.saveTable({
                      if (table != null) 'id': table['id'],
                      'table_name': nameCtrl.text,
                      'capacity': int.tryParse(capacityCtrl.text) ?? 4,
                      'floor_id': selectedFloor,
                      'dining_area_id': selectedArea,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save Table'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showAddPrinterDialog(BuildContext context, RestaurantController ctrl, {Map<String, dynamic>? printer}) {
    final nameCtrl = TextEditingController(text: printer?['printer_name'] ?? '');
    final ipCtrl = TextEditingController(text: printer?['ip_address'] ?? '');
    final portCtrl = TextEditingController(text: printer?['port']?.toString() ?? '9100');
    String pType = printer?['printer_type'] ?? 'NETWORK';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(printer == null ? 'Configure Station Printer' : 'Modify Station Printer', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Printer Reference Name',
                      hintText: 'e.g. Sweets Printer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: pType,
                    decoration: const InputDecoration(labelText: 'Connection Mode', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'NETWORK', child: Text('Network (TCP/IP)')),
                      DropdownMenuItem(value: 'USB', child: Text('USB Driver Direct')),
                      DropdownMenuItem(value: 'BLUETOOTH', child: Text('Bluetooth Wireless')),
                    ],
                    onChanged: (val) => setState(() => pType = val!),
                  ),
                  if (pType == 'NETWORK') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: ipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Printer IP address',
                        hintText: '192.168.1.150',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'TCP Connection Port',
                        hintText: '9100',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    ctrl.savePrinter({
                      if (printer != null) 'id': printer['id'],
                      'printer_name': nameCtrl.text,
                      'printer_type': pType,
                      'ip_address': pType == 'NETWORK' ? ipCtrl.text : null,
                      'port': pType == 'NETWORK' ? (int.tryParse(portCtrl.text) ?? 9100) : null,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save Config'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showAddStationDialog(BuildContext context, RestaurantController ctrl, {Map<String, dynamic>? station}) {
    final nameCtrl = TextEditingController(text: station?['station_name'] ?? '');
    int? selectedPrinter = station?['printer_id'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(station == null ? 'Add Counter Station' : 'Edit Counter Station', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Station Name',
                      hintText: 'e.g. Sweets Counter',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedPrinter,
                    decoration: const InputDecoration(labelText: 'Mapped Output Printer', border: OutlineInputBorder()),
                    items: ctrl.printers.map<DropdownMenuItem<int>>((p) {
                      return DropdownMenuItem<int>(value: p['id'], child: Text(p['printer_name']));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedPrinter = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    ctrl.saveKitchenStation({
                      if (station != null) 'id': station['id'],
                      'station_name': nameCtrl.text,
                      'printer_id': selectedPrinter,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save Station'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showAddReservationDialog(BuildContext context, RestaurantController ctrl) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final sizeCtrl = TextEditingController(text: '2');
    int? selectedTable;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Seating Reservation', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Customer Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sizeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Guest Count',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedTable,
                    decoration: const InputDecoration(labelText: 'Choose Dining Table', border: OutlineInputBorder()),
                    items: ctrl.tables.map<DropdownMenuItem<int>>((t) {
                      return DropdownMenuItem<int>(value: t['id'], child: Text('Table: ${t['table_name']}'));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedTable = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedTable == null) return;
                    ctrl.saveReservation({
                      'customer_name': nameCtrl.text,
                      'customer_phone': phoneCtrl.text,
                      'guest_count': int.tryParse(sizeCtrl.text) ?? 2,
                      'table_id': selectedTable,
                      'reservation_time': DateTime.now().add(const Duration(hours: 2)).toIso8601String()
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Book Reservation'),
                )
              ],
            );
          },
        );
      },
    );
  }
}
