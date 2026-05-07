import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppDateField extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final double width;

  const AppDateField({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.label = "Date",
    this.firstDate,
    this.lastDate,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(
      text: DateFormat('dd-MMM-yyyy').format(selectedDate),
    );

    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: firstDate ?? DateTime(2020),
            lastDate: lastDate ?? DateTime(2100),
          );

          if (picked != null) {
            onDateSelected(picked);
          }
        },
      ),
    );
  }
}
