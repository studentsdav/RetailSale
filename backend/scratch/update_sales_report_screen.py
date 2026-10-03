import re

path = 'lib/screens/reports/sales_report_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace in _rows:
target_rows = """        final lineVal = _isTaxedItem(item)
            ? (itemTaxable + taxAmount)
            : itemNetVal;

        flattened.add(
          _GstSalesRow(
            invoiceDate: sale.saleDate,
            invoiceNumber: sale.saleNo,
            customerName: sale.customerName.trim().isEmpty
                ? 'Walk-in Customer'
                : sale.customerName.trim(),
            customerGstin: customerGstin,
            invoiceValue: sale.netAmount,
            placeOfSupply: placeOfSupply,
            itemDescription: item.itemName.trim(),
            itemGroup: item.itemGroup.trim().isEmpty
                ? 'Ungrouped'
                : item.itemGroup.trim(),
            subCategory: item.subCategory.trim().isEmpty
                ? 'Uncategorized'
                : item.subCategory.trim(),
            brand: item.brand.trim().isEmpty
                ? 'No Brand'
                : item.brand.trim(),
            hsnSacCode: item.hsnSacCode.trim(),
            quantity: item.qty,
            unit: item.unit.trim(),
            taxableValue: itemTaxable,
            taxSaleValue: _isTaxedItem(item) ? itemNetVal : 0,
            nonTaxSaleValue: _isTaxedItem(item) ? 0 : itemNetVal,
            cgstAmount: cgst,
            sgstAmount: sgst,
            igstAmount: igst,
            taxAmount: taxAmount,
            totalLineValue: lineVal,
            totalInvoiceValue: itemNetVal,
            saleDateTime: sale.saleDate,
            paymentMode: sale.paymentMode,
            discount: item.lineDiscount,
            subTotal: item.amount,
          ),
        );"""

replacement_rows = """        final lineVal = _isTaxedItem(item)
            ? (itemTaxable + taxAmount)
            : itemNetVal;

        final mods = _extractItemModifiers(item);
        final double totalModPrice = mods.fold<double>(0, (sum, m) => sum + m.totalPrice);
        final bool hasMods = mods.isNotEmpty && totalModPrice > 0 && item.amount >= totalModPrice;

        if (!hasMods) {
          flattened.add(
            _GstSalesRow(
              invoiceDate: sale.saleDate,
              invoiceNumber: sale.saleNo,
              customerName: sale.customerName.trim().isEmpty
                  ? 'Walk-in Customer'
                  : sale.customerName.trim(),
              customerGstin: customerGstin,
              invoiceValue: sale.netAmount,
              placeOfSupply: placeOfSupply,
              itemDescription: item.itemName.trim(),
              itemGroup: item.itemGroup.trim().isEmpty
                  ? 'Ungrouped'
                  : item.itemGroup.trim(),
              subCategory: item.subCategory.trim().isEmpty
                  ? 'Uncategorized'
                  : item.subCategory.trim(),
              brand: item.brand.trim().isEmpty
                  ? 'No Brand'
                  : item.brand.trim(),
              hsnSacCode: item.hsnSacCode.trim(),
              quantity: item.qty,
              unit: item.unit.trim(),
              taxableValue: itemTaxable,
              taxSaleValue: _isTaxedItem(item) ? itemNetVal : 0,
              nonTaxSaleValue: _isTaxedItem(item) ? 0 : itemNetVal,
              cgstAmount: cgst,
              sgstAmount: sgst,
              igstAmount: igst,
              taxAmount: taxAmount,
              totalLineValue: lineVal,
              totalInvoiceValue: itemNetVal,
              saleDateTime: sale.saleDate,
              paymentMode: sale.paymentMode,
              discount: item.lineDiscount,
              subTotal: item.amount,
            ),
          );
        } else {
          final double baseSubTotal = (item.amount - totalModPrice).clamp(0.0, double.infinity);
          final double baseRatio = item.amount > 0 ? (baseSubTotal / item.amount) : 1.0;

          flattened.add(
            _GstSalesRow(
              invoiceDate: sale.saleDate,
              invoiceNumber: sale.saleNo,
              customerName: sale.customerName.trim().isEmpty
                  ? 'Walk-in Customer'
                  : sale.customerName.trim(),
              customerGstin: customerGstin,
              invoiceValue: sale.netAmount,
              placeOfSupply: placeOfSupply,
              itemDescription: item.itemName.trim(),
              itemGroup: item.itemGroup.trim().isEmpty
                  ? 'Ungrouped'
                  : item.itemGroup.trim(),
              subCategory: item.subCategory.trim().isEmpty
                  ? 'Uncategorized'
                  : item.subCategory.trim(),
              brand: item.brand.trim().isEmpty
                  ? 'No Brand'
                  : item.brand.trim(),
              hsnSacCode: item.hsnSacCode.trim(),
              quantity: item.qty,
              unit: item.unit.trim(),
              taxableValue: itemTaxable * baseRatio,
              taxSaleValue: _isTaxedItem(item) ? (itemNetVal * baseRatio) : 0,
              nonTaxSaleValue: _isTaxedItem(item) ? 0 : (itemNetVal * baseRatio),
              cgstAmount: cgst * baseRatio,
              sgstAmount: sgst * baseRatio,
              igstAmount: igst * baseRatio,
              taxAmount: taxAmount * baseRatio,
              totalLineValue: lineVal * baseRatio,
              totalInvoiceValue: itemNetVal * baseRatio,
              saleDateTime: sale.saleDate,
              paymentMode: sale.paymentMode,
              discount: effectiveDiscount * baseRatio,
              subTotal: baseSubTotal,
            ),
          );

          for (final mod in mods) {
            final double modRatio = item.amount > 0 ? (mod.totalPrice / item.amount) : 0.0;
            final double modTaxable = itemTaxable * modRatio;
            final double modTax = taxAmount * modRatio;
            final double modNet = itemNetVal * modRatio;
            final double modLineVal = lineVal * modRatio;

            flattened.add(
              _GstSalesRow(
                invoiceDate: sale.saleDate,
                invoiceNumber: sale.saleNo,
                customerName: sale.customerName.trim().isEmpty
                    ? 'Walk-in Customer'
                    : sale.customerName.trim(),
                customerGstin: customerGstin,
                invoiceValue: sale.netAmount,
                placeOfSupply: placeOfSupply,
                itemDescription: '${mod.name} (Add-on)',
                itemGroup: 'Modifiers / Add-ons',
                subCategory: 'Add-ons',
                brand: item.brand.trim().isNotEmpty ? '${item.brand.trim()} Add-on' : 'Add-on',
                hsnSacCode: item.hsnSacCode.trim().isNotEmpty ? item.hsnSacCode.trim() : 'NA',
                quantity: mod.qty,
                unit: 'Nos',
                taxableValue: modTaxable,
                taxSaleValue: _isTaxedItem(item) ? modNet : 0,
                nonTaxSaleValue: _isTaxedItem(item) ? 0 : modNet,
                cgstAmount: cgst * modRatio,
                sgstAmount: sgst * modRatio,
                igstAmount: igst * modRatio,
                taxAmount: modTax,
                totalLineValue: modLineVal,
                totalInvoiceValue: modNet,
                saleDateTime: sale.saleDate,
                paymentMode: sale.paymentMode,
                discount: effectiveDiscount * modRatio,
                subTotal: mod.totalPrice,
              ),
            );
          }
        }"""

# Replace in _gstr1HsnRows:
target_hsn = """  List<_Gstr1HsnRow> get _gstr1HsnRows {
    final grouped = <String, _Gstr1HsnRow>{};
    for (final sale in _billWiseSales) {
      final isIgst = sale.igstAmount > 0.009;
      for (final item in sale.items) {
        final code =
            item.hsnSacCode.trim().isEmpty ? 'NA' : item.hsnSacCode.trim();
        final desc = item.itemName.trim();
        final unit = item.unit.trim().isEmpty ? 'NOS' : item.unit.trim();
        final taxable = _isTaxedItem(item) ? item.taxableAmount : item.netAmount;
        final tax = _isTaxedItem(item) ? item.taxAmount : 0.0;
        final cgst = isIgst ? 0.0 : tax / 2;
        final sgst = isIgst ? 0.0 : tax / 2;
        final igst = isIgst ? tax : 0.0;
        final totalVal = taxable + tax;

        final key = '$code|$unit';
        final current = grouped[key];
        if (current == null) {
          grouped[key] = _Gstr1HsnRow(
            hsnSacCode: code,
            description: desc,
            unit: unit,
            totalQty: item.qty,
            totalValue: totalVal,
            taxableValue: taxable,
            cgst: cgst,
            sgst: sgst,
            igst: igst,
          );
        } else {
          grouped[key] = current.copyWith(
            totalQty: current.totalQty + item.qty,
            totalValue: current.totalValue + totalVal,
            taxableValue: current.taxableValue + taxable,
            cgst: current.cgst + cgst,
            sgst: current.sgst + sgst,
            igst: current.igst + igst,
          );
        }
      }"""

replacement_hsn = """  List<_Gstr1HsnRow> get _gstr1HsnRows {
    final grouped = <String, _Gstr1HsnRow>{};
    for (final sale in _billWiseSales) {
      final isIgst = sale.igstAmount > 0.009;
      for (final item in sale.items) {
        final mods = _extractItemModifiers(item);
        final double totalModPrice = mods.fold<double>(0, (sum, m) => sum + m.totalPrice);
        final bool hasMods = mods.isNotEmpty && totalModPrice > 0 && item.amount >= totalModPrice;

        final double baseRatio = hasMods && item.amount > 0 ? ((item.amount - totalModPrice) / item.amount) : 1.0;

        final code = item.hsnSacCode.trim().isEmpty ? 'NA' : item.hsnSacCode.trim();
        final desc = item.itemName.trim();
        final unit = item.unit.trim().isEmpty ? 'NOS' : item.unit.trim();
        final taxable = (_isTaxedItem(item) ? item.taxableAmount : item.netAmount) * baseRatio;
        final tax = (_isTaxedItem(item) ? item.taxAmount : 0.0) * baseRatio;
        final cgst = isIgst ? 0.0 : tax / 2;
        final sgst = isIgst ? 0.0 : tax / 2;
        final igst = isIgst ? tax : 0.0;
        final totalVal = taxable + tax;

        final key = '$code|$desc|$unit';
        final current = grouped[key];
        if (current == null) {
          grouped[key] = _Gstr1HsnRow(
            hsnSacCode: code,
            description: desc,
            unit: unit,
            totalQty: item.qty,
            totalValue: totalVal,
            taxableValue: taxable,
            cgst: cgst,
            sgst: sgst,
            igst: igst,
          );
        } else {
          grouped[key] = current.copyWith(
            totalQty: current.totalQty + item.qty,
            totalValue: current.totalValue + totalVal,
            taxableValue: current.taxableValue + taxable,
            cgst: current.cgst + cgst,
            sgst: current.sgst + sgst,
            igst: current.igst + igst,
          );
        }

        if (hasMods) {
          for (final mod in mods) {
            final double modRatio = item.amount > 0 ? (mod.totalPrice / item.amount) : 0.0;
            final modDesc = '${mod.name} (Add-on)';
            final modUnit = 'NOS';
            final modTaxable = (_isTaxedItem(item) ? item.taxableAmount : item.netAmount) * modRatio;
            final modTax = (_isTaxedItem(item) ? item.taxAmount : 0.0) * modRatio;
            final modCgst = isIgst ? 0.0 : modTax / 2;
            final modSgst = isIgst ? 0.0 : modTax / 2;
            final modIgst = isIgst ? modTax : 0.0;
            final modTotalVal = modTaxable + modTax;

            final modKey = '$code|$modDesc|$modUnit';
            final modCurrent = grouped[modKey];
            if (modCurrent == null) {
              grouped[modKey] = _Gstr1HsnRow(
                hsnSacCode: code,
                description: modDesc,
                unit: modUnit,
                totalQty: mod.qty,
                totalValue: modTotalVal,
                taxableValue: modTaxable,
                cgst: modCgst,
                sgst: modSgst,
                igst: modIgst,
              );
            } else {
              grouped[modKey] = modCurrent.copyWith(
                totalQty: modCurrent.totalQty + mod.qty,
                totalValue: modCurrent.totalValue + modTotalVal,
                taxableValue: modCurrent.taxableValue + modTaxable,
                cgst: modCurrent.cgst + modCgst,
                sgst: modCurrent.sgst + modSgst,
                igst: modCurrent.igst + modIgst,
              );
            }
          }
        }
      }"""

def clean(s):
    return s.replace('\r\n', '\n').strip()

clean_content = content.replace('\r\n', '\n')
assert clean(target_rows) in clean_content, 'target_rows not found'
assert clean(target_hsn) in clean_content, 'target_hsn not found'

clean_content = clean_content.replace(clean(target_rows), clean(replacement_rows), 1)
clean_content = clean_content.replace(clean(target_hsn), clean(replacement_hsn), 1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(clean_content)

print('SUCCESSFULLY updated sales_report_screen.dart!')
