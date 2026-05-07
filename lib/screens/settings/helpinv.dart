import 'package:flutter/material.dart';
import '../../core/config/app_brand.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Quick Guides', [
            _helpTile(
              Icons.inventory,
              'Stock In (Receiving)',
              'How to receive items from supplier',
            ),
            _helpTile(
              Icons.upload,
              'Stock Out',
              'How to move items from store to department',
            ),
            _helpTile(
              Icons.undo,
              'Department Return',
              'How to return items from department to store',
            ),
            _helpTile(
              Icons.warning,
              'Damage Entry',
              'How to record damaged items',
            ),
          ]),
          _section('Reports', [
            _helpTile(
              Icons.receipt_long,
              'Stock Movement Reports',
              'View and filter transaction reports',
            ),
            _helpTile(
              Icons.inventory_2,
              'Stock Balance',
              'Understand current stock and reorder alerts',
            ),
            _helpTile(
              Icons.fact_check,
              'Closing Stock',
              'End of day/month stock summary',
            ),
          ]),
          _section('Troubleshooting', [
            _helpTile(
              Icons.error_outline,
              'Why stock mismatch happens?',
              'Common reasons for mismatch and solution',
            ),
            _helpTile(
              Icons.lock,
              'Permission denied',
              'Why some actions are restricted',
            ),
          ]),
          _section('Contact Support', [
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('Support Phone'),
              subtitle: Text(AppBrand.supportPhone),
            ),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Support Email'),
              subtitle: Text(AppBrand.supportEmail),
            ),
            ListTile(
              leading: Icon(Icons.web),
              title: Text('Knowledge Base'),
              subtitle: Text(AppBrand.supportWebsite),
            ),
          ]),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Text('${AppBrand.companyName} - ${AppBrand.productName}',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 6),
                Text('Version 2.2.574'),
                SizedBox(height: 2),
                Text('Build Date: 2025-12-04'),
                SizedBox(height: 8),
                Text(AppBrand.companyName,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    AppBrand.openSourceNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- HELPERS ----------------
  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _helpTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

