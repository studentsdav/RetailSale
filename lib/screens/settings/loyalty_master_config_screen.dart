import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/sales/sales_controller.dart';

class LoyaltyMasterConfigScreen extends StatefulWidget {
  const LoyaltyMasterConfigScreen({super.key});

  @override
  State<LoyaltyMasterConfigScreen> createState() =>
      _LoyaltyMasterConfigScreenState();
}

class _LoyaltyMasterConfigScreenState extends State<LoyaltyMasterConfigScreen> {
  final SalesController _ctrl = SalesController();

  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  final _minThresholdCtrl = TextEditingController(text: '1000');
  final _earningRatioCtrl = TextEditingController(text: '1000');
  final _redemptionValueCtrl = TextEditingController(text: '1');
  final _maxRedeemPerBillCtrl = TextEditingController(text: '100');
  final _expiryDaysCtrl = TextEditingController(text: '90');

  bool _programStatus = false;
  bool _loading = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _minThresholdCtrl.dispose();
    _earningRatioCtrl.dispose();
    _redemptionValueCtrl.dispose();
    _maxRedeemPerBillCtrl.dispose();
    _expiryDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _ctrl.getLoyaltyConfig();
      _programStatus = data['program_status'] == true;
      _startDate = DateTime.tryParse((data['start_date'] ?? '').toString());
      _endDate = DateTime.tryParse((data['end_date'] ?? '').toString());
      _startDateCtrl.text =
          _startDate == null ? '' : DateFormat('dd-MMM-yyyy').format(_startDate!);
      _endDateCtrl.text =
          _endDate == null ? '' : DateFormat('dd-MMM-yyyy').format(_endDate!);
      _minThresholdCtrl.text =
          (double.tryParse((data['min_purchase_threshold'] ?? 0).toString()) ??
                  0)
              .toStringAsFixed(2);
      _earningRatioCtrl.text =
          (double.tryParse((data['earning_ratio'] ?? 1000).toString()) ?? 1000)
              .toStringAsFixed(2);
      _redemptionValueCtrl.text =
          (double.tryParse((data['redemption_value'] ?? 1).toString()) ?? 1)
              .toStringAsFixed(2);
      _maxRedeemPerBillCtrl.text =
          (int.tryParse((data['max_redeem_per_bill'] ?? 0).toString()) ?? 0)
              .toString();
      _expiryDaysCtrl.text =
          (int.tryParse((data['point_expiry_days'] ?? 90).toString()) ?? 90)
              .toString();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        _startDateCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
      } else {
        _endDate = picked;
        _endDateCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
      }
    });
  }

  Future<void> _save() async {
    final earningRatio = double.tryParse(_earningRatioCtrl.text.trim()) ?? 0;
    final redemptionValue = double.tryParse(_redemptionValueCtrl.text.trim()) ?? 0;
    if (earningRatio <= 0 || redemptionValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Earning ratio and redemption value must be greater than 0.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _ctrl.saveLoyaltyConfig({
        'program_status': _programStatus,
        'start_date': _startDate?.toIso8601String(),
        'end_date': _endDate?.toIso8601String(),
        'min_purchase_threshold':
            double.tryParse(_minThresholdCtrl.text.trim()) ?? 0,
        'earning_ratio': earningRatio,
        'redemption_value': redemptionValue,
        'max_redeem_per_bill':
            int.tryParse(_maxRedeemPerBillCtrl.text.trim()) ?? 0,
        'point_expiry_days': int.tryParse(_expiryDaysCtrl.text.trim()) ?? 90,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loyalty settings saved successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty Master Configuration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  value: _programStatus,
                  title: const Text('Program Status'),
                  subtitle: Text(_programStatus ? 'Active' : 'Deactive'),
                  onChanged: (value) => setState(() => _programStatus = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startDateCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _endDateCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _numField(
                  _minThresholdCtrl,
                  'Min Purchase Threshold',
                  'Example: 1000',
                ),
                const SizedBox(height: 12),
                _numField(
                  _earningRatioCtrl,
                  'Earning Ratio (Spend for 1 point)',
                  'Example: 1000',
                ),
                const SizedBox(height: 12),
                _numField(
                  _redemptionValueCtrl,
                  'Redemption Value (₹ per point)',
                  'Example: 1',
                ),
                const SizedBox(height: 12),
                _numField(
                  _maxRedeemPerBillCtrl,
                  'Max Redeem Per Bill (points)',
                  'Example: 200',
                  isInt: true,
                ),
                const SizedBox(height: 12),
                _numField(
                  _expiryDaysCtrl,
                  'Point Expiry Days',
                  'Example: 90',
                  isInt: true,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                )
              ],
            ),
    );
  }

  Widget _numField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isInt = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
