import '../currency/currency_service.dart';

class CountryTaxHelper {
  CountryTaxHelper._();

  static String normalizeCountryCode(String? country) {
    if (country == null || country.trim().isEmpty) {
      if (CurrencyService.code == 'INR' || CurrencyService.symbol == '₹') return 'IN';
      if (CurrencyService.code == 'KES' || CurrencyService.symbol == 'KSh') return 'KE';
      if (CurrencyService.code == 'GBP' || CurrencyService.symbol == '£') return 'GB';
      if (CurrencyService.code == 'AED') return 'AE';
      if (CurrencyService.code == 'CAD') return 'CA';
      if (CurrencyService.code == 'AUD') return 'AU';
      if (CurrencyService.code == 'EUR' || CurrencyService.symbol == '€') return 'EU';
      return 'US'; // Global default when USD or other international currencies
    }
    final c = country.trim().toUpperCase();
    if (c == 'US' || c == 'USA' || c == 'UNITED STATES' || c == 'UNITED STATES OF AMERICA') return 'US';
    if (c == 'IN' || c == 'IND' || c == 'INDIA') return 'IN';
    if (c == 'KE' || c == 'KEN' || c == 'KENYA') return 'KE';
    if (c == 'GB' || c == 'UK' || c == 'UNITED KINGDOM' || c == 'GREAT BRITAIN') return 'GB';
    if (c == 'AE' || c == 'UAE' || c == 'UNITED ARAB EMIRATES') return 'AE';
    if (c == 'CA' || c == 'CAN' || c == 'CANADA') return 'CA';
    if (c == 'AU' || c == 'AUS' || c == 'AUSTRALIA') return 'AU';
    if (c == 'TZ' || c == 'TZA' || c == 'TANZANIA') return 'TZ';
    if (c == 'UG' || c == 'UGA' || c == 'UGANDA') return 'UG';
    if (c == 'RW' || c == 'RWA' || c == 'RWANDA') return 'RW';
    if (c == 'ZA' || c == 'ZAF' || c == 'SOUTH AFRICA') return 'ZA';
    if (c == 'NG' || c == 'NGA' || c == 'NIGERIA') return 'NG';
    if (c.length == 2) return c;
    return c;
  }

  static String getDefaultCountryCode([String? country]) {
    return normalizeCountryCode(country);
  }

  static bool isIndiaCountry(String? country) {
    final normalized = normalizeCountryCode(country);
    return normalized == 'IN';
  }

  static String taxName([String? country, String? taxMode]) {
    final mode = (taxMode ?? '').trim().toUpperCase();
    if (isIndiaCountry(country)) {
      if (mode == 'IGST') return 'IGST';
      return 'GST';
    }
    if (mode == 'VAT' || mode == 'VAT_ONLY' || mode == 'VAT_CTL') return 'Sales Tax';
    return 'Sales Tax';
  }

  static String taxPercentLabel([String? country, String? taxMode]) {
    return '${taxName(country, taxMode)} %';
  }

  static String taxAmountLabel([String? country, String? taxMode]) {
    return '${taxName(country, taxMode)} Amt';
  }

  static String taxIdLabel([String? country]) {
    final norm = normalizeCountryCode(country);
    if (norm == 'US') return 'Tax ID';
    if (norm == 'KE') return 'PIN';
    if (norm == 'GB') return 'VAT Reg No';
    if (norm == 'AE') return 'TRN';
    if (norm == 'IN') return 'GSTIN';
    return 'Tax ID';
  }

  static String businessRegLabel([String? country]) {
    final norm = normalizeCountryCode(country);
    if (norm == 'US') return 'State Tax ID';
    if (norm == 'KE') return 'Business Reg No';
    if (norm == 'GB') return 'CRN';
    if (norm == 'AE') return 'Trade License';
    if (norm == 'IN') return 'PAN';
    return 'State Tax ID';
  }
}
