import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../screens/dashboard/server_config_screen.dart';
import '../screens/dashboard/cloud_migration_screen.dart';

class CloudFeatureGate extends StatefulWidget {
  final String featureName;
  final String featureDescription;
  final IconData featureIcon;
  final Widget child;
  final bool allowLocalPreview;

  const CloudFeatureGate({
    super.key,
    required this.featureName,
    required this.featureDescription,
    required this.featureIcon,
    required this.child,
    this.allowLocalPreview = true,
  });

  /// Static helper to navigate safely with cloud guard
  static void navigate(
    BuildContext context, {
    required String featureName,
    required String featureDescription,
    required IconData featureIcon,
    required Widget destination,
    bool allowLocalPreview = true,
  }) {
    if (!AppConfig.isLocalServer) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CloudFeatureGate(
            featureName: featureName,
            featureDescription: featureDescription,
            featureIcon: featureIcon,
            allowLocalPreview: allowLocalPreview,
            child: destination,
          ),
        ),
      );
    }
  }

  @override
  State<CloudFeatureGate> createState() => _CloudFeatureGateState();
}

class _CloudFeatureGateState extends State<CloudFeatureGate> {
  bool _previewingLocally = false;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isLocalServer || _previewingLocally) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.featureName),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 820),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Cloud Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_sync_rounded, color: Color(0xFF0284C7), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'ONLINE CLOUD FEATURE',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Feature Icon
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(widget.featureIcon, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 22),

                // Main Heading
                Text(
                  '${widget.featureName} is an Online Cloud Feature',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle explanation
                Text(
                  widget.featureDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Informational Callout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.15 : 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'You are currently running in Local Offline Mode (${AppConfig.baseUrl}). Cloud features require internet reachability so mobile apps, external merchants, and payment gateways can connect.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Options Grid (Self-Host or Cloud Subscription)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Option 1: Self-Hosted Cloud Server
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.dns_rounded, color: Color(0xFF0284C7), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Host on Your Own Server',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Deploy the backend to your own cloud VPS (AWS, DigitalOcean, Azure, or Hetzner). Point your app to your cloud URL.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Option 2: Managed Famalth Cloud
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Famalth Managed Cloud',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Zero-setup managed high-availability cloud cluster with SSL, multi-app routing, payment gateways, and automated backups.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ServerConfigScreen()),
                        );
                      },
                      icon: const Icon(Icons.settings_ethernet_rounded, size: 18),
                      label: const Text('Configure Cloud URL', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CloudMigrationScreen()),
                        );
                      },
                      icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                      label: const Text('1-Click Migrate Store to Cloud', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if (widget.allowLocalPreview)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() => _previewingLocally = true);
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Preview Feature in Offline Mode'),
                      ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Return to Dashboard'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
