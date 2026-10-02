import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../utils/country_tax_helper.dart';

class StateService {
  StateService._();

  static const List<String> defaultIndianStates = [
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal'
  ];

  static const List<String> defaultUSStates = [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'District of Columbia',
    'Florida',
    'Georgia',
    'Guam',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Puerto Rico',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virgin Islands',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming'
  ];

  static final Map<String, List<String>> _cache = {};

  static Future<List<String>> fetchStates({String? countryCode}) async {
    final country = CountryTaxHelper.normalizeCountryCode(countryCode);

    try {
      final res = await ApiClient.get('/api/inventory/states?country_code=$country');
      if (res['success'] == true && res['states'] is List) {
        final List<String> list = List<String>.from(res['states']);
        _cache[country] = list;
        return list;
      }
    } catch (e) {
      debugPrint('[StateService] Error loading states for $country: $e');
    }

    // Fallback if offline or API error
    if (_cache.containsKey(country)) {
      return _cache[country]!;
    }

    if (country == 'US') {
      return List.from(defaultUSStates);
    } else if (country == 'IN') {
      return List.from(defaultIndianStates);
    }
    return [];
  }

  static Future<Map<String, dynamic>?> createCustomState({
    required String stateName,
    String? countryCode,
    String? stateCode,
  }) async {
    final country = CountryTaxHelper.normalizeCountryCode(countryCode);
    try {
      final res = await ApiClient.post('/api/inventory/states', {
        'state_name': stateName.trim(),
        'country_code': country,
        'state_code': stateCode?.trim(),
      });
      // Invalidate cache
      _cache.remove(country);
      return res;
    } catch (e) {
      debugPrint('[StateService] Error creating state $stateName: $e');
      rethrow;
    }
  }
}
