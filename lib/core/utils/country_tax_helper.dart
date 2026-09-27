import '../currency/currency_service.dart';

class CountryTaxHelper {
  CountryTaxHelper._();

  static bool isIndiaCountry(String? country) {
    if (country == null || country.trim().isEmpty) {
      return CurrencyService.symbol == '₹' || CurrencyService.code == 'INR';
    }
    final c = country.trim().toLowerCase();
    if (c == 'usa' || c == 'united states' || c == 'kenya' || c == 'uk' || c == 'united kingdom' || c == 'uae') {
      return false;
    }
    if (c == 'india') return true;
    return CurrencyService.symbol == '₹' || CurrencyService.code == 'INR';
  }

  static String taxName([String? country, String? taxMode]) {
    final mode = (taxMode ?? '').trim().toUpperCase();
    if (mode == 'VAT' || mode == 'VAT_ONLY' || mode == 'VAT_CTL') return 'VAT';
    if (mode == 'US_SALES_TAX' || mode == 'SALES_TAX') return 'Sales Tax';
    if (mode == 'CGST_SGST' || mode == 'IGST') return 'GST';

    final c = (country ?? '').trim().toLowerCase();
    if (c == 'usa' || c == 'united states') return 'Sales Tax';
    if (c == 'kenya' || c == 'uk' || c == 'united kingdom' || c == 'uae') return 'VAT';
    if (c == 'india' || isIndiaCountry(country)) return 'GST';

    if (CurrencyService.symbol == '\$') return 'Tax';
    if (CurrencyService.code == 'KES' || CurrencyService.symbol == '£' || CurrencyService.code == 'AED') return 'VAT';
    return 'Tax';
  }

  static String taxPercentLabel([String? country, String? taxMode]) {
    return '${taxName(country, taxMode)} %';
  }

  static String taxAmountLabel([String? country, String? taxMode]) {
    return '${taxName(country, taxMode)} Amt';
  }

  static String taxIdLabel([String? country]) {
    final c = (country ?? '').trim().toLowerCase();
    if (c == 'usa' || c == 'united states') return 'Tax ID';
    if (c == 'kenya') return 'PIN';
    if (c == 'uk' || c == 'united kingdom') return 'VAT Reg No';
    if (c == 'uae') return 'TRN';
    if (c == 'india' || isIndiaCountry(country)) return 'GSTIN';
    if (CurrencyService.symbol == '\$') return 'Tax ID';
    if (CurrencyService.code == 'KES') return 'PIN';
    if (CurrencyService.symbol == '£') return 'VAT Reg No';
    if (CurrencyService.code == 'AED') return 'TRN';
    return 'Tax ID';
  }

  static String businessRegLabel([String? country]) {
    final c = (country ?? '').trim().toLowerCase();
    if (c == 'usa' || c == 'united states') return 'State Tax ID';
    if (c == 'kenya') return 'Business Reg No';
    if (c == 'uk' || c == 'united kingdom') return 'CRN';
    if (c == 'uae') return 'Trade License';
    if (c == 'india' || isIndiaCountry(country)) return 'PAN';
    if (CurrencyService.symbol == '\$') return 'State Tax ID';
    if (CurrencyService.code == 'KES') return 'Business Reg No';
    if (CurrencyService.symbol == '£') return 'CRN';
    if (CurrencyService.code == 'AED') return 'Trade License';
    return 'State Tax ID';
  }
}
