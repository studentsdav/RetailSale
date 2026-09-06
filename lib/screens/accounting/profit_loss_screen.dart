import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/accounting/financial_reports_controller.dart';

class ProfitLossScreen extends StatefulWidget {
  final String? outletId;
  const ProfitLossScreen({super.key, this.outletId});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  final FinancialReportsController ctrl = FinancialReportsController();

  String _selectedPeriod = 'today';
  DateTimeRange? _customDateRange;

  final Map<String, String> _periodLabels = {
    'today': 'Today',
    'yesterday': 'Yesterday',
    'this_week': 'This Week',
    'this_month': 'This Month',
    'this_year': 'This Year',
    'all': 'All Time',
    'custom': 'Custom Range',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (_selectedPeriod == 'custom' && _customDateRange != null) {
      final start = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
      final end = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
      ctrl.fetchProfitLoss(startDate: start, endDate: end, outletId: widget.outletId);
    } else {
      ctrl.fetchProfitLoss(period: _selectedPeriod, outletId: widget.outletId);
    }
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customDateRange = picked;
      });
      _loadData();
    }
  }

  void _showProfitLossFormulaDialog(BuildContext context, Map<String, dynamic> data) {
    final trading = data['tradingAccount'] ?? {};
    final pl = data['profitAndLossAccount'] ?? {};

    final double grossSales = double.tryParse((trading['totalRevenue'] ?? 0).toString()) ?? 0.0;
    final double discounts = double.tryParse((trading['salesDiscounts'] ?? 0).toString()) ?? 0.0;
    final double netRevenue = double.tryParse((trading['netSalesRevenue'] ?? 0).toString()) ?? 0.0;
    final double cogs = double.tryParse((trading['costOfGoodsSold'] ?? 0).toString()) ?? 0.0;
    final double expenses = double.tryParse((pl['operatingExpenses'] ?? 0).toString()) ?? 0.0;

    final double grossProfitVal = double.tryParse((trading['grossProfit'] ?? 0).toString()) ?? 0.0;
    final double grossLossVal = double.tryParse((trading['grossLoss'] ?? 0).toString()) ?? 0.0;
    final bool isGrossProfit = (trading['isGrossProfit'] == true) || (grossProfitVal >= grossLossVal);
    final double displayGrossAmount = isGrossProfit ? grossProfitVal : grossLossVal;

    final double netProfitVal = double.tryParse((pl['netProfit'] ?? 0).toString()) ?? 0.0;
    final double netLossVal = double.tryParse((pl['netLoss'] ?? 0).toString()) ?? 0.0;
    final bool isNetProfit = (pl['isNetProfit'] == true) || (netProfitVal >= netLossVal);
    final double displayNetAmount = isNetProfit ? netProfitVal : netLossVal;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isNetProfit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetProfit ? Icons.trending_up : Icons.trending_down,
                color: isNetProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Profit & Loss Formula',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How Profit & Loss is calculated in Accounting & Dashboard:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📐 GROSS PROFIT FORMULA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gross Profit = Today Revenue (Excl. Tax) - Today COGS',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                    const Divider(height: 16),
                    const Text(
                      '🔻 GROSS LOSS FORMULA (When Cost > Revenue)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gross Loss = Today COGS - Today Revenue (Excl. Tax)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                    const Divider(height: 16),
                    const Text(
                      '📈 NET PROFIT FORMULA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Net Profit = Today Revenue (Excl. Tax) - Today COGS - Operating Expenses\n(Net Profit = Gross Profit - Operating Expenses)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 TAX & GST HANDLING NOTE:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Same universal formula applies for Taxable, Non-Taxable, Inclusive, & Exclusive GST sales.\n'
                      '• GST collected is a government liability, NOT revenue. For Inclusive GST, tax is deducted before calculating Gross Profit.\n'
                      '• COGS = Sold Quantity × Item Purchase Cost Rate.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Live ${_periodLabels[_selectedPeriod] ?? 'Period'} Component Values:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              if (discounts > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('• Gross Sale (Excl. Tax):', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                    Text('₹${grossSales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('• Less Discount Given:', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                    Text('- ₹${discounts.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('• Net Revenue (Excl. Tax):', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                  Text('₹${netRevenue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('• COGS (Cost of Goods):', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                  Text('₹${cogs.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('• Less Operating Expenses:', style: TextStyle(fontSize: 12.5, color: Color(0xFF8B5CF6))),
                  Text('- ₹${expenses.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isGrossProfit ? '• Calculated Gross Profit:' : '• Calculated Gross Loss:',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '₹${displayGrossAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isGrossProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNetProfit ? '• Calculated Net Profit:' : '• Calculated Net Loss:',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹${displayNetAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isNetProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '📌 Formula Breakdown: Net Profit = Net Revenue (₹${netRevenue.toStringAsFixed(2)}) - COGS (₹${cogs.toStringAsFixed(2)}) - Operating Expenses (₹${expenses.toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Statement of Profit & Loss (P&L)',
          style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
        actions: [
          IconButton(
            tooltip: 'View Profit & Loss Formula',
            icon: const Icon(Icons.functions_rounded, color: primaryColor),
            onPressed: () => _showProfitLossFormulaDialog(context, ctrl.profitLossData),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: primaryColor),
            onPressed: _loadData,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          if (ctrl.loading) return const Center(child: CircularProgressIndicator());

          final data = ctrl.profitLossData;
          final trading = data['tradingAccount'] ?? {};
          final pl = data['profitAndLossAccount'] ?? {};

          final grossSales = double.tryParse((trading['totalRevenue'] ?? 0).toString()) ?? 0.0;
          final salesDiscounts = double.tryParse((trading['salesDiscounts'] ?? 0).toString()) ?? 0.0;
          final netSalesRevenue = double.tryParse((trading['netSalesRevenue'] ?? 0).toString()) ?? (grossSales - salesDiscounts);

          final openingStock = double.tryParse((trading['openingStock'] ?? 0).toString()) ?? 0.0;
          final purchases = double.tryParse((trading['purchases'] ?? 0).toString()) ?? 0.0;
          final directFreight = double.tryParse((trading['directFreight'] ?? 0).toString()) ?? 0.0;
          final closingStock = double.tryParse((trading['closingStock'] ?? 0).toString()) ?? 0.0;
          final cogs = double.tryParse((trading['costOfGoodsSold'] ?? 0).toString()) ?? 0.0;
          final grossProfit = double.tryParse((trading['grossProfit'] ?? 0).toString()) ?? 0.0;
          final grossLoss = double.tryParse((trading['grossLoss'] ?? 0).toString()) ?? 0.0;
          final bool isGrossProfit = (trading['isGrossProfit'] == true) || (grossProfit >= grossLoss);
          final double displayGross = isGrossProfit ? grossProfit : grossLoss;

          final indirectIncome = double.tryParse((pl['indirectIncome'] ?? 0).toString()) ?? 0.0;
          final totalOperatingIncome = double.tryParse((pl['totalOperatingIncome'] ?? 0).toString()) ?? grossProfit;
          final expenses = double.tryParse((pl['operatingExpenses'] ?? 0).toString()) ?? 0.0;
          final expenseBreakdown = pl['expenseBreakdown'] as List? ?? [];
          final netProfit = double.tryParse((pl['netProfit'] ?? 0).toString()) ?? 0.0;
          final netLoss = double.tryParse((pl['netLoss'] ?? 0).toString()) ?? 0.0;
          final bool isNetProfit = (pl['isNetProfit'] == true) || (netProfit >= netLoss);
          final double displayNet = isNetProfit ? netProfit : netLoss;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Filter & Formula Banner
              _buildFilterBar(primaryColor),
              const SizedBox(height: 12),

              // KPI Quick Summary Bar
              _buildSummaryBanner(isNetProfit, displayNet, isGrossProfit, displayGross, netSalesRevenue, cogs, expenses),
              const SizedBox(height: 16),

              // PART I: TRADING ACCOUNT
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PART I: TRADING ACCOUNT (Gross Profit Calculation)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: primaryColor),
                          ),
                          InkWell(
                            onTap: () => _showProfitLossFormulaDialog(context, data),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 15, color: primaryColor),
                                  SizedBox(width: 4),
                                  Text(
                                    'Formula Info',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _row('Gross Sales Revenue (Excl. GST)', '₹${grossSales.toStringAsFixed(2)}', Colors.black87),
                      _row('Less: Sales Returns / Discounts', '(₹${salesDiscounts.toStringAsFixed(2)})', Colors.red.shade700),
                      const Divider(height: 12),
                      _row('NET SALES REVENUE (A)', '₹${netSalesRevenue.toStringAsFixed(2)}', primaryColor, isBold: true),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cost of Goods Sold (COGS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.grey)),
                          Text('(COGS = Sold Qty × Purchase Cost Rate)', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                        ],
                      ),
                      _row('  Opening Stock', '₹${openingStock.toStringAsFixed(2)}', Colors.black54),
                      _row('  Add: Purchases (Net of GST)', '₹${purchases.toStringAsFixed(2)}', Colors.black54),
                      _row('  Add: Direct Freight & Freight Charges', '₹${directFreight.toStringAsFixed(2)}', Colors.black54),
                      _row('  Less: Closing Stock (Unsold Inventory)', '(₹${closingStock.toStringAsFixed(2)})', Colors.green.shade700),
                      _row('TOTAL COST OF GOODS SOLD (B)', '₹${cogs.toStringAsFixed(2)}', Colors.red.shade700, isBold: true),
                      const Divider(),
                      _row(
                        isGrossProfit ? 'GROSS PROFIT [ A - B ]' : 'GROSS LOSS [ B - A ]',
                        '₹${displayGross.toStringAsFixed(2)}',
                        isGrossProfit ? Colors.green.shade800 : Colors.red.shade800,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // PART II: PROFIT & LOSS ACCOUNT
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PART II: PROFIT & LOSS ACCOUNT (Net Income Calculation)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: primaryColor),
                      ),
                      const Divider(height: 20),
                      _row(
                        isGrossProfit ? 'GROSS PROFIT B/F' : 'GROSS LOSS B/F',
                        isGrossProfit ? '₹${displayGross.toStringAsFixed(2)}' : '(₹${displayGross.toStringAsFixed(2)})',
                        isGrossProfit ? Colors.black87 : Colors.red.shade700,
                      ),
                      _row('Add: Indirect Income (Interest / Discounts Received)', '₹${indirectIncome.toStringAsFixed(2)}', Colors.green.shade700),
                      _row('TOTAL OPERATING INCOME (C)', '₹${totalOperatingIncome.toStringAsFixed(2)}', primaryColor, isBold: true),
                      const SizedBox(height: 12),
                      const Text('Less: Indirect & Operating Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.grey)),
                      if (expenseBreakdown.isEmpty)
                        _row('  General Operating Expenses', '₹${expenses.toStringAsFixed(2)}', Colors.red.shade700)
                      else
                        ...expenseBreakdown.map((e) => _row(
                              '  ${e['category'] ?? 'Expense'}',
                              '₹${(double.tryParse((e['amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
                              Colors.red.shade700,
                            )),
                      const Divider(height: 12),
                      _row('TOTAL INDIRECT EXPENSES (D)', '₹${expenses.toStringAsFixed(2)}', Colors.red.shade700, isBold: true),
                      const Divider(),
                      _row(
                        isNetProfit ? 'NET PROFIT BEFORE TAX [ C - D ]' : 'NET LOSS BEFORE TAX [ D - C ]',
                        '₹${displayNet.toStringAsFixed(2)}',
                        isNetProfit ? Colors.green.shade800 : Colors.red.shade800,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.filter_alt_outlined, size: 18, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            const Text('Period:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(width: 8),
            ...['today', 'yesterday', 'this_week', 'this_month', 'this_year', 'all'].map((period) {
              final isSelected = _selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: FilterChip(
                  label: Text(_periodLabels[period] ?? period),
                  selected: isSelected,
                  selectedColor: primaryColor.withAlpha(38),
                  checkmarkColor: primaryColor,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? primaryColor : const Color(0xFF475569),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedPeriod = period;
                        _customDateRange = null;
                      });
                      _loadData();
                    }
                  },
                ),
              );
            }),
            FilterChip(
              label: Text(
                _selectedPeriod == 'custom' && _customDateRange != null
                    ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                    : 'Custom',
              ),
              selected: _selectedPeriod == 'custom',
              selectedColor: primaryColor.withAlpha(38),
              checkmarkColor: primaryColor,
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: _selectedPeriod == 'custom' ? FontWeight.bold : FontWeight.normal,
                color: _selectedPeriod == 'custom' ? primaryColor : const Color(0xFF475569),
              ),
              onSelected: (_) => _selectCustomDateRange(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(
    bool isNetProfit,
    double displayNet,
    bool isGrossProfit,
    double displayGross,
    double netRevenue,
    double cogs,
    double expenses,
  ) {
    final bgColor = isNetProfit ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final borderColor = isNetProfit ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);
    final textColor = isNetProfit ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isNetProfit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isNetProfit ? 'NET PROFIT' : 'NET LOSS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${_periodLabels[_selectedPeriod] ?? 'Period'})',
                    style: TextStyle(fontSize: 11, color: textColor.withAlpha(204)),
                  ),
                ],
              ),
              Text(
                '₹${displayNet.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Revenue: ₹${netRevenue.toStringAsFixed(0)}  |  COGS: ₹${cogs.toStringAsFixed(0)}  |  Expenses: ₹${expenses.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, color: textColor.withAlpha(217), fontWeight: FontWeight.w500),
              ),
              InkWell(
                onTap: () => _showProfitLossFormulaDialog(context, ctrl.profitLossData),
                child: Text(
                  'Dashboard Formula >',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
