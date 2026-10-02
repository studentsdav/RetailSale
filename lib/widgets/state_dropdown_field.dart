import 'package:flutter/material.dart';
import '../core/services/state_service.dart';
import '../core/utils/country_tax_helper.dart';

class StateDropdownField extends StatefulWidget {
  final TextEditingController controller;
  final String? countryCode;
  final String? label;
  final double? width;
  final bool enabled;
  final bool showAddButton;
  final ValueChanged<String?>? onSelected;
  final InputDecoration? decoration;

  const StateDropdownField({
    super.key,
    required this.controller,
    this.countryCode,
    this.label,
    this.width = 240,
    this.enabled = true,
    this.showAddButton = true,
    this.onSelected,
    this.decoration,
  });

  @override
  State<StateDropdownField> createState() => _StateDropdownFieldState();
}

class _StateDropdownFieldState extends State<StateDropdownField> {
  List<String> _states = [];

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  @override
  void didUpdateWidget(covariant StateDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final curCountry = CountryTaxHelper.normalizeCountryCode(widget.countryCode);
    final oldCountry = CountryTaxHelper.normalizeCountryCode(oldWidget.countryCode);
    if (curCountry != oldCountry) {
      _loadStates();
    }
  }

  Future<void> _loadStates() async {
    final country = CountryTaxHelper.normalizeCountryCode(widget.countryCode);
    final list = await StateService.fetchStates(countryCode: country);

    if (mounted) {
      setState(() {
        _states = List.from(list);
        final currentText = widget.controller.text.trim();
        if (currentText.isNotEmpty && !_states.contains(currentText)) {
          _states.insert(0, currentText);
        }
      });
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final defaultCountry = CountryTaxHelper.normalizeCountryCode(widget.countryCode);
    final countryCtrl = TextEditingController(text: defaultCountry);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.public, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Add Custom State / Region', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Save a custom state, province, or region in the database for this outlet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'State / Region Name *',
                    hintText: 'e.g. Nairobi, California, Dubai',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: countryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Country Code',
                          hintText: 'e.g. US, IN, KE, GB, AE',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Code (Optional)',
                          hintText: 'e.g. CA, NY, NBI',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: isSaving
                  ? null
                  : () async {
                      final sName = nameCtrl.text.trim();
                      if (sName.isEmpty) return;
                      setDlgState(() => isSaving = true);
                      try {
                        final country = CountryTaxHelper.normalizeCountryCode(countryCtrl.text.trim());
                        final res = await StateService.createCustomState(
                          stateName: sName,
                          countryCode: country,
                          stateCode: codeCtrl.text.trim(),
                        );
                        if (dialogCtx.mounted) {
                          Navigator.pop(ctx);
                          widget.controller.text = sName;
                          if (widget.onSelected != null) {
                            widget.onSelected!(sName);
                          }
                          await _loadStates();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res?['message'] ?? 'Custom region "$sName" saved to database!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (dialogCtx.mounted) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text('Failed to save state: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Save State'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = CountryTaxHelper.normalizeCountryCode(widget.countryCode);
    final isIndia = CountryTaxHelper.isIndiaCountry(country);
    final fieldLabel = widget.label ?? (isIndia ? 'State (Optional)' : 'State / Region (Optional)');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DropdownMenu<String>(
          width: widget.width,
          enabled: widget.enabled,
          controller: widget.controller,
          label: Text(fieldLabel),
          enableFilter: true,
          requestFocusOnTap: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: widget.enabled ? Colors.white : Colors.grey.shade100,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          dropdownMenuEntries: _states.map((String state) {
            return DropdownMenuEntry<String>(
              value: state,
              label: state,
            );
          }).toList(),
          onSelected: (String? val) {
            if (val != null) {
              widget.controller.text = val;
            }
            if (widget.onSelected != null) {
              widget.onSelected!(val);
            }
          },
        ),
        if (widget.showAddButton && widget.enabled) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB), size: 22),
            tooltip: 'Add Custom State / Region to Database',
            onPressed: _showAddDialog,
          ),
        ],
      ],
    );
  }
}
