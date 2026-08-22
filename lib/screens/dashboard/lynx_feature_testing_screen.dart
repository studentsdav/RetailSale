import 'package:flutter/material.dart';
import '../../widgets/lynx_assist_modal.dart';
import '../reports/operations_intelligence_screen.dart';
import '../settings/workflow_automation_screen.dart';
import '../settings/developer_ecosystem_screen.dart';
import '../settings/plugin_marketplace_screen.dart';
import 'autonomous_agent_screen.dart';
import '../inventory/salescreen.dart';

class LynxFeatureTestingScreen extends StatelessWidget {
  const LynxFeatureTestingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E1E2D) : const Color(0xFFF8FAFC);
    final appBarBg = isDark ? const Color(0xFF151521) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF2B2B40) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: isDark ? 0 : 1,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            const Icon(Icons.science_rounded, color: Color(0xFFE53935)),
            const SizedBox(width: 10),
            Text("FAMALTH LYNX • Feature Testing Hub", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC81E1E), Color(0xFF8B0000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC81E1E).withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("FAMALTH LYNX Innovation Hub", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                      SizedBox(height: 4),
                      Text("Test and explore all AI, Intelligence, Operations, Automation, and Ecosystem features built in Phases 1 through 6.",
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text("ALL FEATURE TESTING CARDS", style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 12),

          // Phase 1 Card
          _buildFeatureCard(
            context,
            isDark: isDark,
            bgColor: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            phase: "PHASE 1",
            title: "LYNX ASSIST (AI Voice & Text-to-SQL)",
            description: "Chat or speak with Gemini AI to convert questions into SQL database queries and fetch live metrics.",
            icon: Icons.graphic_eq_rounded,
            color: Colors.deepPurple,
            buttonText: "Launch AI Voice & Chat Assistant",
            onPressed: () => LynxAssistModal.show(context),
          ),

          // Phase 2 Card
          _buildFeatureCard(
            context,
            isDark: isDark,
            bgColor: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            phase: "PHASE 2",
            title: "LYNX GROW (POS Smart Upsell Recommendations)",
            description: "Real-time cross-sell recommendations bar inside POS Billing screen based on co-occurrence basket analysis.",
            icon: Icons.shopping_basket_rounded,
            color: const Color(0xFF059669),
            buttonText: "Open POS Billing Screen",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen()));
            },
          ),

          // Phase 3 Card
          _buildFeatureCard(
            context,
            isDark: isDark,
            bgColor: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            phase: "PHASE 3",
            title: "LYNX OPERATE (Operations Excellence)",
            description: "Sales velocity reorder watcher, 60-day batch expiry alerts, and operational health KPIs dashboard.",
            icon: Icons.speed_rounded,
            color: const Color(0xFFD97706),
            buttonText: "Open Operations Intelligence Dashboard",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsIntelligenceScreen()));
            },
          ),

          // Phase 4 Card
          _buildFeatureCard(
            context,
            isDark: isDark,
            bgColor: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            phase: "PHASE 4",
            title: "LYNX AUTOMATE (Workflow Automation Engine)",
            description: "Event-driven automation rule configurator for WhatsApp invoice receipts, low-stock PO drafts, and overdue reminders.",
            icon: Icons.bolt_rounded,
            color: const Color(0xFFB45309),
            buttonText: "Open Workflow Rules Configurator",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkflowAutomationScreen()));
            },
          ),

          // Phase 5 Card
          _buildFeatureCard(
            context,
            isDark: isDark,
            bgColor: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            phase: "PHASE 5",
            title: "LYNX AI AGENT (Autonomous Business OS)",
            description: "Proactive business anomaly detector, 1-click owner approval cards, and execution audit log history.",
            icon: Icons.psychology_rounded,
            color: const Color(0xFF0284C7),
            buttonText: "Open Autonomous AI Agent Hub",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AutonomousAgentScreen()));
            },
          ),

          // Section 6 Card
          _buildFeatureCard(
            context,
            isDark: isDark,
            bgColor: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            phase: "SECTION 6",
            title: "FAMALTH LYNX Ecosystem & Developer Hub",
            description: "Open REST API documentation gateway, developer Webhooks manager, and Open API Keys generator.",
            icon: Icons.code_rounded,
            color: const Color(0xFF2563EB),
            buttonText: "Open Developer & Webhooks Hub",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperEcosystemScreen()));
            },
          ),

          // Plugin Marketplace Card
          _buildFeatureCard(
            context,
            isDark: isDark,
            bgColor: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            phase: "PLUGINS",
            title: "Add-on Plugin Marketplace",
            description: "Browse and install third-party plugins (Tally ERP Sync, Zomato/Swiggy POS, WooCommerce, Loyalty Wheel, SMS Gateway).",
            icon: Icons.extension_rounded,
            color: const Color(0xFFC81E1E),
            buttonText: "Open Add-on Plugin Marketplace",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required bool isDark,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
    required String phase,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Card(
      color: bgColor,
      elevation: isDark ? 0 : 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    phase,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Icon(icon, color: color, size: 22),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(color: subtitleColor, fontSize: 12, height: 1.4)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC81E1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
