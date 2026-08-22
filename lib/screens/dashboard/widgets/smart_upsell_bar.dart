import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';

class SmartUpsellBar extends StatefulWidget {
  final List<dynamic> cartItems;
  final Function(Map<String, dynamic> item)? onAddRecommendedItem;

  const SmartUpsellBar({
    Key? key,
    required this.cartItems,
    this.onAddRecommendedItem,
  }) : super(key: key);

  @override
  State<SmartUpsellBar> createState() => _SmartUpsellBarState();
}

class _SmartUpsellBarState extends State<SmartUpsellBar> {
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  @override
  void didUpdateWidget(covariant SmartUpsellBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cartItems.length != widget.cartItems.length) {
      _fetchRecommendations();
    }
  }

  Future<void> _fetchRecommendations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final List<String> itemIds = [];
      final List<String> itemCodes = [];

      for (final item in widget.cartItems) {
        if (item is Map) {
          if (item['id'] != null) itemIds.add(item['id'].toString());
          if (item['item_id'] != null) itemIds.add(item['item_id'].toString());
          if (item['item_code'] != null) itemCodes.add(item['item_code'].toString());
        }
      }

      final queryParams = <String, String>{};
      if (itemIds.isNotEmpty) queryParams['itemIds'] = itemIds.join(',');
      if (itemCodes.isNotEmpty) queryParams['itemCodes'] = itemCodes.join(',');

      final uri = Uri.parse(ApiEndpoints.cartRecommendations).replace(queryParameters: queryParams);
      final response = await ApiClient.get(uri.toString());

      if (response != null && response['success'] == true && response['data'] is List) {
        final List list = response['data'];
        if (mounted) {
          setState(() {
            _recommendations = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          });
        }
      }
    } catch (e) {
      // Quiet fallback
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53935)),
            ),
            SizedBox(width: 12),
            Text(
              "LYNX GROW analyzing customer cart for upsell opportunities...",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC81E1E).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFFE53935), size: 18),
              SizedBox(width: 8),
              Text(
                "LYNX GROW • Smart Upsell & Basket Recommendations",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendations.length,
              itemBuilder: (context, index) {
                final rec = _recommendations[index];
                final name = rec['item_name'] ?? 'Item';
                final rate = (rec['rate'] ?? 0).toString();
                final reason = rec['reason'] ?? 'Suggested';

                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2B40),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3F3F5F)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "₹$rate • $reason",
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          if (widget.onAddRecommendedItem != null) {
                            widget.onAddRecommendedItem!(rec);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC81E1E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.add, color: Colors.white, size: 14),
                              SizedBox(width: 2),
                              Text(
                                "Add",
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
