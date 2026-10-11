import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';

class PluginDevStudioScreen extends StatefulWidget {
  const PluginDevStudioScreen({super.key});

  @override
  State<PluginDevStudioScreen> createState() => _PluginDevStudioScreenState();
}

class _PluginDevStudioScreenState extends State<PluginDevStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _idController = TextEditingController(text: 'plg_custom_global_flow');
  final TextEditingController _nameController = TextEditingController(text: 'Custom Order & Webhook Flow');
  final TextEditingController _versionController = TextEditingController(text: '1.0.0');
  final TextEditingController _categoryController = TextEditingController(text: 'Custom Automation');
  final TextEditingController _authorController = TextEditingController(text: 'Outlet Developer');
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _testPayloadController = TextEditingController(
    text: '{\n  "amount": 250,\n  "currency": "USD",\n  "receipt": "INV-10023"\n}',
  );

  String _selectedLanguage = 'typescript'; // 'javascript' or 'typescript'
  bool _isPublicForAllOutlets = true;
  int _activeOutletId = 1;
  String _activeOutletName = 'My Outlet';

  List<Map<String, dynamic>> _existingPlugins = [];
  String? _selectedPluginIdToEdit = 'NEW';
  bool _isPluginLocked = false;
  String _pluginLockReason = '';

  // Test Console state
  String _testTargetPluginId = 'PLG_GLOBAL_GATEWAY';
  final TextEditingController _hookController = TextEditingController(text: 'onPaymentCreate');
  bool _isRunningTest = false;
  bool _isDeploying = false;
  String _consoleOutput = 'Ready. Select a target plugin and hook, then click "Execute Sandbox Hook".';
  String _structuredResultJson = '';
  List<String> _consoleLogs = [];
  int _lastExecutionMs = 0;
  bool? _lastExecutionSuccess;

  static const String defaultTsTemplate = '''// Real-world Global Developer Plugin (TypeScript)
export default {
  // 1. Initialized when plugin is loaded or credentials configured
  async onInit(context: any) {
    context.logger.info("Custom plugin initialized for outlet: " + context.outletId);
    return { ready: true, status: "CONFIGURED" };
  },

  // 2. Triggered when cashier or customer initiates payment / checkout
  async onPaymentCreate(context: any, payload: any) {
    const { amount, currency = 'USD', receipt = 'REC_' + Date.now() } = payload;
    context.logger.info("Payment hook triggered for receipt: " + receipt + " | Amount: " + amount + " " + currency);

    // Call external payment gateway, webhook, or generate dynamic QR code
    return {
      success: true,
      orderId: "ord_global_" + Date.now(),
      amount: Number(amount),
      currency: currency,
      status: "CREATED"
    };
  },

  // 3. Triggered to verify payment webhook or transaction token
  async onPaymentVerify(context: any, payload: any) {
    const { paymentId, gatewayOrderId } = payload;
    context.logger.info("Verifying transaction: " + paymentId);
    return {
      verified: Boolean(paymentId),
      paymentId: paymentId,
      gatewayOrderId: gatewayOrderId,
      status: "PAID"
    };
  },

  // 4. Triggered during external order synchronization (Shopify / ERP / Custom API)
  async onOrderFetch(context: any, payload: any) {
    context.logger.info("Order fetch hook running for outlet: " + context.outletId);
    return {
      success: true,
      ordersCount: 0,
      orders: []
    };
  }
};''';

  static const String defaultJsTemplate = '''// Real-world Global Developer Plugin (JavaScript)
module.exports = {
  // 1. Initialized when plugin is loaded or credentials configured
  async onInit(context) {
    context.logger.info("Custom JS plugin initialized for outlet: " + context.outletId);
    return { ready: true, status: "CONFIGURED" };
  },

  // 2. Triggered when cashier or customer initiates payment / checkout
  async onPaymentCreate(context, payload) {
    const amount = payload.amount || 0;
    const currency = payload.currency || 'USD';
    context.logger.info("Payment hook invoked with amount: " + amount + " " + currency);
    return {
      success: true,
      orderId: "js_ord_" + Date.now(),
      amount: amount,
      currency: currency,
      status: "COMPLETED"
    };
  },

  // 3. Triggered to verify payment webhook or transaction token
  async onPaymentVerify(context, payload) {
    context.logger.info("Verifying payment payload: " + JSON.stringify(payload));
    return {
      verified: true,
      paymentId: payload.paymentId || "pay_mock_123",
      status: "PAID"
    };
  },

  // 4. Triggered during external order synchronization (Shopify / ERP / Custom API)
  async onOrderFetch(context, payload) {
    context.logger.info("Fetching orders from external endpoint...");
    return {
      success: true,
      ordersCount: 0,
      orders: []
    };
  }
};''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _codeController.text = defaultTsTemplate;
    _initOutletAndPlugins();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _versionController.dispose();
    _categoryController.dispose();
    _authorController.dispose();
    _codeController.dispose();
    _testPayloadController.dispose();
    _hookController.dispose();
    super.dispose();
  }

  Future<void> _initOutletAndPlugins() async {
    await _loadActiveOutlet();
    await _loadPlugins();
  }

  Future<void> _loadActiveOutlet() async {
    try {
      final userMap = await TokenStorage.getUser();
      if (userMap != null) {
        _activeOutletId = int.tryParse((userMap['outlet_id'] ?? userMap['outletId'] ?? userMap['property_id'] ?? 1).toString()) ?? 1;
        final name = (userMap['outlet_name'] ?? userMap['outletName'] ?? userMap['outlet_code'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          _activeOutletName = name;
        }
      }

      // Check public property-info to fetch exact business/property name
      final propRes = await ApiClient.get(ApiEndpoints.publicPropertyInfo);
      if (propRes != null && propRes['data'] != null) {
        final p = propRes['data'];
        final pName = (p['property_name'] ?? p['legal_name'] ?? '').toString().trim();
        if (pName.isNotEmpty) {
          _activeOutletName = pName;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _authorController.text = _activeOutletName;
      });
    }
  }

  Future<void> _loadPlugins() async {
    try {
      final plugsRes = await ApiClient.get(ApiEndpoints.pluginsMarketplace);
      if (plugsRes != null && plugsRes['success'] == true && plugsRes['data'] is List) {
        final all = (plugsRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

        // ONLY keep plugins that this outlet personally authored/created!
        // Never show other outlets' plugins or core system plugins in this outlet's developer studio.
        final myPlugins = all.where((p) {
          final int createdBy = int.tryParse(p['createdByOutletId']?.toString() ?? '0') ?? 0;
          final String pId = p['id']?.toString() ?? '';
          final bool isCore = pId == 'PLG_GLOBAL_GATEWAY' || pId == 'PLG_SHOPIFY_PUBLIC_FETCH' || createdBy == 0;
          return !isCore && createdBy == _activeOutletId;
        }).toList();

        setState(() {
          _existingPlugins = myPlugins;
          if (_existingPlugins.isNotEmpty) {
            if (!_existingPlugins.any((p) => p['id'] == _testTargetPluginId)) {
              _testTargetPluginId = _existingPlugins.first['id'];
            }
            final hooks = _extractHooksFromCode(_getCodeForTargetPlugin());
            if (hooks.isNotEmpty && !hooks.contains(_hookController.text.trim())) {
              _selectHookAndSyncPayload(hooks.first);
            }
          }
        });
      }
    } catch (_) {}
  }

  void _createNewPlugin() {
    final nextNumber = _existingPlugins.length + 1;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    setState(() {
      _selectedPluginIdToEdit = 'NEW';
      _isPluginLocked = false;
      _pluginLockReason = '';
      _idController.text = 'plg_custom_$timestamp';
      _nameController.text = 'Custom Plugin $nextNumber';
      _versionController.text = '1.0.0';
      _categoryController.text = 'Custom Automation';
      _authorController.text = _activeOutletName;
      _selectedLanguage = 'typescript';
      _isPublicForAllOutlets = false;
      _codeController.text = defaultTsTemplate;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ Ready to create Plugin #$nextNumber! Customize the name, code, and scope, then click "Deploy Plugin" to save.'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onSelectPluginToEdit(String? pluginId) {
    if (pluginId == 'NEW') {
      _createNewPlugin();
      return;
    }
    setState(() {
      _selectedPluginIdToEdit = pluginId;
      if (pluginId == null || pluginId == 'SAMPLE') {
        _isPluginLocked = false;
        _pluginLockReason = '';
        _idController.text = 'plg_sample_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        _nameController.text = 'Sample Plugin (Starter Scaffold)';
        _versionController.text = '1.0.0';
        _categoryController.text = 'Custom Automation';
        _authorController.text = _activeOutletName;
        _selectedLanguage = 'typescript';
        _isPublicForAllOutlets = false;
        _codeController.text = defaultTsTemplate;
      } else {
        final found = _existingPlugins.firstWhere((p) => p['id'] == pluginId, orElse: () => {});
        if (found.isNotEmpty) {
          final int createdBy = int.tryParse(found['createdByOutletId']?.toString() ?? '0') ?? 0;
          final bool isSystemCore = found['id'] == 'PLG_GLOBAL_GATEWAY' || found['id'] == 'PLG_SHOPIFY_PUBLIC_FETCH' || createdBy == 0;

          if (isSystemCore) {
            _isPluginLocked = true;
            _pluginLockReason = 'System Core Plugin (Read-Only • Cannot be modified or deleted)';
          } else if (createdBy > 0 && createdBy != _activeOutletId) {
            _isPluginLocked = true;
            final cleanAuthor = (found['author'] ?? 'Another Store').toString().replaceAll(RegExp(r'\(Outlet\s*#?\d+\)', caseSensitive: false), '').trim();
            _pluginLockReason = 'Locked: Created by $cleanAuthor. Only the creator can edit or delete this plugin.';
          } else {
            _isPluginLocked = false;
            _pluginLockReason = '';
          }

          _idController.text = found['id'] ?? '';
          _nameController.text = found['name'] ?? '';
          _versionController.text = found['version'] ?? '1.0.0';
          _categoryController.text = found['category'] ?? 'Integration';
          final cleanAuthor = (found['author'] != null && found['author'].toString().isNotEmpty)
              ? found['author'].toString().replaceAll(RegExp(r'\(Outlet\s*#?\d+\)', caseSensitive: false), '').trim()
              : _activeOutletName;
          _authorController.text = cleanAuthor;
          _selectedLanguage = found['language'] ?? 'typescript';
          _isPublicForAllOutlets = found['isPublic'] == true || found['outletId'] == 0 || found['outletId'] == null;
          if (found['codeBundle'] != null && found['codeBundle'].toString().isNotEmpty) {
            _codeController.text = found['codeBundle'].toString();
          } else {
            _codeController.text = _selectedLanguage == 'typescript' ? defaultTsTemplate : defaultJsTemplate;
          }
        }
      }
    });
  }

  void _loadCommunityPlugin(Map<String, dynamic> plugin) {
    final int createdBy = int.tryParse(plugin['createdByOutletId']?.toString() ?? '0') ?? 0;
    final bool isMine = createdBy > 0 && createdBy == _activeOutletId;
    final cleanAuthor = (plugin['author'] ?? 'Community Contributor')
        .toString()
        .replaceAll(RegExp(r'\(Outlet\s*#?\d+\)', caseSensitive: false), '')
        .trim();

    setState(() {
      _selectedPluginIdToEdit = plugin['id'] ?? '';
      _isPluginLocked = !isMine;
      if (!isMine) {
        _pluginLockReason = 'Public Community Plugin by $cleanAuthor (Read-Only). You can inspect the code below or click "Make a Copy (Fork)" to build your own version!';
      } else {
        _pluginLockReason = '';
      }

      _idController.text = plugin['id'] ?? '';
      _nameController.text = plugin['name'] ?? '';
      _versionController.text = plugin['version'] ?? '1.0.0';
      _categoryController.text = plugin['category'] ?? 'Community Script';
      _authorController.text = cleanAuthor;
      _selectedLanguage = plugin['language'] ?? 'typescript';
      _isPublicForAllOutlets = true;
      _codeController.text = plugin['codeBundle']?.toString() ?? '';
    });
  }

  void _forkCurrentPlugin() {
    final originalName = _nameController.text.trim();
    final originalCode = _codeController.text;
    final newId = 'plg_copy_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final newName = originalName.startsWith('Copy of ') ? originalName : 'Copy of $originalName';

    setState(() {
      _selectedPluginIdToEdit = 'SAMPLE';
      _isPluginLocked = false;
      _pluginLockReason = '';
      _idController.text = newId;
      _nameController.text = newName;
      _versionController.text = '1.0.0';
      _categoryController.text = 'Custom Automation';
      _authorController.text = _activeOutletName;
      _isPublicForAllOutlets = false;
      _codeController.text = originalCode;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Script forked into new editable draft "$newName"! You can now customize and deploy.'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showCommunityPluginSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CommunityPluginSearchDialog(
        currentOutletId: _activeOutletId,
        onSelectPlugin: (plugin) {
          _loadCommunityPlugin(plugin);
        },
      ),
    );
  }

  void _onLanguageChanged(String newLang) {
    setState(() {
      _selectedLanguage = newLang;
      if (newLang == 'typescript') {
        _codeController.text = defaultTsTemplate;
      } else {
        _codeController.text = defaultJsTemplate;
      }
    });
  }

  void _prettifyPayloadJson() {
    try {
      final decoded = jsonDecode(_testPayloadController.text.trim());
      const encoder = JsonEncoder.withIndent('  ');
      setState(() {
        _testPayloadController.text = encoder.convert(decoded);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _selectHookAndSyncPayload(String hookName) {
    _hookController.text = hookName;
    final targetPlugin = _existingPlugins.firstWhere(
      (p) => p['id'] == _testTargetPluginId,
      orElse: () => {},
    );
    final config = targetPlugin['config'] is Map ? Map<String, dynamic>.from(targetPlugin['config'] as Map) : <String, dynamic>{};

    if (hookName == 'onOrderFetch') {
      final domain = (config['shopDomain']?.toString().isNotEmpty == true)
          ? config['shopDomain'].toString()
          : 'your-store.myshopify.com';
      final token = (config['accessToken']?.toString().isNotEmpty == true)
          ? config['accessToken'].toString()
          : 'shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxx';

      _testPayloadController.text = '{\n  "shopDomain": "$domain",\n  "accessToken": "$token",\n  "status": "any",\n  "limit": 10\n}';
    } else if (hookName == 'onInit') {
      _testPayloadController.text = '{\n  "testMode": true\n}';
    } else if (hookName == 'onPaymentCreate') {
      final curr = config['currency']?.toString() ?? 'USD';
      _testPayloadController.text = '{\n  "amount": 199.50,\n  "currency": "$curr",\n  "receipt": "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}"\n}';
    } else if (hookName == 'onPaymentVerify') {
      _testPayloadController.text = '{\n  "paymentId": "pay_live_998877",\n  "gatewayOrderId": "ord_global_4433",\n  "amount": 199.50\n}';
    } else {
      _testPayloadController.text = '{\n  "hook": "$hookName",\n  "timestamp": ${DateTime.now().millisecondsSinceEpoch}\n}';
    }
    setState(() {});
  }


  static const Set<String> _reservedKeywords = {
    'if', 'for', 'while', 'switch', 'catch', 'function', 'constructor',
    'return', 'export', 'import', 'default', 'class', 'let', 'const', 'var', 'try', 'finally', 'typeof', 'instanceof'
  };

  String _getCodeForTargetPlugin() {
    if (_testTargetPluginId == _idController.text.trim()) {
      return _codeController.text;
    }
    final found = _existingPlugins.firstWhere(
      (p) => p['id'] == _testTargetPluginId,
      orElse: () => {},
    );
    if (found.isNotEmpty && found['codeBundle'] != null && found['codeBundle'].toString().isNotEmpty) {
      return found['codeBundle'].toString();
    }
    return _codeController.text;
  }

  List<String> _extractHooksFromCode(String code) {
    final Set<String> detected = {};
    if (code.trim().isEmpty) return ['onInit', 'onPaymentCreate', 'onPaymentVerify', 'onOrderFetch'];

    // 1. Find the exported root object block: export default { ... } OR module.exports = { ... }
    String exportBlock = code;
    final exportObjMatch = RegExp(r'(?:export\s+default|module\.exports)\s*=\s*\{([\s\S]*)\}', multiLine: true).firstMatch(code);
    if (exportObjMatch != null && exportObjMatch.group(1) != null) {
      exportBlock = exportObjMatch.group(1)!;
    }

    // 2. Match root-level method declarations inside the exported object:
    // e.g.:
    // async onOrderFetch(context, payload) {
    // onPaymentCreate(context, payload) {
    // onInit(context: any) {
    final rootMethodRegex = RegExp(
      r'^\s*(?:async\s+)?([A-Za-z][A-Za-z0-9_]*)\s*\(\s*(?:context|ctx|[A-Za-z0-9_]+)?(?:\s*:[^,\)]+)?(?:\s*,[^)]*)?\)\s*(?::\s*[^\{]+)?\s*\{',
      multiLine: true,
    );

    for (final m in rootMethodRegex.allMatches(exportBlock)) {
      final name = m.group(1);
      if (name != null && !_reservedKeywords.contains(name)) {
        detected.add(name);
      }
    }

    // 3. Match property arrow / function definitions:
    // e.g. onOrderFetch: async (context) => { or onInit: async function(context) {
    final propFnRegex = RegExp(
      r'^\s*([A-Za-z][A-Za-z0-9_]*)\s*:\s*(?:async\s+)?(?:function|\([^)]*\)\s*=>)',
      multiLine: true,
    );

    for (final m in propFnRegex.allMatches(exportBlock)) {
      final name = m.group(1);
      if (name != null && !_reservedKeywords.contains(name)) {
        detected.add(name);
      }
    }

    // 4. Match top-level named exports: export async function onInit(...)
    final topLevelExportRegex = RegExp(
      r'export\s+(?:async\s+)?function\s+([A-Za-z][A-Za-z0-9_]*)\s*\(',
      multiLine: true,
    );
    for (final m in topLevelExportRegex.allMatches(code)) {
      final name = m.group(1);
      if (name != null && !_reservedKeywords.contains(name)) {
        detected.add(name);
      }
    }

    // 5. Match exports.myHook = ...
    final exportsNamedRegex = RegExp(
      r'exports\.([A-Za-z][A-Za-z0-9_]*)\s*=\s*(?:async\s+)?(?:function|\([^)]*\)\s*=>)',
      multiLine: true,
    );
    for (final m in exportsNamedRegex.allMatches(code)) {
      final name = m.group(1);
      if (name != null && !_reservedKeywords.contains(name)) {
        detected.add(name);
      }
    }

    // Filter out built-in methods and utilities
    const excluded = {
      'trim', 'split', 'replace', 'map', 'filter', 'foreach', 'reduce',
      'find', 'indexof', 'includes', 'push', 'pop', 'shift', 'unshift',
      'tostring', 'valueof', 'stringify', 'parse', 'log', 'info', 'warn', 'error',
      'get', 'post', 'put', 'delete', 'set', 'catch', 'then', 'json'
    };

    final cleanList = detected.where((name) => !excluded.contains(name.toLowerCase())).toList();

    if (cleanList.isEmpty) {
      return ['onInit', 'onPaymentCreate', 'onPaymentVerify', 'onOrderFetch'];
    }

    return cleanList;
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Developer Guide • Enterprise Plugin Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGuideSection(
                    '1. Multi-Tenant Scoping (Public vs Store Isolated)',
                    '• Public (Global Marketplace): Deployed with `is_public = TRUE`. Any cash counter and branch globally can install and use it. Your store name will appear as the author.\n'
                    '• This Outlet Only: Deployed specifically for your logged-in store ($_activeOutletName). It runs only for your store transactions and remains completely hidden from other branches.',
                  ),
                  _buildGuideSection(
                    '2. Safe Injected "context" Sandbox Object',
                    'Every hook receives `context` with:\n'
                    '• context.config: Decrypted API keys & credentials\n'
                    '• context.http: Built-in HTTP client (get, post) for calling external APIs\n'
                    '• context.logger: Output logs shown in the test console\n'
                    '• context.storage: Fast in-memory key-value cache (get, set)\n'
                    '• context.outletId: Current execution store identity',
                  ),
                  _buildGuideSection(
                    '3. Standard Universal Lifecycle Hooks',
                    '• onInit(context): Initial validation and credentials check\n'
                    '• onPaymentCreate(context, payload): Generates checkout URL or dynamic QR\n'
                    '• onPaymentVerify(context, payload): Validates webhook signature or gateway callback\n'
                    '• onOrderFetch(context, payload): Ingests external e-commerce orders (Shopify / Custom)',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got It!'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildGuideSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Future<void> _deployPlugin() async {
    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    final code = _codeController.text;
    final author = _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : _activeOutletName;

    if (_isPluginLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot deploy: $_pluginLockReason'), backgroundColor: Colors.red),
      );
      return;
    }

    if (id.isEmpty || name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plugin ID, Name and Code are required.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isDeploying = true;
    });

    try {
      final res = await ApiClient.post(ApiEndpoints.pluginDeploy, {
        'id': id,
        'name': name,
        'version': _versionController.text.trim(),
        'category': _categoryController.text.trim(),
        'author': author,
        'language': _selectedLanguage,
        'code': code,
        'isPublic': _isPublicForAllOutlets,
        'targetOutletId': _isPublicForAllOutlets ? 0 : _activeOutletId,
      });

      if (mounted) {
        if (res != null && res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🚀 ${res['message'] ?? 'Plugin deployed and active!'}'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          await _loadPlugins();
          if (mounted) {
            _onSelectPluginToEdit(id);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res?['message'] ?? 'Failed to deploy plugin'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeploying = false;
        });
      }
    }
  }

  Future<void> _deleteCurrentPlugin() async {
    final pluginId = _idController.text.trim();
    final pluginName = _nameController.text.trim();

    if (_isPluginLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot delete: $_pluginLockReason'), backgroundColor: Colors.red),
      );
      return;
    }

    if (pluginId.isEmpty || _selectedPluginIdToEdit == 'NEW' || _selectedPluginIdToEdit == 'SAMPLE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the sample template plugin.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Safety confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text('Delete Created Plugin?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "$pluginName" ($pluginId)?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will permanently remove the plugin bundle from the system and marketplace catalog. POS billing and sales data are 100% unaffected.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete Plugin'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await ApiClient.delete('/api/v1/plugins/$pluginId');
      if (mounted) {
        if (res != null && (res['success'] == true || res['deleted'] == true)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ Plugin "$pluginName" permanently deleted.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          await _loadPlugins();
          if (mounted) {
            _createNewPlugin();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res?['message'] ?? 'Failed to delete plugin'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runTestHook() async {
    final hookName = _hookController.text.trim();
    if (hookName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a hook function name.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final targetPlugin = _existingPlugins.firstWhere(
      (p) => p['id'] == _testTargetPluginId,
      orElse: () => <String, dynamic>{},
    );
    final bool isTargetInstalled = targetPlugin['isInstalled'] == true;
    if (!isTargetInstalled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot execute hook: Plugin "$_testTargetPluginId" is NOT installed for $_activeOutletName. Please install it from the Add-on Marketplace first.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isRunningTest = true;
      _consoleOutput = 'Executing $hookName on $_testTargetPluginId in isolated Node.js sandbox...';
      _structuredResultJson = '';
      _consoleLogs = [];
      _lastExecutionSuccess = null;
    });

    Map<String, dynamic> payload = {};
    try {
      final text = _testPayloadController.text.trim();
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON in Request Payload: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isRunningTest = false);
      return;
    }

    try {
      // If the target plugin matches what's currently open in editor, save/deploy before running hook
      if (_testTargetPluginId == _idController.text.trim()) {
        await ApiClient.post(ApiEndpoints.pluginDeploy, {
          'id': _idController.text.trim(),
          'name': _nameController.text.trim(),
          'version': _versionController.text.trim(),
          'category': _categoryController.text.trim(),
          'author': _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : _activeOutletName,
          'language': _selectedLanguage,
          'code': _codeController.text,
          'isPublic': _isPublicForAllOutlets,
          'targetOutletId': _isPublicForAllOutlets ? 0 : _activeOutletId,
        });
      }

      final endpoint = '/api/v1/plugins/$_testTargetPluginId/hook/$hookName?outletId=$_activeOutletId';
      final res = await ApiClient.post(endpoint, payload);

      if (mounted) {
        setState(() {
          if (res != null && res['data'] != null) {
            final data = res['data'];
            final logs = (data['logs'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final result = data['result'];
            final execTime = data['executionTimeMs'] ?? 0;
            final isSuccess = data['success'] == true;

            _lastExecutionMs = execTime;
            _lastExecutionSuccess = isSuccess;
            _consoleLogs = logs;
            if (result != null) {
              const encoder = JsonEncoder.withIndent('  ');
              _structuredResultJson = encoder.convert(result);
            } else {
              _structuredResultJson = 'null';
            }

            _consoleOutput = 'Execution Finished in ${execTime}ms\nStatus: ${isSuccess ? "200 SUCCESS" : "ERROR"}\n\n'
                '--- LOGS ---\n${logs.join('\n')}\n\n'
                '--- RESULT ---\n$_structuredResultJson';
          } else {
            _lastExecutionSuccess = false;
            _consoleOutput = 'Unexpected Response: $res';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastExecutionSuccess = false;
          _consoleOutput = 'Test Run Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningTest = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.extension_rounded, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plugin Developer Studio',
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Enterprise Extensibility Engine • Connected: $_activeOutletName',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: const Text('Developer Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _showGuideDialog,
          ),
          const SizedBox(width: 10),
          if (_isPluginLocked) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.call_split_rounded, size: 16),
              label: const Text('Make a Copy (Fork)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: _forkCurrentPlugin,
            ),
            const SizedBox(width: 8),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPluginLocked ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isDeploying
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_isPluginLocked ? Icons.lock_rounded : Icons.cloud_upload_rounded, size: 16),
              label: Text(_isPluginLocked ? 'Read-Only (Public Plugin)' : 'Deploy Plugin', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: (_isDeploying || _isPluginLocked) ? null : _deployPlugin,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          tabs: const [
            Tab(icon: Icon(Icons.code_rounded, size: 18), text: 'Source Editor & Metadata'),
            Tab(icon: Icon(Icons.play_circle_outline_rounded, size: 18), text: 'Live Sandbox & Test Console'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditorTab(cardBg, borderColor, textColor, isDark),
          _buildConsoleTab(cardBg, borderColor, textColor, isDark),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: SOURCE EDITOR & METADATA
  // -------------------------------------------------------------
  Widget _buildEditorTab(Color cardBg, Color borderColor, Color textColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select Plugin to Edit Dropdown Card
          Card(
            color: cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  const Text('Select Plugin to Edit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_selectedPluginIdToEdit == 'NEW')
                            ? 'NEW'
                            : ((_selectedPluginIdToEdit == null || _selectedPluginIdToEdit == 'SAMPLE')
                                ? 'SAMPLE'
                                : (_existingPlugins.any((p) => p['id'] == _selectedPluginIdToEdit) ? _selectedPluginIdToEdit : 'SAMPLE')),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<String>(
                            value: 'NEW',
                            child: Row(
                              children: [
                                const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '+ Create New Plugin (${_existingPlugins.length + 1})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'SAMPLE',
                            child: Row(
                              children: [
                                Icon(Icons.code_rounded, color: Color(0xFF2563EB), size: 18),
                                SizedBox(width: 8),
                                Text('Sample Plugin (Starter Scaffold)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ],
                            ),
                          ),
                          ..._existingPlugins.map((p) {
                            final pId = p['id'] ?? '';
                            final pName = p['name'] ?? pId;

                            return DropdownMenuItem<String>(
                              value: pId,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.extension_rounded,
                                    size: 16,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text('$pName ($pId)', overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'MINE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: _onSelectPluginToEdit,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('New Plugin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _createNewPlugin,
                  ),
                  if (_selectedPluginIdToEdit != null && _selectedPluginIdToEdit != 'NEW' && _selectedPluginIdToEdit != 'SAMPLE' && !_isPluginLocked) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 16),
                      label: const Text('Delete Plugin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _deleteCurrentPlugin,
                    ),
                  ],
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    icon: const Icon(Icons.explore_rounded, size: 16),
                    label: const Text('Explore Public Plugins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _showCommunityPluginSearchDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Lock / Community Script Banner if plugin is locked
          if (_isPluginLocked) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pluginLockReason,
                      style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.call_split_rounded, size: 16),
                    label: const Text('Make a Copy (Fork)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _forkCurrentPlugin,
                  ),
                ],
              ),
            ),
          ],

          // Metadata & Configuration Card
          Card(
            color: cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Plugin Manifest & Identity',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      // Language segmented control
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          children: [
                            _buildLangTab('typescript', 'TypeScript (.ts)', isDark),
                            _buildLangTab('javascript', 'JavaScript (.js)', isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 1: ID & Name
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: _idController,
                          readOnly: _isPluginLocked || (_selectedPluginIdToEdit != null && _selectedPluginIdToEdit != 'NEW'),
                          decoration: InputDecoration(
                            labelText: 'Plugin ID',
                            hintText: 'e.g. plg_order_dispatcher',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: _nameController,
                          readOnly: _isPluginLocked,
                          decoration: InputDecoration(
                            labelText: 'Display Name',
                            hintText: 'e.g. Enterprise Webhook Dispatcher',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Version, Category, and Author (Defaults to active outlet)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _versionController,
                          readOnly: _isPluginLocked,
                          decoration: InputDecoration(
                            labelText: 'Version',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: _categoryController,
                          readOnly: _isPluginLocked,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: _authorController,
                          readOnly: _isPluginLocked,
                          decoration: InputDecoration(
                            labelText: 'Developer / Publisher',
                            helperText: 'Shows on Marketplace as plugin creator',
                            helperMaxLines: 1,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 3: Deployment Scope (Azure Resource / Google Cloud style selection)
                  const Text('Deployment Scope', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildScopeCard(
                          title: 'Public for All Outlets',
                          subtitle: 'Available globally across all branches on the Lynx Marketplace.',
                          badge: 'Global Public',
                          isSelected: _isPublicForAllOutlets,
                          badgeColor: const Color(0xFF2563EB),
                          onTap: _isPluginLocked ? () {} : () => setState(() => _isPublicForAllOutlets = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildScopeCard(
                          title: 'This Outlet Only ($_activeOutletName)',
                          subtitle: 'Sandboxed strictly to $_activeOutletName. Other branches cannot run it.',
                          badge: 'Store Isolated',
                          isSelected: !_isPublicForAllOutlets,
                          badgeColor: const Color(0xFF8B5CF6),
                          onTap: _isPluginLocked ? () {} : () => setState(() => _isPublicForAllOutlets = false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Code Editor Container (VS Code / Monaco style)
          Card(
            color: cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedLanguage == 'typescript' ? Icons.javascript_rounded : Icons.code_rounded,
                              color: const Color(0xFF38BDF8),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedLanguage == 'typescript' ? 'index.ts' : 'index.js',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Injected: ctx.http, ctx.config, ctx.logger, ctx.storage, ctx.outletId',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy Code', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _codeController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied to clipboard!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      if (!_isPluginLocked)
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Reset Template', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _codeController.text = _selectedLanguage == 'typescript' ? defaultTsTemplate : defaultJsTemplate;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // IDE Editor Frame
                  Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: Color(0xFF38BDF8)),
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A), // Deep Slate IDE background
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155), width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: TextFormField(
                        controller: _codeController,
                        readOnly: _isPluginLocked,
                        maxLines: 26,
                        cursorColor: const Color(0xFF38BDF8),
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF38BDF8),
                          height: 1.45,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: true,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangTab(String langKey, String label, bool isDark) {
    final isSelected = _selectedLanguage == langKey;
    return GestureDetector(
      onTap: () => _onLanguageChanged(langKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? Colors.grey : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildScopeCard({
    required String title,
    required String subtitle,
    required String badge,
    required bool isSelected,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? badgeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? badgeColor : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? badgeColor : null),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3)),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: LIVE SANDBOX & TEST CONSOLE (Google / Azure API Portal)
  // -------------------------------------------------------------
  Widget _buildConsoleTab(Color cardBg, Color borderColor, Color textColor, bool isDark) {
    final targetPlugin = _existingPlugins.firstWhere(
      (p) => p['id'] == _testTargetPluginId,
      orElse: () => <String, dynamic>{},
    );
    final bool isTargetInstalled = targetPlugin['isInstalled'] == true;
    final String targetPluginName = targetPlugin['name'] ?? _testTargetPluginId;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isTargetInstalled) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Notice: "$targetPluginName" is NOT installed for $_activeOutletName. Hooks cannot be executed until this add-on is installed from the Marketplace.',
                      style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Top Control Bar: Target Plugin Selector, Hook, Scope, and Run Button
          Card(
            color: cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 1. Target Plugin to Test
                      const Icon(Icons.extension_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      const Text('Target Plugin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _existingPlugins.any((p) => p['id'] == _testTargetPluginId)
                            ? _testTargetPluginId
                            : (_existingPlugins.isNotEmpty ? _existingPlugins.first['id'] : null),
                        items: _existingPlugins.map((p) {
                          final pId = p['id'] ?? '';
                          final pName = p['name'] ?? pId;
                          return DropdownMenuItem<String>(
                            value: pId,
                            child: Text('$pName ($pId)', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _testTargetPluginId = val;
                              final hooks = _extractHooksFromCode(_getCodeForTargetPlugin());
                              if (hooks.isNotEmpty && !hooks.contains(_hookController.text.trim())) {
                                _hookController.text = hooks.first;
                              }
                            });
                            _selectHookAndSyncPayload(_hookController.text.trim());
                          }
                        },
                      ),
                      const SizedBox(width: 16),

                      // 2. Custom Free-form Hook Input
                      const Text('Hook:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(
                        width: 190,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: _hookController,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF2563EB)),
                            hintText: 'e.g. calculateTax',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // 3. Current Outlet Scope Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Scope: $_activeOutletName',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                      const Spacer(),

                      // 4. Run Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (!isTargetInstalled)
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: _isRunningTest
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(!isTargetInstalled ? Icons.lock_outline_rounded : Icons.play_arrow_rounded, size: 18),
                        label: Text(!isTargetInstalled ? 'Not Installed (Locked)' : 'Execute Sandbox Hook', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: (_isRunningTest || !isTargetInstalled) ? null : _runTestHook,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Auto-Detected Hooks from Plugin Code
                  Builder(
                    builder: (ctx) {
                      final detected = _extractHooksFromCode(_getCodeForTargetPlugin());
                      return Row(
                        children: [
                          const Icon(Icons.code_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          const Text(
                            'Detected in Code:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: detected.map((h) {
                                  final isSelected = _hookController.text.trim() == h;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () => _selectHookAndSyncPayload(h),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF2563EB)
                                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.bolt_rounded,
                                              size: 13,
                                              color: isSelected ? Colors.white : const Color(0xFF2563EB),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$h()',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                color: isSelected ? Colors.white : const Color(0xFF1E40AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2-Column Split Workspace (Request Payload Editor on Left, Live Console Output on Right)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Request JSON Payload
                Expanded(
                  flex: 5,
                  child: Card(
                    color: cardBg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.data_object_rounded, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              const Text('Request Payload (JSON)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const Spacer(),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                                icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                                label: const Text('Prettify', style: TextStyle(fontSize: 11)),
                                onPressed: _prettifyPayloadJson,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Dynamic Payload Template buttons matching only detected functions
                          Builder(
                            builder: (ctx) {
                              final detected = _extractHooksFromCode(_getCodeForTargetPlugin());
                              return Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final h in detected)
                                    _buildPresetChip('⚡ $h() Template', () => _selectHookAndSyncPayload(h)),
                                  _buildPresetChip('🔑 Use Configured Store Data', () {
                                    final targetPlugin = _existingPlugins.firstWhere(
                                      (p) => p['id'] == _testTargetPluginId,
                                      orElse: () => {},
                                    );
                                    final config = targetPlugin['config'] is Map ? Map<String, dynamic>.from(targetPlugin['config'] as Map) : <String, dynamic>{};
                                    if (config.isNotEmpty) {
                                      const encoder = JsonEncoder.withIndent('  ');
                                      final payloadMap = Map<String, dynamic>.from(config);
                                      if (!payloadMap.containsKey('limit')) payloadMap['limit'] = 10;
                                      if (!payloadMap.containsKey('status')) payloadMap['status'] = 'any';
                                      setState(() {
                                        _testPayloadController.text = encoder.convert(payloadMap);
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No configured credentials saved yet for this plugin in Marketplace.')),
                                      );
                                    }
                                  }),
                                  _buildPresetChip('🧹 Empty JSON (Auto-Use Config)', () {
                                    setState(() {
                                      _testPayloadController.text = '{\n\n}';
                                    });
                                  }),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Theme(
                              data: ThemeData.dark(),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: TextFormField(
                                  controller: _testPayloadController,
                                  maxLines: null,
                                  expands: true,
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 13,
                                    color: Color(0xFFA5B4FC), // Soft purple JSON
                                    height: 1.45,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Right Panel: Response Output & Execution Terminal
                Expanded(
                  flex: 6,
                  child: Card(
                    color: cardBg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              const Text('Execution Output & Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const Spacer(),
                              if (_lastExecutionSuccess != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _lastExecutionSuccess == true
                                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                        : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _lastExecutionSuccess == true ? '200 SUCCESS' : 'EXECUTION ERROR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _lastExecutionSuccess == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_lastExecutionMs}ms',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                icon: const Icon(Icons.clear_all_rounded, size: 18),
                                tooltip: 'Clear Output',
                                onPressed: () {
                                  setState(() {
                                    _consoleOutput = 'Console cleared.';
                                    _structuredResultJson = '';
                                    _consoleLogs = [];
                                    _lastExecutionSuccess = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_consoleLogs.isNotEmpty) ...[
                                      const Text('// Stdout Sandbox Logs:', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Consolas', fontSize: 12)),
                                      const SizedBox(height: 4),
                                      ..._consoleLogs.map((log) {
                                        Color logColor = const Color(0xFF38BDF8);
                                        if (log.contains('[ERROR]')) logColor = const Color(0xFFF87171);
                                        if (log.contains('[WARN]')) logColor = const Color(0xFFFBBF24);
                                        return Text(
                                          log,
                                          style: TextStyle(fontFamily: 'Consolas', fontSize: 12.5, color: logColor, height: 1.4),
                                        );
                                      }),
                                      const Divider(color: Color(0xFF334155), height: 20),
                                    ],
                                    if (_structuredResultJson.isNotEmpty) ...[
                                      const Text('// Returned Result Object:', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Consolas', fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _structuredResultJson,
                                        style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, color: Color(0xFF34D399), height: 1.45),
                                      ),
                                    ] else
                                      Text(
                                        _consoleOutput,
                                        style: TextStyle(
                                          fontFamily: 'Consolas',
                                          fontSize: 13,
                                          color: _lastExecutionSuccess == false ? const Color(0xFFF87171) : const Color(0xFF94A3B8),
                                          height: 1.45,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
      labelStyle: const TextStyle(color: Color(0xFF2563EB)),
      side: const BorderSide(color: Color(0xFF2563EB), width: 0.8),
      onPressed: onTap,
    );
  }
}

class _CommunityPluginSearchDialog extends StatefulWidget {
  final int currentOutletId;
  final ValueChanged<Map<String, dynamic>> onSelectPlugin;

  const _CommunityPluginSearchDialog({
    required this.currentOutletId,
    required this.onSelectPlugin,
  });

  @override
  State<_CommunityPluginSearchDialog> createState() => _CommunityPluginSearchDialogState();
}

class _CommunityPluginSearchDialogState extends State<_CommunityPluginSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _plugins = [];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPlugins('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchPlugins(query);
    });
  }

  Future<void> _fetchPlugins(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = '${ApiEndpoints.pluginsCommunitySearch}?q=${Uri.encodeComponent(query.trim())}&limit=20';
      final res = await ApiClient.get(uri);

      if (res != null && res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final List list = data['plugins'] ?? [];
        if (mounted) {
          setState(() {
            _plugins = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _totalCount = (data['total'] as num?)?.toInt() ?? _plugins.length;
            _isLoading = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load community plugins.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.public_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Community Plugin Library',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Public community plugins: inspect source code or make a copy to customize. Max 20 results per search.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search community plugins by name, tag, author, or keyword...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _fetchPlugins('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Result Count & Sandbox Notice
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoading
                        ? 'Searching...'
                        : 'Showing ${_plugins.length} script${_plugins.length == 1 ? '' : 's'}${_totalCount > _plugins.length ? ' of $_totalCount' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'Read-Only Sandbox • Safe to Inspect & Fork',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // List View / States
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Fetching community scripts...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                                const SizedBox(height: 8),
                                Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () => _fetchPlugins(_searchController.text),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _plugins.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.extension_off_rounded, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 10),
                                    const Text('No public community plugins found.', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Publish your script with "Public for All Outlets" enabled to share it with other outlets.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _plugins.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (ctx, idx) {
                                  final p = _plugins[idx];
                                  final name = p['name'] ?? p['id'] ?? 'Unnamed Plugin';
                                  final author = (p['author'] ?? 'Community')
                                      .toString()
                                      .replaceAll(RegExp(r'\s*\(Outlet\s*#?\d+\)', caseSensitive: false), '')
                                      .trim();
                                  final desc = p['description']?.toString() ?? 'Community-contributed custom integration script.';
                                  final lang = (p['language'] ?? 'typescript').toString().toUpperCase();
                                  final category = p['category'] ?? 'Integration';
                                  final isMine = p['isMine'] == true;

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isMine
                                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                            : Colors.grey.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.code_rounded, color: Color(0xFF2563EB), size: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      lang,
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                                    ),
                                                  ),
                                                  if (isMine) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'YOUR OUTLET',
                                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                desc,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.person_outline, size: 13, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Author: $author',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(Icons.category_outlined, size: 13, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    category,
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.visibility_outlined, size: 16),
                                          label: const Text('Inspect & Fork', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            widget.onSelectPlugin(p);
                                          },
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
      ),
    );
  }
}
