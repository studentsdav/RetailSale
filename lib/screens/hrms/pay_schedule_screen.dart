import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class PayScheduleScreen extends StatefulWidget {
  const PayScheduleScreen({Key? key}) : super(key: key);

  @override
  State<PayScheduleScreen> createState() => _PayScheduleScreenState();
}

class _PayScheduleScreenState extends State<PayScheduleScreen> {
  bool _loading = false;
  bool _saving = false;
  String? _error;

  // Calculation method settings
  String _calcMethod = 'Actual Days'; // 'Actual Days' or 'Fixed Days'
  final _fixedDaysCtrl = TextEditingController(text: '26');
  final _workingHoursCtrl = TextEditingController(text: '8.0');

  // Pay Date settings
  String _payDateType = 'Last Day'; // 'Last Day' or 'Day X'
  int _payDateDay = 1;

  // First payroll setup
  String _firstMonth = ''; // e.g. 'April-2026'
  DateTime? _firstPayDate;

  // Holiday / Weekly Off policy settings
  String _holidayWorkPolicy = 'Normal Pay';
  final _holidayMultiplierCtrl = TextEditingController(text: '1.5');

  // Selections for first month dropdown
  final List<String> _monthsList = [];

  @override
  void initState() {
    super.initState();
    _generateMonthsList();
    _loadSettings();
  }

  void _generateMonthsList() {
    final now = DateTime.now();
    final df = DateFormat('MMMM-yyyy');
    for (int i = -3; i <= 6; i++) {
      final date = DateTime(now.year, now.month + i);
      _monthsList.add(df.format(date));
    }
    _firstMonth = df.format(now);
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.hrmsPayrollSettings);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _calcMethod = data['calculation_method'] ?? 'Actual Days';
          _fixedDaysCtrl.text = (data['fixed_working_days'] ?? 26).toString();
          _workingHoursCtrl.text = (data['working_hours_per_day'] ?? 8.0).toString();
          _payDateType = data['pay_date_type'] ?? 'Last Day';
          final dayVal = int.tryParse(data['pay_date_value']?.toString() ?? '') ?? 1;
          _payDateDay = (dayVal >= 1 && dayVal <= 31) ? dayVal : 1;
          final val = data['first_month']?.toString() ?? '';
          if (val.isNotEmpty && _monthsList.contains(val)) {
            _firstMonth = val;
          }
          if (data['first_date'] != null) {
            _firstPayDate = DateTime.tryParse(data['first_date'].toString());
          }
          _holidayWorkPolicy = data['holiday_work_policy'] ?? 'Normal Pay';
          _holidayMultiplierCtrl.text = (data['holiday_overtime_multiplier'] ?? 1.5).toString();
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {
        'calculation_method': _calcMethod,
        'fixed_working_days': int.tryParse(_fixedDaysCtrl.text) ?? 26,
        'working_hours_per_day': double.tryParse(_workingHoursCtrl.text) ?? 8.0,
        'pay_date_type': _payDateType,
        'pay_date_value': _payDateDay,
        'first_month': _firstMonth,
        'first_date': _firstPayDate != null
            ? DateFormat('yyyy-MM-dd').format(_firstPayDate!)
            : null,
        'holiday_work_policy': _holidayWorkPolicy,
        'holiday_overtime_multiplier': double.tryParse(_holidayMultiplierCtrl.text) ?? 1.5,
      };

      final res = await ApiClient.post(ApiEndpoints.hrmsPayrollSettings, payload);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pay schedule settings saved successfully')),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(res['message'] ?? 'Failed to save settings');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _selectFirstPayDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstPayDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE03E2D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E3A5F),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _firstPayDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Pay Schedule', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) _buildErrorCard(),
                _buildCalculationMethodCard(),
                _buildPayDateCard(),
                _buildHolidayPolicyCard(),
                _buildFirstPayrollSetupCard(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildCalculationMethodCard() {
    return _card(
      title: 'Salary Calculation Method',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select how monthly salary should be calculated.*',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 12),
          RadioListTile<String>(
            title: const Text('Actual days in a month', style: TextStyle(fontSize: 14)),
            value: 'Actual Days',
            groupValue: _calcMethod,
            activeColor: const Color(0xFFE03E2D),
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _calcMethod = v!),
          ),
          RadioListTile<String>(
            title: const Text('Based on fixed working days per month', style: TextStyle(fontSize: 14)),
            value: 'Fixed Days',
            groupValue: _calcMethod,
            activeColor: const Color(0xFFE03E2D),
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _calcMethod = v!),
          ),
          if (_calcMethod == 'Fixed Days') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _fixedDaysCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDecor('Working Days in Month', Icons.calendar_today_outlined),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _workingHoursCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecor('Required Working Hours per Day', Icons.access_time),
          ),
        ],
      ),
    );
  }

  Widget _buildPayDateCard() {
    return _card(
      title: 'Pay Date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select when employees should be paid.*',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 12),
          RadioListTile<String>(
            title: const Text('On the last day of every month', style: TextStyle(fontSize: 14)),
            value: 'Last Day',
            groupValue: _payDateType,
            activeColor: const Color(0xFFE03E2D),
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _payDateType = v!),
          ),
          RadioListTile<String>(
            title: Row(
              children: [
                const Text('On Day ', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                DropdownButton<int>(
                  value: _payDateDay,
                  onChanged: _payDateType == 'Day X'
                      ? (v) => setState(() => _payDateDay = v!)
                      : null,
                  items: List.generate(31, (i) => i + 1)
                      .map((d) => DropdownMenuItem<int>(
                            value: d,
                            child: Text(d.toString()),
                          ))
                      .toList(),
                ),
                const SizedBox(width: 6),
                const Text(' of every month', style: TextStyle(fontSize: 14)),
              ],
            ),
            value: 'Day X',
            groupValue: _payDateType,
            activeColor: const Color(0xFFE03E2D),
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _payDateType = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayPolicyCard() {
    return _card(
      title: 'Holiday & Weekly Off Work Policy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose how the system handles payroll and leaves when employees punch attendance on holidays or weekly off days.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _holidayWorkPolicy,
            items: const [
              DropdownMenuItem(value: 'Normal Pay', child: Text('Normal Pay (Standard salary)')),
              DropdownMenuItem(value: 'Paid Overtime', child: Text('Paid Overtime (Hourly rate multiplier)')),
              DropdownMenuItem(value: 'Comp Off', child: Text('Earn Comp-Off (Credited to leave balance)')),
            ],
            onChanged: (v) => setState(() => _holidayWorkPolicy = v!),
            decoration: InputDecoration(
              labelText: 'Work Compensation Policy',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (_holidayWorkPolicy == 'Paid Overtime') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _holidayMultiplierCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecor('Overtime Pay Multiplier (e.g. 1.5, 2.0)', Icons.percent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFirstPayrollSetupCard() {
    return _card(
      title: 'First Payroll Setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Start your first payroll from*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _firstMonth,
            items: _monthsList
                .map((m) => DropdownMenuItem<String>(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _firstMonth = v!),
            decoration: _dropdownDecor(),
          ),
          const SizedBox(height: 16),
          const Text('Select a pay date for your first payroll*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
          const SizedBox(height: 6),
          InkWell(
            onTap: _selectFirstPayDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _firstPayDate != null
                        ? DateFormat('dd/MM/yyyy').format(_firstPayDate!)
                        : 'Select Date',
                    style: TextStyle(
                      fontSize: 13,
                      color: _firstPayDate != null ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF4B5563))),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _saving ? null : _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE03E2D),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const Divider(height: 24, color: Color(0xFFE5E7EB)),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 16),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE03E2D), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
    );
  }

  InputDecoration _dropdownDecor() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE03E2D), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
    );
  }
}
