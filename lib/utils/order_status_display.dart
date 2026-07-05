import 'package:flutter/material.dart';

class OrderStatusDisplay {
  final String label;
  final Color color;
  final IconData icon;

  const OrderStatusDisplay({
    required this.label,
    required this.color,
    required this.icon,
  });

  static String _normalize(dynamic value) {
    return value?.toString().trim().toUpperCase() ?? '';
  }

  static bool _isTruthy(dynamic value) {
    if (value == true || value == 1) return true;
    final normalized = _normalize(value);
    return normalized == 'TRUE' || normalized == 'YES';
  }

  static bool _isExchangeReplacementOrder(Map<String, dynamic>? order) {
    final paymentMode = _normalize(order?['payment_mode']);
    final notes = order?['notes']?.toString().toLowerCase() ?? '';
    return paymentMode == 'EXCHANGE' ||
        notes.contains('exchange order for return');
  }

  static OrderStatusDisplay fromOrder(Map<String, dynamic>? order) {
    final status = _normalize(order?['status']);
    final returnStatus = _normalize(order?['return_status']);
    final refundStatus = _normalize(order?['refund_status']);
    final returnType = _normalize(order?['return_type']);
    final isExchangeReplacement = _isExchangeReplacementOrder(order);

    final isRefunded = refundStatus == 'REFUNDED' ||
        refundStatus == 'PARTIALLY_REFUNDED' ||
        returnStatus == 'RETURNED' ||
        returnType == 'REFUND';
    final isExchanged = returnType == 'EXCHANGE' ||
        returnStatus == 'EXCHANGED' ||
        refundStatus == 'EXCHANGED';

    if (isRefunded) {
      return const OrderStatusDisplay(
        label: 'REFUNDED',
        color: Colors.blue,
        icon: Icons.currency_rupee,
      );
    }
    if (isExchangeReplacement && status == 'DELIVERED') {
      return const OrderStatusDisplay(
        label: 'EXCHANGE DELIVERED',
        color: Colors.purple,
        icon: Icons.swap_horiz_outlined,
      );
    }
    if (isExchanged || isExchangeReplacement) {
      return const OrderStatusDisplay(
        label: 'EXCHANGE',
        color: Colors.purple,
        icon: Icons.swap_horiz_outlined,
      );
    }
    if (status == 'DELIVERED') {
      return const OrderStatusDisplay(
        label: 'DELIVERED',
        color: Colors.green,
        icon: Icons.check_circle_outline_rounded,
      );
    }
    if (status == 'CANCELLED') {
      return const OrderStatusDisplay(
        label: 'CANCELLED',
        color: Colors.red,
        icon: Icons.cancel_outlined,
      );
    }
    if (status == 'OUT_FOR_DELIVERY') {
      return const OrderStatusDisplay(
        label: 'OUT FOR DELIVERY',
        color: Colors.teal,
        icon: Icons.delivery_dining_outlined,
      );
    }
    if (status == 'ASSIGNED') {
      return const OrderStatusDisplay(
        label: 'ASSIGNED',
        color: Colors.indigo,
        icon: Icons.local_shipping_outlined,
      );
    }
    if (status == 'ACCEPTED') {
      return const OrderStatusDisplay(
        label: 'ACCEPTED',
        color: Colors.blue,
        icon: Icons.check_circle_outline_rounded,
      );
    }
    if (status == 'PENDING') {
      return const OrderStatusDisplay(
        label: 'PENDING',
        color: Colors.orange,
        icon: Icons.pending_actions_outlined,
      );
    }

    return OrderStatusDisplay(
      label: status.isNotEmpty ? status : 'PENDING',
      color: Colors.orange,
      icon: _isTruthy(order?['is_prepaid'])
          ? Icons.receipt_long_outlined
          : Icons.local_shipping_outlined,
    );
  }
}
