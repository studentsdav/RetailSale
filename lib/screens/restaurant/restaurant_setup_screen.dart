import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as exc;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../controllers/restaurant/restaurant_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../models/inventory/settings/system_settings_model.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/settings/local_preferences.dart';
import '../../core/printing/device_printer_routing.dart';
import '../../core/utils/country_tax_helper.dart';
import 'table_reservation_screen.dart';
import 'table_qr_designer_screen.dart';

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
  DateTime _resvFilterDate = DateTime.now();
  String _currentMachineId = LocalPreferences.getSystemHardwareId();

  static const Color primaryBlue = Color(0xFF0B5CAD);
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color bgGray = Color(0xFFF4F6FA);
  static const Color cardBg = Colors.white;
  static const Color borderGray = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    LocalPreferences.getMachineId().then((id) {
      if (mounted) setState(() => _currentMachineId = id);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<RestaurantController>(context, listen: false);
      controller.loadFloors();
      controller.loadDiningAreas();
      controller.loadTableTypes();
      controller.loadTables();
      controller.loadPrinters();
      controller.loadKitchenStations();
      controller.loadTemplates();
      controller.loadReservations();
      Provider.of<SystemSettingsController>(context, listen: false).load();
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

    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Restaurant Master Configuration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryDark),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorWeight: 3,
          indicatorColor: primaryBlue,
          labelColor: primaryBlue,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.table_bar, size: 20), text: 'Tables & Floors'),
            Tab(icon: Icon(Icons.print, size: 20), text: 'Printers & Kitchens'),
            Tab(icon: Icon(Icons.calendar_month, size: 20), text: 'Reservations'),
          ],
        ),
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTablesFloorsTab(context, controller),
                _buildPrintersKitchensTab(context, controller),
                _buildReservationsTab(context, controller),
              ],
            ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? action,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: primaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDark),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _cardWrapper({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }

  // ==========================================
  // TAB 1: TABLES, FLOORS & AREAS
  // ==========================================
  Widget _buildTablesFloorsTab(BuildContext context, RestaurantController ctrl) {
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
                      icon: Icons.layers_outlined,
                      action: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showAddFloorDialog(context, ctrl),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Floor'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _cardWrapper(
                      child: ctrl.floors.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No floors added yet.', style: TextStyle(color: Colors.grey))),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ctrl.floors.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: borderGray),
                              itemBuilder: (context, index) {
                                final floor = ctrl.floors[index];
                                final bool isActive = floor['status'] == 'ACTIVE';
                                return ListTile(
                                  title: Text(floor['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
                                  subtitle: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          floor['status'] ?? 'ACTIVE',
                                          style: TextStyle(
                                            color: isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: primaryBlue, size: 18),
                                        onPressed: () => _showAddFloorDialog(context, ctrl, floor: floor),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
                      icon: Icons.storefront_outlined,
                      action: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showAddDiningAreaDialog(context, ctrl),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Area'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _cardWrapper(
                      child: ctrl.diningAreas.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No dining areas added yet.', style: TextStyle(color: Colors.grey))),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ctrl.diningAreas.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: borderGray),
                              itemBuilder: (context, index) {
                                final area = ctrl.diningAreas[index];
                                return ListTile(
                                  title: Text(area['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
                                  subtitle: Text(area['description'] ?? 'No description', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: primaryBlue, size: 18),
                                        onPressed: () => _showAddDiningAreaDialog(context, ctrl, area: area),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'Dining Tables List',
            subtitle: 'Configure physical layout, seat count, and staff assignments',
            icon: Icons.table_restaurant_outlined,
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: const BorderSide(color: primaryBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _exportTablesToExcel(ctrl),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Export Excel'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal.shade800,
                    side: BorderSide(color: Colors.teal.shade600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _downloadSampleTableExcel(),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Sample Template'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showImportTablesDialog(context, ctrl),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Import Excel / CSV'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TableQrDesignerScreen(tables: ctrl.tables),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2, size: 16),
                  label: const Text('Table QR Designer'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAddTableDialog(context, ctrl),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Table'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _cardWrapper(
            child: ctrl.tables.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No dining tables added yet.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ctrl.tables.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: borderGray),
                    itemBuilder: (context, index) {
                      final table = ctrl.tables[index];
                      final waiterName = table['waiter']?['employee_name'] ?? table['waiter_name'];
                      return ListTile(
                        title: Text(
                          'Table: ${table['table_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark),
                        ),
                        subtitle: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Seats: ${table['capacity']}',
                                style: const TextStyle(color: Color(0xFF0369A1), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Floor: ${table['floor']?['name'] ?? 'N/A'}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Area: ${table['dining_area']?['name'] ?? 'N/A'}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                              ),
                            ),
                            if (waiterName != null && waiterName.toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Waiter: $waiterName',
                                  style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_2, color: Color(0xFFD97706), size: 22),
                              tooltip: 'View & Print QR Code',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TableQrDesignerScreen(
                                      tables: ctrl.tables,
                                      initialTableId: table['id']?.toString(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_pin_outlined, color: Colors.teal, size: 20),
                              tooltip: 'Assign Staff / Waiter',
                              onPressed: () => _showAssignTableStaffDialog(context, ctrl, table),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: primaryBlue, size: 18),
                              onPressed: () => _showAddTableDialog(context, ctrl, table: table),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
  Widget _buildPrintersKitchensTab(BuildContext context, RestaurantController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Outlet Printers',
            subtitle: 'Configure ticket thermal printers',
            icon: Icons.print_outlined,
            action: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showAddPrinterDialog(context, ctrl),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Printer'),
            ),
          ),
          const SizedBox(height: 12),
          _cardWrapper(
            child: ctrl.printers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No printers configured.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ctrl.printers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: borderGray),
                    itemBuilder: (context, index) {
                      final printer = ctrl.printers[index];
                      return ListTile(
                        title: Text(printer['printer_name'], style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
                        subtitle: Text(
                          'Connection: ${printer['printer_type']} | Path: ${printer['ip_address'] ?? 'Local USB'}:${printer['port'] ?? ''}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: primaryBlue, size: 18),
                              onPressed: () => _showAddPrinterDialog(context, ctrl, printer: printer),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              onPressed: () => ctrl.deletePrinter(printer['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'KOT Printing & KDS Output Settings',
            subtitle: 'Choose whether to print physical KOT paper slips or use KDS screen only',
            icon: Icons.soup_kitchen_outlined,
          ),
          const SizedBox(height: 12),
          Consumer<SystemSettingsController>(
            builder: (context, sysSettingsCtrl, _) {
              final sysSettings = sysSettingsCtrl.currentSettings;

              return _cardWrapper(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('KOT Print Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                SizedBox(height: 2),
                                Text('Decide action when order is sent to kitchen', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          DropdownButton<String>(
                            value: ['DIRECT', 'DIALOG', 'NONE'].contains(sysSettings.kotPrintMode) ? sysSettings.kotPrintMode : 'DIRECT',
                            items: const [
                              DropdownMenuItem(value: 'DIRECT', child: Text('Direct Print (Automatic)')),
                              DropdownMenuItem(value: 'DIALOG', child: Text('Show Print Dialog')),
                              DropdownMenuItem(value: 'NONE', child: Text('No KOT Print (KDS Only)')),
                            ],
                            onChanged: (val) async {
                              if (val != null) {
                                sysSettings.kotPrintMode = val;
                                sysSettings.enableKotPrint = val != 'NONE';
                                await sysSettingsCtrl.save(sysSettings);
                                if (mounted) setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Physical Paper KOT Print with KDS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: const Text('When disabled, order is sent only to Kitchen Display (KDS) screen without paper print.', style: TextStyle(fontSize: 11.5)),
                        value: sysSettings.enableKotPrint,
                        onChanged: (val) async {
                          sysSettings.enableKotPrint = val;
                          if (!val) sysSettings.kotPrintMode = 'NONE';
                          if (val && sysSettings.kotPrintMode == 'NONE') sysSettings.kotPrintMode = 'DIRECT';
                          await sysSettingsCtrl.save(sysSettings);
                          if (mounted) setState(() {});
                        },
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Restaurant Billing & Settlement Workflow',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: primaryDark),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sysSettings.restaurantSettlementMode == 'DIRECT'
                                      ? '⚡ Direct Settlement (Retail Style): Checkout tenders payment immediately, saves Completed bill, frees table, and prints receipt.'
                                      : '🖨️ Settlement After Bill Print: Prints customer bill first (Running Bill status). Payment is settled later from the Reprint / Modify Sales Bill screen.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            value: sysSettings.restaurantSettlementMode == 'AFTER_BILL_PRINT' ? 'AFTER_BILL_PRINT' : 'DIRECT',
                            items: const [
                              DropdownMenuItem(
                                value: 'DIRECT',
                                child: Text('⚡ Direct Settlement (Retail)', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              DropdownMenuItem(
                                value: 'AFTER_BILL_PRINT',
                                child: Text('🖨️ Settle After Bill Print (Dine-in)', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ],
                            onChanged: (val) async {
                              if (val != null) {
                                sysSettings.restaurantSettlementMode = val;
                                await sysSettingsCtrl.save(sysSettings);
                                if (mounted) setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'Kitchen & Counter Stations',
            subtitle: 'Map order prep lines and printer outputs per terminal machine',
            icon: Icons.restaurant_outlined,
            action: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final sysSettingsCtrl = context.read<SystemSettingsController>();
                DevicePrinterRouting.showRoutingDialog(
                  context: context,
                  settings: sysSettingsCtrl.currentSettings,
                  sectionKey: 'kots',
                  title: 'Kitchen KOT Printer Routing',
                  currentMachineId: _currentMachineId,
                  onSaved: () async {
                    await sysSettingsCtrl.save(sysSettingsCtrl.currentSettings);
                    if (mounted) setState(() {});
                  },
                );
              },
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Map KOT Printers'),
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final sysSettingsCtrl = context.watch<SystemSettingsController>();
              final sysSettings = sysSettingsCtrl.currentSettings;
              final kotMappings = DevicePrinterRouting.getSectionMappings(sysSettings, 'kots');

              return _cardWrapper(
                child: kotMappings.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No KOT kitchen station printers mapped yet. Click "Map KOT Printers" above to add.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: kotMappings.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: borderGray),
                        itemBuilder: (context, index) {
                          final item = kotMappings[index];
                          return ListTile(
                            title: Row(
                              children: [
                                Text(
                                  item.location,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    item.machineId,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryBlue),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Mapped Printer: ${item.printer.isEmpty ? "Default Printer" : item.printer} (${item.copies} Cop${item.copies > 1 ? "ies" : "y"})',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, color: primaryBlue, size: 18),
                              onPressed: () {
                                DevicePrinterRouting.showRoutingDialog(
                                  context: context,
                                  settings: sysSettings,
                                  sectionKey: 'kots',
                                  title: 'Kitchen KOT Printer Routing',
                                  currentMachineId: _currentMachineId,
                                  onSaved: () async {
                                    await sysSettingsCtrl.save(sysSettings);
                                    if (mounted) setState(() {});
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: TOKEN SYSTEM & PRINT COPIES CONFIG
  // ==========================================
  Widget _buildTokenOptionsTab(BuildContext context, RestaurantController ctrl) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Receipt Configurations & Splits',
            subtitle: 'Control tickets printing copy counts',
            icon: Icons.tune_outlined,
          ),
          const SizedBox(height: 16),
          _cardWrapper(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Split Invoice Items by Mapped Station', style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
                    subtitle: const Text('Prints separate kitchen tickets automatically for sweets, beverages, bar, and chef counters.'),
                    value: isSplitRoutingEnabled,
                    activeColor: primaryBlue,
                    onChanged: (val) {
                      setState(() {
                        isSplitRoutingEnabled = val;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(val ? 'Multi-counter routing enabled' : 'Counter item split disabled')),
                      );
                    },
                  ),
                  const Divider(color: borderGray),
                  ListTile(
                    title: const Text('Main Bill Printer Copies', style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
                    subtitle: const Text('Default number of copies for customer checkout invoices.'),
                    trailing: DropdownButton<int>(
                      value: Provider.of<SystemSettingsController>(context).settings?.billCopiesCount ?? 1,
                      items: List.generate(5, (i) => i + 1)
                          .map((val) => DropdownMenuItem(value: val, child: Text('$val Cop${val > 1 ? "ies" : "y"}')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final settingsCtrl = Provider.of<SystemSettingsController>(context, listen: false);
                          final systemSettings = settingsCtrl.settings ?? SystemSettings(
                            autoReorder: true,
                            allowNegativeStock: false,
                            damageApprovalRequired: true,
                            enableAuditLog: true,
                            autoPrintOnSave: false,
                            enableItemImagesInSales: false,
                            printMode: 'PRINT_DIALOG',
                            defaultPrinterName: '',
                            defaultPrinterUrl: '',
                            billingCountry: 'India',
                            billingTaxMode: 'CGST_SGST',
                            billFormat: 'A4',
                            defaultCharges: const [],
                            isCloudEnabled: false,
                            enableAppSubscription: false,
                            enablePaymentGateway: false,
                            paymentGatewayProvider: 'SANDBOX',
                            paymentGatewayApiKey: '',
                            paymentGatewaySecretKey: '',
                            merchantUpiId: '',
                            subDeliveryChargeEnabled: false,
                            subDeliveryChargeName: '',
                            subDeliveryChargeAmount: 0,
                            subDeliveryChargeType: 'FLAT',
                            subDeliveryChargeGstPercent: 0,
                            subDeliveryFreeAbove: 0,
                            enableSalespersonTagging: false,
                            billCopiesCount: 1,
                            showBrandName: true,
                          );
                          systemSettings.billCopiesCount = val;
                          settingsCtrl.save(systemSettings);
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  const Divider(color: borderGray),
                  ListTile(
                    title: const Text('Kitchen Running Ticket (KOT) Copies', style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
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
  // TAB 4: RESERVATION
  // ==========================================
  String _formatReservationLocalTime(dynamic rawTime) {
    if (rawTime == null || rawTime.toString().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(rawTime.toString()).toLocal();
      return DateFormat('hh:mm a, dd-MMM-yyyy').format(dt);
    } catch (_) {
      return rawTime.toString();
    }
  }

  String _formatReservationSlotTime(dynamic rawTime) {
    if (rawTime == null || rawTime.toString().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(rawTime.toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return rawTime.toString();
    }
  }

  // ==========================================
  // TABLE BOOKINGS TAB & ANALYTICS
  // ==========================================
  int _getTodayCount(List<dynamic> list) {
    final now = DateTime.now();
    return list.where((resv) {
      if (resv['reservation_time'] == null) return false;
      try {
        final dt = DateTime.parse(resv['reservation_time'].toString()).toLocal();
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  int _getWeekCount(List<dynamic> list) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
    final end = start.add(const Duration(days: 7));
    return list.where((resv) {
      if (resv['reservation_time'] == null) return false;
      try {
        final dt = DateTime.parse(resv['reservation_time'].toString()).toLocal();
        return dt.isAfter(start) && dt.isBefore(end);
      } catch (_) {
        return false;
      }
    }).length;
  }

  int _getMonthCount(List<dynamic> list) {
    final now = DateTime.now();
    return list.where((resv) {
      if (resv['reservation_time'] == null) return false;
      try {
        final dt = DateTime.parse(resv['reservation_time'].toString()).toLocal();
        return dt.year == now.year && dt.month == now.month;
      } catch (_) {
        return false;
      }
    }).length;
  }

  Widget _buildDashboardCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsTab(BuildContext context, RestaurantController ctrl) {
    // 1. Dashboard calculations
    final todayBookings = _getTodayCount(ctrl.reservations);
    final weekBookings = _getWeekCount(ctrl.reservations);
    final monthBookings = _getMonthCount(ctrl.reservations);

    // 2. Date Filtering
    final allForDate = ctrl.reservations.where((resv) {
      if (resv['reservation_time'] == null) return false;
      try {
        final dt = DateTime.parse(resv['reservation_time'].toString());
        return dt.year == _resvFilterDate.year &&
            dt.month == _resvFilterDate.month &&
            dt.day == _resvFilterDate.day;
      } catch (_) {
        return false;
      }
    }).toList();

    // 3. Separate into sections
    final arrivalsList = allForDate.where((resv) {
      final status = (resv['status'] ?? 'Pending').toString();
      return status != 'Seated' && status != 'Cancelled';
    }).toList();

    final seatedOrCancelledList = allForDate.where((resv) {
      final status = (resv['status'] ?? 'Pending').toString();
      return status == 'Seated' || status == 'Cancelled';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Table Bookings',
            subtitle: 'Schedule reservations and guest seating',
            icon: Icons.calendar_month_outlined,
            action: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TableReservationScreen()),
                ).then((_) => ctrl.loadReservations());
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Booking'),
            ),
          ),
          const SizedBox(height: 16),

          // Analytics dashboard cards row
          Row(
            children: [
              Expanded(
                child: _buildDashboardCard(
                  title: "Today's Bookings",
                  count: todayBookings,
                  color: Colors.blue.shade800,
                  icon: Icons.today,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDashboardCard(
                  title: "This Week",
                  count: weekBookings,
                  color: Colors.green.shade800,
                  icon: Icons.calendar_view_week,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDashboardCard(
                  title: "This Month",
                  count: monthBookings,
                  color: Colors.orange.shade800,
                  icon: Icons.calendar_view_month,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date Navigation Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: primaryBlue),
                onPressed: () {
                  setState(() {
                    _resvFilterDate = _resvFilterDate.subtract(const Duration(days: 1));
                  });
                },
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _resvFilterDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _resvFilterDate = picked;
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, d MMM yyyy').format(_resvFilterDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: primaryBlue),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: primaryBlue),
                onPressed: () {
                  setState(() {
                    _resvFilterDate = _resvFilterDate.add(const Duration(days: 1));
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Section 1: Today's Expected Arrivals
          Text(
            'TODAY\'S ARRIVALS (${arrivalsList.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          _cardWrapper(
            child: arrivalsList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No expected arrivals for this date.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: arrivalsList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: borderGray),
                    itemBuilder: (context, index) {
                      final resv = arrivalsList[index];
                      final bool isPending = resv['status'] == 'Pending';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        title: Text(
                          '${resv['customer_name']} (Guests: ${resv['guest_count']})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Table: ${resv['table']?['table_name'] ?? 'N/A'}  •  Slot Time: ${_formatReservationSlotTime(resv['reservation_time'])}  (${_formatReservationLocalTime(resv['reservation_time'])})',
                              style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            if (resv['customer_phone'] != null && resv['customer_phone'].toString().isNotEmpty)
                              Text('Phone: ${resv['customer_phone']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (resv['address'] != null && resv['address'].toString().isNotEmpty)
                              Text('Address: ${resv['address']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (resv['gstin'] != null && resv['gstin'].toString().isNotEmpty)
                              Text('${CountryTaxHelper.taxIdLabel()}: ${resv['gstin']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                resv['status'] ?? 'Pending',
                                style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => ctrl.updateReservationStatus(resv['id'], 'Seated'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF166534),
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
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),

          // Section 2: Seated / Cancelled Bookings
          Text(
            'SEATED / CANCELLED BOOKINGS (${seatedOrCancelledList.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          _cardWrapper(
            child: seatedOrCancelledList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No historical or seated entries for this date.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: seatedOrCancelledList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: borderGray),
                    itemBuilder: (context, index) {
                      final resv = seatedOrCancelledList[index];
                      final bool isSeated = resv['status'] == 'Seated';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        title: Text(
                          '${resv['customer_name']} (Guests: ${resv['guest_count']})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Table: ${resv['table']?['table_name'] ?? 'N/A'}  •  Slot Time: ${_formatReservationSlotTime(resv['reservation_time'])}  (${_formatReservationLocalTime(resv['reservation_time'])})',
                              style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            if (resv['customer_phone'] != null && resv['customer_phone'].toString().isNotEmpty)
                              Text('Phone: ${resv['customer_phone']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (resv['address'] != null && resv['address'].toString().isNotEmpty)
                              Text('Address: ${resv['address']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (resv['gstin'] != null && resv['gstin'].toString().isNotEmpty)
                              Text('${CountryTaxHelper.taxIdLabel()}: ${resv['gstin']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSeated ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                resv['status'] ?? 'Seated',
                                style: TextStyle(
                                  color: isSeated ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
  // POPUP DIALOGS DEFINITIONS WITH RETAILSALE THEME
  // ==========================================
  void _showAddFloorDialog(BuildContext context, RestaurantController ctrl, {Map<String, dynamic>? floor}) {
    final nameCtrl = TextEditingController(text: floor?['name'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(floor == null ? 'Create Zone Floor' : 'Modify Zone Floor', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Zone Floor Name',
              hintText: 'e.g. Ground Floor, Terrace',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(area == null ? 'Create Dining Area' : 'Modify Dining Area', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Area Name',
                  hintText: 'e.g. AC Lounge, Poolside',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(table == null ? 'Create Dining Table' : 'Modify Dining Table', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Table Identifier',
                      hintText: 'e.g. Table 12',
                      filled: true,
                      fillColor: Colors.white,
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
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedFloor,
                    decoration: const InputDecoration(
                      labelText: 'Floor Zone',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: ctrl.floors.map<DropdownMenuItem<int>>((f) {
                      return DropdownMenuItem<int>(value: f['id'], child: Text(f['name']));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedFloor = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedArea,
                    decoration: const InputDecoration(
                      labelText: 'Dining Area',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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

  Future<void> _exportTablesToExcel(RestaurantController ctrl) async {
    try {
      if (ctrl.tables.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No dining tables found to export.')),
        );
        return;
      }

      final excel = exc.Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.rename(defaultSheet, 'Dining Tables');
      }

      final sheet = excel['Dining Tables'];

      sheet.appendRow([
        exc.TextCellValue('Table Name'),
        exc.TextCellValue('Capacity (Seats)'),
        exc.TextCellValue('Floor Name'),
        exc.TextCellValue('Dining Area'),
        exc.TextCellValue('Table Type'),
        exc.TextCellValue('Status'),
        exc.TextCellValue('Assigned Waiter'),
        exc.TextCellValue('Assigned Captain'),
      ]);

      for (final table in ctrl.tables) {
        final tableName = (table['table_name'] ?? '').toString();
        final capacity = (table['capacity'] ?? 4).toString();
        final floorName = (table['floor']?['name'] ?? table['floor_name'] ?? '').toString();
        final areaName = (table['dining_area']?['name'] ?? table['dining_area_name'] ?? '').toString();
        final typeName = (table['table_type']?['name'] ?? table['table_type_name'] ?? '').toString();
        final status = (table['status'] ?? 'Available').toString();
        final waiter = (table['waiter']?['employee_name'] ?? table['waiter_name'] ?? '').toString();
        final captain = (table['captain']?['employee_name'] ?? table['captain_name'] ?? '').toString();

        sheet.appendRow([
          exc.TextCellValue(tableName),
          exc.TextCellValue(capacity),
          exc.TextCellValue(floorName),
          exc.TextCellValue(areaName),
          exc.TextCellValue(typeName),
          exc.TextCellValue(status),
          exc.TextCellValue(waiter),
          exc.TextCellValue(captain),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) return;

      final fileName = 'dining_tables_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: fileName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exported Successfully! File downloaded.')),
          );
        }
        return;
      }

      String? targetPath;
      try {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && Directory('$userProfile\\Downloads').existsSync()) {
          targetPath = '$userProfile\\Downloads\\$fileName';
        } else {
          final dir = await getApplicationDocumentsDirectory();
          targetPath = '${dir.path}\\$fileName';
        }
      } catch (_) {
        final dir = await getApplicationDocumentsDirectory();
        targetPath = '${dir.path}\\$fileName';
      }

      final file = File(targetPath);
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${ctrl.tables.length} tables successfully!\nSaved to: $targetPath'),
            backgroundColor: Colors.green.shade700,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(targetPath!),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadSampleTableExcel() async {
    try {
      final excel = exc.Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.rename(defaultSheet, 'Dining Tables Template');
      }

      final sheet = excel['Dining Tables Template'];

      sheet.appendRow([
        exc.TextCellValue('Table Name'),
        exc.TextCellValue('Capacity (Seats)'),
        exc.TextCellValue('Floor Name'),
        exc.TextCellValue('Dining Area'),
        exc.TextCellValue('Table Type'),
        exc.TextCellValue('Assigned Waiter'),
        exc.TextCellValue('Assigned Captain'),
      ]);

      final sampleRows = [
        ['Table 1', '4', 'Ground Floor', 'AC Section', 'Standard', 'John Doe', ''],
        ['Table 2', '4', 'Ground Floor', 'AC Section', 'Standard', '', ''],
        ['Table 3', '6', 'Ground Floor', 'Family Hall', 'Standard', '', ''],
        ['VIP 1', '8', 'First Floor', 'VIP Lounge', 'VIP Table', '', 'Captain Alex'],
        ['Bar 1', '2', 'Ground Floor', 'Bar Lounge', 'High Chair', '', ''],
      ];

      for (final r in sampleRows) {
        sheet.appendRow(r.map((c) => exc.TextCellValue(c)).toList());
      }

      final bytes = excel.encode();
      if (bytes == null) return;

      final fileName = 'sample_dining_tables_template.xlsx';

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: fileName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sample Template downloaded.')),
          );
        }
        return;
      }

      String? targetPath;
      try {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && Directory('$userProfile\\Downloads').existsSync()) {
          targetPath = '$userProfile\\Downloads\\$fileName';
        } else {
          final dir = await getApplicationDocumentsDirectory();
          targetPath = '${dir.path}\\$fileName';
        }
      } catch (_) {
        final dir = await getApplicationDocumentsDirectory();
        targetPath = '${dir.path}\\$fileName';
      }

      final file = File(targetPath);
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample Template created!\nSaved to: $targetPath'),
            backgroundColor: Colors.teal.shade700,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(targetPath!),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate template: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImportTablesDialog(BuildContext context, RestaurantController ctrl) {
    int activeTab = 0; // 0: File Upload, 1: Text Paste
    String? pickedFileName;
    List<Map<String, dynamic>> parsedFileRows = [];
    final textCtrl = TextEditingController(
      text: 'Table 1, 4, Ground Floor, AC Section, Standard\n'
            'Table 2, 4, Ground Floor, AC Section, Standard\n'
            'Table 3, 6, Ground Floor, Family Hall, Standard\n'
            'VIP 1, 8, First Floor, VIP Lounge, VIP Table\n'
            'Bar 1, 2, Ground Floor, Bar Lounge, High Chair',
    );
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.table_view_rounded, color: primaryBlue),
              const SizedBox(width: 8),
              const Text('Import Dining Tables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _downloadSampleTableExcel(),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Template (.xlsx)', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 580,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: primaryBlue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '• Floors, Dining Areas & Table Types will be auto-created & linked automatically.\n• Duplicate Table Names are safely updated (upserted) without duplicate records.\n• Strict outlet isolation is enforced.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tab switcher
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => activeTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: activeTab == 0 ? primaryBlue : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file, size: 16, color: activeTab == 0 ? primaryBlue : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Upload Excel (.xlsx/.csv)',
                                  style: TextStyle(
                                    fontWeight: activeTab == 0 ? FontWeight.bold : FontWeight.normal,
                                    color: activeTab == 0 ? primaryBlue : Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => activeTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: activeTab == 1 ? primaryBlue : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note, size: 18, color: activeTab == 1 ? primaryBlue : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Paste CSV Text',
                                  style: TextStyle(
                                    fontWeight: activeTab == 1 ? FontWeight.bold : FontWeight.normal,
                                    color: activeTab == 1 ? primaryBlue : Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  if (activeTab == 0) ...[
                    Center(
                      child: InkWell(
                        onTap: isImporting
                            ? null
                            : () async {
                                final result = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['xlsx', 'xls', 'csv'],
                                  withData: true,
                                );

                                if (result == null || result.files.isEmpty) return;
                                final file = result.files.single;
                                final fileName = file.name;
                                final bytes = file.bytes ?? (file.path != null ? File(file.path!).readAsBytesSync() : null);

                                if (bytes == null) {
                                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                    const SnackBar(content: Text('Could not read file bytes'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }

                                final parsed = <Map<String, dynamic>>[];

                                if (fileName.toLowerCase().endsWith('.csv')) {
                                  final content = String.fromCharCodes(bytes);
                                  final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
                                  bool isFirstRow = true;
                                  int nameCol = 0, capCol = 1, floorCol = 2, areaCol = 3, typeCol = 4, waiterCol = -1, captainCol = -1;

                                  for (final line in lines) {
                                    final parts = line.split(',').map((p) => p.trim().replaceAll('"', '')).toList();
                                    if (parts.isEmpty || parts[0].isEmpty) continue;

                                    if (isFirstRow) {
                                      isFirstRow = false;
                                      final lower = parts.map((p) => p.toLowerCase()).toList();
                                      if (lower.any((h) => h.contains('table') || h.contains('capacity') || h.contains('floor') || h.contains('name'))) {
                                        for (int i = 0; i < lower.length; i++) {
                                          if (lower[i].contains('table') || lower[i] == 'name') {
                                            nameCol = i;
                                          } else if (lower[i].contains('cap') || lower[i].contains('seat')) {
                                            capCol = i;
                                          } else if (lower[i].contains('floor')) {
                                            floorCol = i;
                                          } else if (lower[i].contains('area') || lower[i].contains('section')) {
                                            areaCol = i;
                                          } else if (lower[i].contains('type')) {
                                            typeCol = i;
                                          } else if (lower[i].contains('waiter')) {
                                            waiterCol = i;
                                          } else if (lower[i].contains('captain')) {
                                            captainCol = i;
                                          }
                                        }
                                        continue;
                                      }
                                    }

                                    parsed.add({
                                      'table_name': nameCol < parts.length ? parts[nameCol] : parts[0],
                                      'capacity': capCol < parts.length ? int.tryParse(parts[capCol]) ?? 4 : 4,
                                      'floor': floorCol >= 0 && floorCol < parts.length && parts[floorCol].isNotEmpty ? parts[floorCol] : 'Main Floor',
                                      'dining_area': areaCol >= 0 && areaCol < parts.length && parts[areaCol].isNotEmpty ? parts[areaCol] : 'General Dining',
                                      'table_type': typeCol >= 0 && typeCol < parts.length && parts[typeCol].isNotEmpty ? parts[typeCol] : 'Standard',
                                      if (waiterCol >= 0 && waiterCol < parts.length && parts[waiterCol].isNotEmpty) 'waiter': parts[waiterCol],
                                      if (captainCol >= 0 && captainCol < parts.length && parts[captainCol].isNotEmpty) 'captain': parts[captainCol],
                                    });
                                  }
                                } else {
                                  final excelDoc = exc.Excel.decodeBytes(bytes);
                                  for (final tableKey in excelDoc.tables.keys) {
                                    final sheet = excelDoc.tables[tableKey]!;
                                    if (sheet.rows.isEmpty) continue;

                                    int nameCol = 0, capCol = 1, floorCol = 2, areaCol = 3, typeCol = 4, waiterCol = -1, captainCol = -1;
                                    bool hasHeader = false;

                                    final firstRow = sheet.rows.first;
                                    final headerVals = firstRow.map((c) => c?.value?.toString().toLowerCase().trim() ?? '').toList();
                                    if (headerVals.any((h) => h.contains('table') || h.contains('capacity') || h.contains('floor') || h.contains('name'))) {
                                      hasHeader = true;
                                      for (int i = 0; i < headerVals.length; i++) {
                                        final h = headerVals[i];
                                        if (h.contains('table') || h == 'name') {
                                          nameCol = i;
                                        } else if (h.contains('cap') || h.contains('seat')) {
                                          capCol = i;
                                        } else if (h.contains('floor')) {
                                          floorCol = i;
                                        } else if (h.contains('area') || h.contains('section')) {
                                          areaCol = i;
                                        } else if (h.contains('type')) {
                                          typeCol = i;
                                        } else if (h.contains('waiter')) {
                                          waiterCol = i;
                                        } else if (h.contains('captain')) {
                                          captainCol = i;
                                        }
                                      }
                                    }

                                    final startIdx = hasHeader ? 1 : 0;
                                    for (int r = startIdx; r < sheet.rows.length; r++) {
                                      final row = sheet.rows[r];
                                      if (row.isEmpty) continue;

                                      String getVal(int idx) => (idx >= 0 && idx < row.length && row[idx]?.value != null) ? row[idx]!.value.toString().trim() : '';

                                      final tName = getVal(nameCol);
                                      if (tName.isEmpty) continue;

                                      final capStr = getVal(capCol);
                                      final fName = getVal(floorCol);
                                      final aName = getVal(areaCol);
                                      final tType = getVal(typeCol);
                                      final wName = waiterCol >= 0 ? getVal(waiterCol) : '';
                                      final cName = captainCol >= 0 ? getVal(captainCol) : '';

                                      parsed.add({
                                        'table_name': tName,
                                        'capacity': int.tryParse(capStr) ?? 4,
                                        'floor': fName.isNotEmpty ? fName : 'Main Floor',
                                        'dining_area': aName.isNotEmpty ? aName : 'General Dining',
                                        'table_type': tType.isNotEmpty ? tType : 'Standard',
                                        if (wName.isNotEmpty) 'waiter': wName,
                                        if (cName.isNotEmpty) 'captain': cName,
                                      });
                                    }
                                  }
                                }

                                setDlgState(() {
                                  pickedFileName = fileName;
                                  parsedFileRows = parsed;
                                });
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: primaryBlue.withOpacity(0.4), style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.blue.shade50.withOpacity(0.3),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.cloud_upload_outlined, size: 40, color: primaryBlue),
                              const SizedBox(height: 8),
                              Text(
                                pickedFileName ?? 'Click to choose Excel (.xlsx / .xls) or .CSV file',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: pickedFileName != null ? Colors.green.shade800 : primaryBlue,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pickedFileName != null
                                    ? '${parsedFileRows.length} valid dining table rows detected'
                                    : 'Columns: Table Name, Capacity, Floor Name, Dining Area, Table Type, Waiter, Captain',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (parsedFileRows.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Ready to import ${parsedFileRows.length} tables (Sample: ${parsedFileRows.take(3).map((r) => r['table_name']).join(', ')}...)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      'Paste your CSV or comma-separated rows below (one table per line).\nFormat: Table Name, Capacity, Floor, Dining Area, Table Type, Waiter, Captain',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textCtrl,
                      maxLines: 7,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Table 1, 4, Ground Floor, AC Section, Standard',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: isImporting
                  ? null
                  : () async {
                      List<Map<String, dynamic>> toImport = [];

                      if (activeTab == 0) {
                        if (parsedFileRows.isEmpty) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            const SnackBar(content: Text('Please select an Excel or CSV file first!'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        toImport = parsedFileRows;
                      } else {
                        final raw = textCtrl.text.trim();
                        if (raw.isEmpty) return;
                        final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
                        for (final line in lines) {
                          final parts = line.split(',').map((p) => p.trim()).toList();
                          if (parts.isEmpty || parts[0].isEmpty) continue;
                          toImport.add({
                            'table_name': parts[0],
                            'capacity': parts.length > 1 ? int.tryParse(parts[1]) ?? 4 : 4,
                            'floor': parts.length > 2 && parts[2].isNotEmpty ? parts[2] : 'Main Floor',
                            'dining_area': parts.length > 3 && parts[3].isNotEmpty ? parts[3] : 'General Dining',
                            'table_type': parts.length > 4 && parts[4].isNotEmpty ? parts[4] : 'Standard',
                            if (parts.length > 5 && parts[5].isNotEmpty) 'waiter': parts[5],
                            if (parts.length > 6 && parts[6].isNotEmpty) 'captain': parts[6],
                          });
                        }
                      }

                      if (toImport.isEmpty) {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          const SnackBar(content: Text('No table rows found to import.'), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      setDlgState(() => isImporting = true);
                      try {
                        final res = await ApiClient.post('/api/restaurant/tables/import', {'tables': toImport});
                        if (dialogCtx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Imported ${toImport.length} tables successfully!'),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          ctrl.loadFloors();
                          ctrl.loadDiningAreas();
                          ctrl.loadTableTypes();
                          ctrl.loadTables();
                        }
                      } catch (e) {
                        setDlgState(() => isImporting = false);
                        if (dialogCtx.mounted) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              icon: isImporting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.file_download_done, size: 16),
              label: Text(
                activeTab == 0 && parsedFileRows.isNotEmpty
                    ? 'Import ${parsedFileRows.length} Tables'
                    : 'Import All Tables',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignTableStaffDialog(BuildContext context, RestaurantController ctrl, Map<String, dynamic> table) async {
    List<Map<String, dynamic>> employees = [];
    try {
      final res = await ApiClient.get('/api/hrms/employees');
      if (res['success'] == true && res['data'] is List) {
        employees = List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (_) {}

    if (!context.mounted) return;

    int? selectedWaiterId = table['current_waiter_id'] ?? table['waiter_id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Waiter: ${table['table_name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select dedicated staff member or waiter assigned to this dining table:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: selectedWaiterId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assigned Waiter / Staff',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('-- None / Open Table --', style: TextStyle(color: Colors.grey)),
                  ),
                  ...employees.map((emp) {
                    final id = emp['id'] as int?;
                    final name = emp['full_name'] ?? emp['employee_name'] ?? 'Staff #$id';
                    final role = emp['designation']?['title'] ?? 'Staff';
                    return DropdownMenuItem<int?>(
                      value: id,
                      child: Text('$name ($role)', overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (val) => setDlgState(() => selectedWaiterId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await ApiClient.post('/api/restaurant/tables/${table['id']}/assign-user', {
                    'waiter_id': selectedWaiterId,
                  });
                  if (dialogCtx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Table staff assignment updated!'), backgroundColor: Colors.green),
                    );
                    ctrl.loadTables();
                  }
                } catch (e) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(content: Text('Error assigning table: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPrinterDialog(BuildContext context, RestaurantController ctrl, {Map<String, dynamic>? printer}) {
    final nameCtrl = TextEditingController(text: printer?['printer_name'] ?? '');
    final ipCtrl = TextEditingController(text: printer?['ip_address'] ?? '');
    final portCtrl = TextEditingController(text: printer?['port']?.toString() ?? '9100');
    String pType = printer?['printer_type'] ?? 'SYSTEM';
    List<Printer> systemPrinters = [];
    bool loadingSystemPrinters = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (loadingSystemPrinters && systemPrinters.isEmpty) {
              Printing.listPrinters().timeout(const Duration(seconds: 3), onTimeout: () => []).then((list) {
                if (context.mounted) {
                  final Set<String> seen = {};
                  final List<Printer> uniqueList = [];
                  for (final p in list) {
                    final k = p.name.trim();
                    if (k.isNotEmpty && !seen.contains(k)) {
                      seen.add(k);
                      uniqueList.add(p);
                    }
                  }
                  setState(() {
                    systemPrinters = uniqueList;
                    loadingSystemPrinters = false;
                  });
                }
              }).catchError((_) {
                if (context.mounted) {
                  setState(() => loadingSystemPrinters = false);
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(printer == null ? 'Configure Outlet Printer' : 'Modify Outlet Printer', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: pType,
                    decoration: const InputDecoration(
                      labelText: 'Printer Mode',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SYSTEM', child: Text('System Installed Printer (USB/Local/Driver)')),
                      DropdownMenuItem(value: 'NETWORK', child: Text('Direct Network (TCP/IP)')),
                      DropdownMenuItem(value: 'BLUETOOTH', child: Text('Bluetooth Wireless')),
                    ],
                    onChanged: (val) => setState(() => pType = val!),
                  ),
                  const SizedBox(height: 12),
                  if (pType == 'SYSTEM') ...[
                    if (loadingSystemPrinters)
                      const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(color: primaryBlue)))
                    else
                      DropdownButtonFormField<String>(
                        value: systemPrinters.any((p) => p.name == nameCtrl.text) ? nameCtrl.text : null,
                        decoration: const InputDecoration(
                          labelText: 'Select Installed System Printer',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        items: systemPrinters
                            .where((p) => p.name.trim().isNotEmpty)
                            .map((p) {
                          return DropdownMenuItem<String>(
                            value: p.name,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => nameCtrl.text = val);
                        },
                      ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Printer Reference Name',
                      hintText: 'e.g. Kitchen Printer 1',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (pType == 'NETWORK') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: ipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Printer IP address',
                        hintText: '192.168.1.150',
                        filled: true,
                        fillColor: Colors.white,
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
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
    List<String> itemLocations = [];
    bool isFetched = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!isFetched) {
              isFetched = true;
              Future.wait([
                ApiClient.get(ApiEndpoints.stockLocations).catchError((_) => {}),
                ApiClient.get(ApiEndpoints.items).catchError((_) => {}),
              ]).then((results) {
                if (!context.mounted) return;
                final Set<String> locs = <String>{};

                // 1. Stock locations from database master table (stock_locations)
                final stockLocRes = results[0];
                if (stockLocRes != null && stockLocRes['data'] is List) {
                  for (final loc in (stockLocRes['data'] as List)) {
                    final name = (loc['location_name'] ?? loc['name'] ?? loc['location_code'] ?? '').toString().trim();
                    if (name.isNotEmpty) locs.add(name);
                  }
                }

                // 2. Item locations from item master table (item_master)
                final itemsRes = results[1];
                if (itemsRes != null && itemsRes['data'] is List) {
                  for (final it in (itemsRes['data'] as List)) {
                    final l = (it['location'] ?? it['kitchen_location'] ?? '').toString().trim();
                    if (l.isNotEmpty) locs.add(l);
                  }
                }

                if (nameCtrl.text.trim().isNotEmpty) {
                  locs.add(nameCtrl.text.trim());
                }

                setState(() {
                  itemLocations = locs.toList()..sort();
                });
              });
            }

            final String? currentDropdownVal = itemLocations.contains(nameCtrl.text.trim())
                ? nameCtrl.text.trim()
                : (itemLocations.isNotEmpty ? itemLocations.first : null);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(
                station == null ? 'Add Counter Station' : 'Edit Counter Station',
                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: currentDropdownVal,
                    decoration: const InputDecoration(
                      labelText: 'Item Master Unique Location',
                      hintText: 'Select location from database master',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: itemLocations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc,
                        child: Text(loc),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          nameCtrl.text = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Station Location Name',
                      hintText: 'e.g. Bar Counter',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedPrinter,
                    decoration: const InputDecoration(
                      labelText: 'Mapped Output Printer',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    ctrl.saveKitchenStation({
                      if (station != null) 'id': station['id'],
                      'station_name': nameCtrl.text.trim(),
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
}
