import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../controllers/settings/whatsapp_controller.dart';
import '../../models/auth/permission_service.dart';

class WhatsAppDashboardScreen extends StatefulWidget {
  const WhatsAppDashboardScreen({super.key});

  @override
  State<WhatsAppDashboardScreen> createState() => _WhatsAppDashboardScreenState();
}

class _WhatsAppDashboardScreenState extends State<WhatsAppDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WhatsAppController _whatsappCtrl = WhatsAppController();

  bool _loading = false;
  
  // Configuration controllers
  final _wabaIdCtrl = TextEditingController();
  final _phoneIdCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _verifyTokenCtrl = TextEditingController();
  final _appSecretCtrl = TextEditingController();

  // Template Creator controllers
  final _templateNameCtrl = TextEditingController();
  final _templateBodyCtrl = TextEditingController();
  final _templateHeaderCtrl = TextEditingController();
  final _templateFooterCtrl = TextEditingController();
  final _templateQuickReplyCtrl = TextEditingController();
  String _category = 'MARKETING';
  String _language = 'en_US';
  String _headerType = 'NONE';

  // Campaign wizard controllers
  final _campaignNameCtrl = TextEditingController();
  dynamic _selectedTemplate;
  final Map<String, String> _variableMappings = {}; // varIndex -> 'name' | 'phone' | 'static'
  final Map<String, TextEditingController> _variableStaticCtrls = {}; // varIndex -> controller
  final List<dynamic> _selectedAudience = [];
  
  // Audience filters
  final _searchCtrl = TextEditingController();
  double _minSpentFilter = 0;
  String _daysFilter = 'ALL'; // ALL, 30, 90, 180

  bool get _isAdmin => PermissionService.user?.role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Add listener to template body text area to trigger live preview state update
    _templateBodyCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _templateHeaderCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _templateFooterCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _templateQuickReplyCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wabaIdCtrl.dispose();
    _phoneIdCtrl.dispose();
    _tokenCtrl.dispose();
    _verifyTokenCtrl.dispose();
    _appSecretCtrl.dispose();
    _templateNameCtrl.dispose();
    _templateBodyCtrl.dispose();
    _templateHeaderCtrl.dispose();
    _templateFooterCtrl.dispose();
    _templateQuickReplyCtrl.dispose();
    _campaignNameCtrl.dispose();
    _searchCtrl.dispose();
    for (var ctrl in _variableStaticCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      await _whatsappCtrl.getConfig();
      await _whatsappCtrl.getTemplates();
      await _whatsappCtrl.getCampaigns();
      await _whatsappCtrl.getLogs();
      await _whatsappCtrl.getAudience();
      await _whatsappCtrl.getBillingDashboard();

      // Populate config controllers
      if (_whatsappCtrl.config != null) {
        _wabaIdCtrl.text = _whatsappCtrl.config!['waba_id'] ?? '';
        _phoneIdCtrl.text = _whatsappCtrl.config!['phone_number_id'] ?? '';
        _tokenCtrl.text = _whatsappCtrl.config!['token'] ?? '';
        _verifyTokenCtrl.text = _whatsappCtrl.config!['webhook_verify_token'] ?? '';
        _appSecretCtrl.text = _whatsappCtrl.config!['app_secret'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading WhatsApp dashboard data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only administrators can save settings.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _whatsappCtrl.saveConfig({
        'waba_id': _wabaIdCtrl.text.trim(),
        'phone_number_id': _phoneIdCtrl.text.trim(),
        'token': _tokenCtrl.text.trim(),
        'webhook_verify_token': _verifyTokenCtrl.text.trim(),
        'app_secret': _appSecretCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testConnectionDialog() async {
    final testNumCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test Connection'),
        content: TextField(
          controller: testNumCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Recipient Phone Number',
            hintText: 'e.g. +919876543210',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final num = testNumCtrl.text.trim();
              if (num.isEmpty) return;
              Navigator.pop(ctx);
              
              setState(() => _loading = true);
              try {
                await _whatsappCtrl.testConnection(
                  _phoneIdCtrl.text.trim(),
                  _tokenCtrl.text.trim(),
                  num,
                );
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Success'),
                      content: const Text('Test text message triggered successfully! Check your test phone number.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
                      ],
                    ),
                  );
                }
              } catch (_) {}
              finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            child: const Text('Send Test'),
          )
        ],
      ),
    );
  }

  Future<void> _syncTemplates() async {
    setState(() => _loading = true);
    try {
      await _whatsappCtrl.syncTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Templates successfully synchronized.')),
        );
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitTemplate() async {
    final name = _templateNameCtrl.text.trim();
    final body = _templateBodyCtrl.text.trim();
    if (name.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template name and body text are required.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final buttons = [];
      if (_templateQuickReplyCtrl.text.trim().isNotEmpty) {
        buttons.add({
          'type': 'QUICK_REPLY',
          'text': _templateQuickReplyCtrl.text.trim(),
        });
      }

      await _whatsappCtrl.createTemplate({
        'template_name': name,
        'category': _category,
        'language': _language,
        'header_type': _headerType,
        'header_text': _headerType == 'TEXT' ? _templateHeaderCtrl.text.trim() : null,
        'body_text': body,
        'footer_text': _templateFooterCtrl.text.trim().isEmpty ? null : _templateFooterCtrl.text.trim(),
        'buttons': buttons.isNotEmpty ? buttons : null,
      });

      _templateNameCtrl.clear();
      _templateBodyCtrl.clear();
      _templateHeaderCtrl.clear();
      _templateFooterCtrl.clear();
      _templateQuickReplyCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template submitted successfully.')),
        );
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onTemplateSelected(dynamic t) {
    setState(() {
      _selectedTemplate = t;
      _variableMappings.clear();
      _variableStaticCtrls.clear();
      
      final vars = t['variables'] ?? [];
      for (var v in vars) {
        final varStr = v.toString();
        // Auto map variable 1 to Customer Name by default
        _variableMappings[varStr] = varStr == '1' ? 'name' : 'static';
        _variableStaticCtrls[varStr] = TextEditingController();
      }
    });
  }

  Future<void> _pickCSVFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      final csvString = utf8.decode(file.bytes!);
      final lines = const LineSplitter().convert(csvString);
      
      int parsedCount = 0;
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        // Split by commas
        final cols = line.split(',');
        if (cols.isEmpty) continue;

        final phoneCol = cols.first.trim();
        // Strip non-numeric characters except +
        final sanitizedPhone = phoneCol.replaceAll(RegExp(r'[^0-9+]'), '');
        if (sanitizedPhone.length < 10) continue;

        final nameCol = cols.length > 1 ? cols[1].trim() : 'CSV contact';

        // Check if phone already in selected list to prevent duplicates
        final exists = _selectedAudience.any((e) => e['customer_phone'] == sanitizedPhone);
        if (!exists) {
          setState(() {
            _selectedAudience.add({
              'customer_phone': sanitizedPhone,
              'customer_name': nameCol,
              'last_purchase_date': null,
              'total_spent': 0.0,
              'is_custom_csv': true
            });
          });
          parsedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully loaded $parsedCount new contacts from CSV.')),
        );
      }
    } catch (e) {
      debugPrint('Error picking or parsing CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read CSV. Ensure it has valid numbers in the first column.')),
        );
      }
    }
  }

  Future<void> _launchCampaign() async {
    final name = _campaignNameCtrl.text.trim();
    if (name.isEmpty || _selectedTemplate == null || _selectedAudience.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign name, template, and target audience are required.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final recipients = _selectedAudience.map((cust) {
        final variables = [];
        final vars = _selectedTemplate['variables'] ?? [];

        for (var v in vars) {
          final varStr = v.toString();
          final mapping = _variableMappings[varStr];
          
          if (mapping == 'name') {
            variables.add(cust['customer_name'] ?? 'Customer');
          } else if (mapping == 'phone') {
            variables.add(cust['customer_phone'] ?? '');
          } else {
            // Static text
            variables.add(_variableStaticCtrls[varStr]?.text.trim() ?? '');
          }
        }

        return {
          'phone': cust['customer_phone'],
          'variables': variables,
        };
      }).toList();

      await _whatsappCtrl.launchCampaign(
        name,
        _selectedTemplate['id'],
        recipients,
      );

      _campaignNameCtrl.clear();
      _selectedAudience.clear();
      setState(() {
        _selectedTemplate = null;
      });

      // Reload analytics totals
      await _whatsappCtrl.getCampaigns();
      await _whatsappCtrl.getBillingDashboard();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign launched and broadcasting in background!')),
        );
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Business Cloud API'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.description_outlined), text: 'Templates'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Campaigns'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Configuration'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme),
                _buildTemplatesTab(theme),
                _buildCampaignTab(theme),
                _buildConfigurationTab(theme),
              ],
            ),
    );
  }

  // ==================== OVERVIEW TAB ====================
  Widget _buildOverviewTab(ThemeData theme) {
    final logs = _whatsappCtrl.logs;
    final dashboard = _whatsappCtrl.billingDashboard;
    
    final estBill = dashboard?['total_spent'] ?? 0.0;
    final sent = dashboard?['messages_sent'] ?? 0;
    final roi = dashboard?['roi_percent'] ?? 0.0;
    final revenue = dashboard?['revenue_generated'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WhatsApp Marketing & Billing Dashboard', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisExtent: 140,
            children: [
              _analyticsCard(
                'Estimated Meta Bill (Month)',
                '₹ ${NumberFormat('#,##0.00').format(estBill)}',
                Colors.orange.shade700,
                Icons.account_balance_wallet_outlined,
                'Based on marketing (₹0.86) and utility (₹0.12) rates',
              ),
              _analyticsCard(
                'Total Messages Sent',
                NumberFormat('#,##0').format(sent),
                Colors.blue.shade700,
                Icons.outgoing_mail,
                'Successful dispatches for current calendar month',
              ),
              _analyticsCard(
                'Campaign ROI',
                '${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(1)}%',
                Colors.green.shade700,
                Icons.trending_up,
                'Generated ₹${NumberFormat('#,##0.00').format(revenue)} from campaigns',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent Events Telemetry Log', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: logs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No telemetry logs recorded yet.')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length > 20 ? 20 : logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = logs[idx];
                      final date = DateTime.tryParse(item['updated_at'] ?? '') ?? DateTime.now();
                      final formattedDate = DateFormat('dd MMM yyyy HH:mm').format(date);
                      final costText = item['cost'] != null ? ' | ₹${item['cost']}' : '';
                      return ListTile(
                        leading: _statusBadge(item['delivery_status']),
                        title: Text(item['recipient_phone'] ?? 'N/A'),
                        subtitle: Text('${item['message_type']}$costText | $formattedDate'),
                        trailing: item['error_message'] != null
                            ? Tooltip(
                                message: item['error_message'],
                                child: const Icon(Icons.warning_amber, color: Colors.orange),
                              )
                            : null,
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _analyticsCard(String title, String value, Color color, IconData icon, String subtitle) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String? status) {
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade800;
    switch (status) {
      case 'read':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'delivered':
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade800;
        break;
      case 'sent':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        break;
      case 'failed':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      case 'queued':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status?.toUpperCase() ?? 'QUEUED',
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  // ==================== TEMPLATES TAB ====================
  Widget _buildTemplatesTab(ThemeData theme) {
    final templates = _whatsappCtrl.templates;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Creation Form
          Expanded(
            flex: 6,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create & Submit Message Template', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _templateNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Template Name',
                        hintText: 'e.g. invoice_alert (lowercase, underscores only)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'MARKETING', child: Text('MARKETING')),
                              DropdownMenuItem(value: 'UTILITY', child: Text('UTILITY')),
                            ],
                            onChanged: (val) => setState(() => _category = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _language,
                            decoration: const InputDecoration(
                              labelText: 'Language',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'en_US', child: Text('English (en_US)')),
                              DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)')),
                            ],
                            onChanged: (val) => setState(() => _language = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _headerType,
                      decoration: const InputDecoration(
                        labelText: 'Header Component (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'NONE', child: Text('None')),
                        DropdownMenuItem(value: 'TEXT', child: Text('Text Header')),
                        DropdownMenuItem(value: 'IMAGE', child: Text('Image Header')),
                        DropdownMenuItem(value: 'DOCUMENT', child: Text('Document/PDF Header')),
                      ],
                      onChanged: (val) => setState(() => _headerType = val!),
                    ),
                    if (_headerType == 'TEXT') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _templateHeaderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Header Text',
                          hintText: 'Supports static text or dynamic {{1}}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _templateBodyCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Body Text',
                        hintText: 'Hello {{1}}, your invoice for amount {{2}} is ready.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _templateFooterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Footer Component (Optional)',
                        hintText: 'e.g. Standard disclaimer terms',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _templateQuickReplyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quick Reply Button Text (Optional)',
                        hintText: 'e.g. Opt Out / Unsubscribe',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _submitTemplate,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Submit to Meta Manager'),
                    )
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Middle Column: Live Chat Bubble Previewer (Module E)
          Expanded(
            flex: 4,
            child: _buildLivePreviewer(theme),
          ),
          const SizedBox(width: 16),
          // Right Column: Local Cache list
          Expanded(
            flex: 6,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Synced Cache Templates', style: theme.textTheme.titleMedium),
                        IconButton(
                          onPressed: _syncTemplates,
                          icon: const Icon(Icons.sync),
                          tooltip: 'Sync with Meta API',
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    templates.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No templates fetched. Run Sync.')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: templates.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, idx) {
                              final t = templates[idx];
                              final isDefaultInvoice = t['is_default_invoice_template'] == true;
                              return ListTile(
                                title: Text(t['template_name'] ?? ''),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Category: ${t['category']} | Lang: ${t['language']}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      t['body_text'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _statusBadge(t['status']),
                                    if (t['status'] == 'APPROVED' && t['category'] == 'UTILITY') ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _whatsappCtrl.toggleDefaultInvoiceTemplate(t['id']).then((_) => _whatsappCtrl.getTemplates()),
                                        child: Text(
                                          isDefaultInvoice ? '★ DEFAULT BILL ALERT' : '☆ Use for Bill Alert',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDefaultInvoice ? Colors.green : Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // Live WhatsApp Chat Bubble Preview Widget (Module E)
  Widget _buildLivePreviewer(ThemeData theme) {
    // Live parse variables in header and body text
    String rawHeader = _templateHeaderCtrl.text;
    String rawBody = _templateBodyCtrl.text.isEmpty ? 'Type template body message here...' : _templateBodyCtrl.text;
    String rawFooter = _templateFooterCtrl.text;
    String rawButton = _templateQuickReplyCtrl.text;

    final regex = RegExp(r'\{\{(\d+)\}\}');
    
    String parsedHeader = rawHeader.replaceAllMapped(regex, (match) => '[Variable ${match.group(1)}]');
    String parsedBody = rawBody.replaceAllMapped(regex, (match) => '[Variable ${match.group(1)}]');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Smartphone Preview', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              height: 440,
              decoration: BoxDecoration(
                color: const Color(0xFFE5DDD5), // Classic WhatsApp wallpaper background
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Column(
                children: [
                  // Phone simulated header
                  Container(
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFF075E54), // WhatsApp Dark Green header
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(9)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('WhatsApp Alert Business', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            Text('online', style: TextStyle(color: Colors.white70, fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 240),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Media rendering top thumbnail placeholder
                                if (_headerType == 'IMAGE')
                                  Container(
                                    height: 80,
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.image, size: 36, color: Colors.grey),
                                  ),
                                if (_headerType == 'DOCUMENT')
                                  Container(
                                    height: 45,
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                                        SizedBox(width: 8),
                                        Text('invoice.pdf', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                if (_headerType == 'TEXT' && parsedHeader.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(parsedHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                
                                // Body text with highlighted variables
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.black, fontSize: 10.5, height: 1.3),
                                    children: _parseBodyTextSpans(parsedBody),
                                  ),
                                ),
                                
                                if (rawFooter.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(rawFooter, style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Quick reply white button rendering at bottom of bubble
                        if (rawButton.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 240,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 0.5))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.reply, size: 12, color: Color(0xFF007A65)),
                                  const SizedBox(width: 6),
                                  Text(rawButton, style: const TextStyle(fontSize: 10, color: Color(0xFF007A65), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Split parsed body text into styling spans to render variables in green bold
  List<TextSpan> _parseBodyTextSpans(String parsedBody) {
    final spans = <TextSpan>[];
    final parts = parsedBody.split(RegExp(r'(\[Variable \d+\])'));
    
    for (var part in parts) {
      if (part.startsWith('[Variable ') && part.endsWith(']')) {
        spans.add(TextSpan(
          text: part,
          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(text: part));
      }
    }
    return spans;
  }

  // ==================== CAMPAIGN TAB ====================
  Widget _buildCampaignTab(ThemeData theme) {
    final campaigns = _whatsappCtrl.campaigns;
    final approvedTemplates = _whatsappCtrl.templates.where((t) => t['status'] == 'APPROVED').toList();
    
    // Apply filters to audience list
    List<dynamic> filteredAudience = List.from(_whatsappCtrl.audience);
    final search = _searchCtrl.text.toLowerCase().trim();
    if (search.isNotEmpty) {
      filteredAudience = filteredAudience.where((c) {
        final name = String.fromCharCodes(c['customer_name']?.toString().codeUnits ?? []).toLowerCase();
        final phone = c['customer_phone']?.toString().toLowerCase() ?? '';
        return name.contains(search) || phone.contains(search);
      }).toList();
    }
    if (_minSpentFilter > 0) {
      filteredAudience = filteredAudience.where((c) => (double.tryParse(c['total_spent']?.toString() ?? '0') ?? 0) >= _minSpentFilter).toList();
    }
    if (_daysFilter != 'ALL') {
      final days = int.tryParse(_daysFilter) ?? 30;
      final cutOff = DateTime.now().subtract(Duration(days: days));
      filteredAudience = filteredAudience.where((c) {
        if (c['last_purchase_date'] == null) return false;
        final date = DateTime.tryParse(c['last_purchase_date']);
        return date != null && date.isAfter(cutOff);
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Wizard Panel
          Expanded(
            flex: 7,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Broadcast Campaign Wizard', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _campaignNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Campaign Name',
                        hintText: 'e.g. Eid Mubarak Discount Alert',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<dynamic>(
                      value: _selectedTemplate,
                      hint: const Text('Select Approved Template'),
                      decoration: const InputDecoration(
                        labelText: 'Templates Selection',
                        border: OutlineInputBorder(),
                      ),
                      items: approvedTemplates.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text('${t['template_name']} (${t['category']})'),
                        );
                      }).toList(),
                      onChanged: _onTemplateSelected,
                    ),
                    if (_selectedTemplate != null) ...[
                      const SizedBox(height: 16),
                      Text('Template Body Preview:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          _selectedTemplate['body_text'] ?? '',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                      
                      // Variable Mapping Engine (Module F)
                      if (_variableMappings.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Map Dynamic Variables Mappings:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ..._variableMappings.entries.map((entry) {
                          final varIdx = entry.key;
                          final mapping = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text('Variable {{ $varIdx }}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: DropdownButtonFormField<String>(
                                    value: mapping,
                                    items: const [
                                      DropdownMenuItem(value: 'name', child: Text('Customer First Name')),
                                      DropdownMenuItem(value: 'phone', child: Text('Customer Phone Number')),
                                      DropdownMenuItem(value: 'static', child: Text('Static Fallback Value')),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _variableMappings[varIdx] = val!;
                                      });
                                    },
                                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: mapping == 'static'
                                      ? TextField(
                                          controller: _variableStaticCtrls[varIdx],
                                          decoration: const InputDecoration(
                                            labelText: 'Static Value',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.all(8),
                                          ),
                                        )
                                      : const Text('Auto-mapped from list metadata', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // Audience Builder Data Grid (Module F)
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Select Target Audience Builder:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: _pickCSVFile,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Upload CSV Target List'),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Grid Filters
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Search Name/Phone',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _daysFilter,
                              decoration: const InputDecoration(
                                labelText: 'Recency filter',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All Purchases')),
                                DropdownMenuItem(value: '30', child: Text('Purchased last 30 Days')),
                                DropdownMenuItem(value: '90', child: Text('Purchased last 90 Days')),
                                DropdownMenuItem(value: '180', child: Text('Purchased last 180 Days')),
                              ],
                              onChanged: (val) => setState(() => _daysFilter = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Min Spent Filter: ', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: _minSpentFilter,
                              min: 0,
                              max: 50000,
                              divisions: 50,
                              label: '₹ ${_minSpentFilter.round()}',
                              onChanged: (val) => setState(() => _minSpentFilter = val),
                            ),
                          ),
                          Text('₹ ${_minSpentFilter.round()}+', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Container(
                              color: Colors.grey.shade200,
                              height: 35,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _selectedAudience.length == filteredAudience.length && filteredAudience.isNotEmpty,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedAudience.clear();
                                          _selectedAudience.addAll(filteredAudience);
                                        } else {
                                          _selectedAudience.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  const Expanded(flex: 3, child: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  const Expanded(flex: 2, child: Text('Spent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: filteredAudience.isEmpty
                                  ? const Center(child: Text('No matching audience customers.'))
                                  : ListView.builder(
                                      itemCount: filteredAudience.length,
                                      itemBuilder: (ctx, index) {
                                        final cust = filteredAudience[index];
                                        final isSelected = _selectedAudience.any((e) => e['customer_phone'] == cust['customer_phone']);
                                        final name = cust['customer_name'] ?? 'Walk-in';
                                        final phone = cust['customer_phone'] ?? '';
                                        final spent = double.tryParse(cust['total_spent']?.toString() ?? '0') ?? 0.0;
                                        
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedAudience.removeWhere((e) => e['customer_phone'] == phone);
                                              } else {
                                                _selectedAudience.add(cust);
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                            ),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      if (val == true) {
                                                        _selectedAudience.add(cust);
                                                      } else {
                                                        _selectedAudience.removeWhere((e) => e['customer_phone'] == phone);
                                                      }
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(flex: 3, child: Text(name, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                Expanded(flex: 3, child: Text(phone, style: const TextStyle(fontSize: 11))),
                                                Expanded(flex: 2, child: Text('₹${spent.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Selected Target Count: ${_selectedAudience.length} recipients'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _launchCampaign,
                        icon: const Icon(Icons.rocket_launch_outlined),
                        label: const Text('Launch Campaign Broadcast'),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right: History Panel
          Expanded(
            flex: 5,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Campaigns History Logs', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    campaigns.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No historical campaigns found.')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: campaigns.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, idx) {
                              final c = campaigns[idx];
                              final date = DateTime.tryParse(c['created_at'] ?? '') ?? DateTime.now();
                              final formatted = DateFormat('dd MMM yyyy HH:mm').format(date);
                              return ListTile(
                                title: Text(c['campaign_name'] ?? 'Marketing Campaign'),
                                subtitle: Text('Template: ${c['template']?['template_name']} | Date: $formatted'),
                                trailing: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  radius: 18,
                                  child: Text(
                                    c['total_recipients']?.toString() ?? '0',
                                    style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              );
                            },
                          )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ==================== CONFIGURATION TAB ====================
  Widget _buildConfigurationTab(ThemeData theme) {
    // Generate Webhook URL dynamically
    const webhookUrl = 'https://(YOUR_API_DOMAIN)/webhooks/whatsapp';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Configuration Panel', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('Manage credentials for WhatsApp Cloud API integration.', style: theme.textTheme.bodySmall),
                      const Divider(height: 32),
                      
                      TextField(
                        controller: _wabaIdCtrl,
                        enabled: _isAdmin,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp Business Account ID (WABA ID)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneIdCtrl,
                        enabled: _isAdmin,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_android),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tokenCtrl,
                        enabled: _isAdmin,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Permanent Access Token',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.vpn_key),
                          helperText: 'Generated in Meta Business Manager System Users settings',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _verifyTokenCtrl,
                        enabled: _isAdmin,
                        decoration: const InputDecoration(
                          labelText: 'Webhook Verification Token (Custom Secret)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.security),
                          helperText: 'A secret key you choose. Paste this in Meta Developer Webhooks console',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _appSecretCtrl,
                        enabled: _isAdmin,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'App Secret (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                          helperText: 'Required to authenticate incoming Webhooks signatures',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _testConnectionDialog,
                            icon: const Icon(Icons.network_check_outlined),
                            label: const Text('Test Connection'),
                          ),
                          if (_isAdmin)
                            FilledButton.icon(
                              onPressed: _saveConfig,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Credentials'),
                            )
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Webhook Configuration Hint:', style: theme.textTheme.titleSmall?.copyWith(color: Colors.blue.shade900)),
                      const SizedBox(height: 8),
                      Text(
                        'To start receiving real-time status updates (sent, delivered, read, failed) and template status approvals, set up a webhook subscription in the Meta Developer portal pointing to:',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                      ),
                      const SizedBox(height: 8),
                      const SelectableText(
                        webhookUrl,
                        style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Provide the Webhook Verification Token configured above to authorize the handshake verification.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
