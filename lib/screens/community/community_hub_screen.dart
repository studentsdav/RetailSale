import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/community/community_controller.dart';
import '../../controllers/inventory/marketplace_controller.dart';
import '../../models/community/community_models.dart';
import 'chat_conversation_screen.dart';

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommunityController>().setScreenActive(true);
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<CommunityController>().setScreenActive(false);
    } catch (_) {}
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Modal to Create a New Business Community / Channel (Max 5 per outlet)
  void _openCreateCommunityModal(BuildContext context) {
    final ctrl = context.read<CommunityController>();

    if (ctrl.myCreatedCommunitiesCount >= 5) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Limit Reached', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'You have created ${ctrl.myCreatedCommunitiesCount}/5 community channels. Each outlet is limited to a maximum of 5 channels to keep the platform organized.\n\nYou can continue to discover and join existing public channels!',
            style: const TextStyle(fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _openDiscoverCommunitiesModal(context);
              },
              child: const Text('Discover Communities'),
            ),
          ],
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: ctrl.currentCity);
    final stateCtrl = TextEditingController(text: ctrl.currentState);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.group_add, color: Colors.purple.shade800, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Create New Business Community',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Limit: ${ctrl.myCreatedCommunitiesCount}/5 channels used • Local city: ${ctrl.currentCity}',
                                style: TextStyle(fontSize: 12, color: Colors.purple.shade700, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Community / Channel Name *',
                        hintText: 'e.g. ${ctrl.currentCity} FMCG & Retail Network',
                        prefixIcon: const Icon(Icons.tag),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Topic & Trade Purpose *',
                        hintText: 'e.g. Daily wholesale rates, bulk orders, and stock clearance',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityCtrl,
                            decoration: InputDecoration(
                              labelText: 'Region / City (Property Info)',
                              prefixIcon: const Icon(Icons.location_city),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: stateCtrl,
                            decoration: InputDecoration(
                              labelText: 'State / Territory',
                              prefixIcon: const Icon(Icons.map_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          isSubmitting ? 'Creating...' : 'Create & Open Community (${5 - ctrl.myCreatedCommunitiesCount} left)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleCtrl.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a community name')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                try {
                                  final createdChannel = await ctrl.createNewCommunityChannel(
                                    title: title,
                                    description: descCtrl.text.trim(),
                                    regionCity: cityCtrl.text.trim(),
                                    regionState: stateCtrl.text.trim(),
                                  );

                                  if (modalCtx.mounted) {
                                    Navigator.pop(modalCtx);
                                  }

                                  if (createdChannel != null && context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatConversationScreen(conversation: createdChannel),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Modal to Discover and Join other Public Business Communities (e.g. Chandigarh, Delhi)
  void _openDiscoverCommunitiesModal(BuildContext context) {
    final ctrl = context.read<CommunityController>();
    final searchCtrl = TextEditingController();
    List<ChatConversation> discoveredChannels = [];
    bool isLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            void loadChannels(String query) async {
              setModalState(() => isLoading = true);
              final list = await ctrl.discoverPublicChannels(query: query);
              setModalState(() {
                // Limit discovery to max 5 results
                discoveredChannels = list.take(5).toList();
                isLoading = false;
              });
            }

            if (isLoading && discoveredChannels.isEmpty) {
              loadChannels('');
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.explore, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discover & Join Business Communities',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Search by City (e.g. New York, Chicago, Miami) or Channel Name (max 5 results)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search city (e.g. New York, Chicago, Miami) or topic...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    loadChannels('');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (q) => loadChannels(q.trim()),
                        onChanged: (q) {
                          if (q.trim().length >= 2 || q.trim().isEmpty) {
                            loadChannels(q.trim());
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : discoveredChannels.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
                                        const SizedBox(height: 10),
                                        Text(
                                          searchCtrl.text.isNotEmpty
                                              ? 'No community channels found matching "${searchCtrl.text}".'
                                              : 'No other public communities found.\nBe the first to create one!',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollCtrl,
                                    itemCount: discoveredChannels.length,
                                    itemBuilder: (_, idx) {
                                      final ch = discoveredChannels[idx];
                                      final isAlreadyJoined = ctrl.isChannelJoined(ch.id) ||
                                          ctrl.channels.any((c) => c.id == ch.id);

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.purple.shade100,
                                            child: Text(
                                              ch.title.replaceAll('#', '').trim().isNotEmpty
                                                  ? ch.title.replaceAll('#', '').trim()[0].toUpperCase()
                                                  : '#',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple.shade900,
                                              ),
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(ch.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '📍 ${ch.regionCity}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              ch.description.isNotEmpty ? ch.description : 'Open regional trade group',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          trailing: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isAlreadyJoined ? Colors.grey.shade200 : Colors.purple.shade700,
                                              foregroundColor: isAlreadyJoined ? Colors.black87 : Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            ),
                                            onPressed: () async {
                                              await ctrl.joinCommunityChannel(ch);
                                              if (modalCtx.mounted) Navigator.pop(modalCtx);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Joined ${ch.title}! Saved to your Regional Channels.'),
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ChatConversationScreen(conversation: ch),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text(isAlreadyJoined ? 'Open' : 'Join & Open'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openNewDirectChatModal(BuildContext context) {
    final marketplaceCtrl = context.read<MarketplaceController>();
    final communityCtrl = context.read<CommunityController>();

    String activeCity = communityCtrl.currentCity;
    bool isOtherCity = false;
    final cityInputCtrl = TextEditingController();

    communityCtrl.fetchPlatformOutlets(city: activeCity);

    final searchModalCtrl = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final cleanQ = searchQuery.toLowerCase().trim();
            final isSearchMode = cleanQ.isNotEmpty;

            // Filter Platform Outlets (Real registered outlets from database)
            final filteredOutlets = communityCtrl.platformOutlets.where((o) {
              final idStr = (o['id'] ?? o['outlet_id'] ?? '').toString();
              if (idStr == communityCtrl.currentMerchantId) return false;

              if (isSearchMode) {
                final bName = (o['business_name'] ?? o['outlet_name'] ?? '').toString().toLowerCase();
                final gstin = (o['gstin'] ?? '').toString().toLowerCase();
                final phone = (o['phone'] ?? '').toString().toLowerCase();
                final code = (o['outlet_code'] ?? '').toString().toLowerCase();
                final city = (o['city'] ?? '').toString().toLowerCase();

                return bName.contains(cleanQ) ||
                    gstin.contains(cleanQ) ||
                    phone.contains(cleanQ) ||
                    code.contains(cleanQ) ||
                    city.contains(cleanQ);
              }

              return true;
            }).toList();

            // Filter Marketplace Vendors (Registered accounts)
            final filteredVendors = marketplaceCtrl.vendors.where((v) {
              if (isSearchMode) {
                return v.businessName.toLowerCase().contains(cleanQ) ||
                    v.tradeName.toLowerCase().contains(cleanQ) ||
                    v.gstin.toLowerCase().contains(cleanQ) ||
                    v.phone.toLowerCase().contains(cleanQ) ||
                    v.city.toLowerCase().contains(cleanQ);
              }
              final vCity = v.city.trim().toLowerCase();
              final target = activeCity.trim().toLowerCase();
              return vCity.isEmpty || vCity.contains(target) || target.contains(vCity);
            }).toList();

            final displayOutlets = isSearchMode ? filteredOutlets.take(5).toList() : filteredOutlets;
            final displayVendors = isSearchMode ? filteredVendors.take(5).toList() : filteredVendors;
            final totalResults = displayOutlets.length + displayVendors.length;

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.mark_chat_read_outlined, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Discover & Message Registered Outlets',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  isSearchMode
                                      ? 'Searching by Tax ID / Name (Max 5 results)'
                                      : 'Outlets in $activeCity (Select "Other City" or search by Tax ID)',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Search Input Bar (Case 3: Search by Tax ID or Name or Code - 5 results limit)
                      TextField(
                        controller: searchModalCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search by Tax ID, Outlet Name, or Code (max 5)...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchModalCtrl.clear();
                                    setModalState(() => searchQuery = '');
                                    communityCtrl.fetchPlatformOutlets(city: activeCity);
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                          if (val.trim().length >= 2) {
                            communityCtrl.fetchPlatformOutlets(query: val.trim());
                          } else if (val.trim().isEmpty) {
                            communityCtrl.fetchPlatformOutlets(city: activeCity);
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // City Selector Bar (Case 1: Own City, Case 2: Other City)
                      if (!isSearchMode)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Selected / Active City Chip
                              ChoiceChip(
                                avatar: const Icon(Icons.location_on, size: 15),
                                label: Text('📍 $activeCity ${isOtherCity ? "(Selected)" : "(My City)"}'),
                                selected: true,
                                selectedColor: Colors.blue.shade100,
                                onSelected: (_) {},
                              ),
                              const SizedBox(width: 8),

                              // Button to enter / select Other City
                              ActionChip(
                                avatar: const Icon(Icons.edit_location_alt, size: 15, color: Colors.purple),
                                label: const Text('📍 Other City / Change', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.purple.shade50,
                                onPressed: () {
                                  cityInputCtrl.text = isOtherCity ? activeCity : '';
                                  showDialog(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(Icons.location_city, color: Colors.purple),
                                          SizedBox(width: 8),
                                          Text('Enter City Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Enter the city name (e.g. New York, Chicago, Los Angeles, Miami) to see registered outlets in that city:',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: cityInputCtrl,
                                            autofocus: true,
                                            decoration: InputDecoration(
                                              hintText: 'e.g. Chicago, Miami, or Los Angeles',
                                              prefixIcon: const Icon(Icons.location_on),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogCtx),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800, foregroundColor: Colors.white),
                                          onPressed: () {
                                            final enteredCity = cityInputCtrl.text.trim();
                                            if (enteredCity.isNotEmpty) {
                                              setModalState(() {
                                                activeCity = enteredCity;
                                                isOtherCity = (enteredCity.toLowerCase() != communityCtrl.currentCity.toLowerCase());
                                              });
                                              communityCtrl.fetchPlatformOutlets(city: enteredCity);
                                            }
                                            Navigator.pop(dialogCtx);
                                          },
                                          child: const Text('Show Outlets'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              if (isOtherCity) ...[
                                const SizedBox(width: 8),
                                ActionChip(
                                  avatar: const Icon(Icons.replay, size: 14, color: Colors.grey),
                                  label: Text('Reset to ${communityCtrl.currentCity}', style: const TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    setModalState(() {
                                      activeCity = communityCtrl.currentCity;
                                      isOtherCity = false;
                                    });
                                    communityCtrl.fetchPlatformOutlets(city: communityCtrl.currentCity);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),

                      // Merchant List
                      Expanded(
                        child: totalResults == 0
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_search, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 10),
                                    Text(
                                      isSearchMode
                                          ? 'No registered outlets found matching "$searchQuery"'
                                          : 'No other registered outlets found in $activeCity.\nTap "Other City" or search by Tax ID/Name.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                controller: scrollCtrl,
                                children: [
                                  // 1. Registered Platform Outlets (Database Outlets)
                                  if (displayOutlets.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text(
                                        isSearchMode
                                            ? 'SEARCH RESULTS (TOP ${displayOutlets.length})'
                                            : 'REGISTERED PLATFORM OUTLETS IN ${activeCity.toUpperCase()} (${displayOutlets.length})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    ...displayOutlets.map((o) {
                                      final idStr = (o['id'] ?? o['outlet_id'] ?? '').toString();
                                      final bName = (o['business_name'] ?? o['outlet_name'] ?? 'Outlet $idStr').toString();
                                      final gstin = (o['gstin'] ?? '').toString();
                                      final phone = (o['phone'] ?? '').toString();
                                      final location = (o['city'] ?? o['state'] ?? o['address'] ?? '').toString();

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.teal.shade100,
                                            child: Text(
                                              bName.isNotEmpty ? bName[0].toUpperCase() : 'O',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade900,
                                              ),
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  bName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Registered Outlet',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (gstin.isNotEmpty)
                                                  Row(
                                                    children: [
                                                      Icon(Icons.verified, size: 13, color: Colors.green.shade700),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Tax ID: $gstin',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.grey.shade800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  location.isNotEmpty && phone.isNotEmpty
                                                      ? '$location • $phone'
                                                      : (location.isNotEmpty ? location : phone),
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            final directChat = communityCtrl.getOrCreateDirectChat(
                                              recipientId: idStr,
                                              recipientName: bName,
                                              recipientGstin: gstin,
                                              recipientPhone: phone,
                                              recipientCity: location,
                                            );
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatConversationScreen(conversation: directChat),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ],

                                  // 2. Marketplace Registered Merchants
                                  if (displayVendors.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text(
                                        'MARKETPLACE MERCHANTS (${displayVendors.length})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent.shade700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    ...displayVendors.map((v) {
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.blue.shade100,
                                            child: Text(
                                              v.businessName.isNotEmpty ? v.businessName[0].toUpperCase() : 'V',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  v.businessName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Marketplace',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (v.gstin.isNotEmpty)
                                                  Row(
                                                    children: [
                                                      Icon(Icons.verified, size: 13, color: Colors.green.shade700),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Tax ID: ${v.gstin}',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.grey.shade800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${v.city} • ${v.phone}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            final directChat = communityCtrl.getOrCreateDirectChat(
                                              recipientId: v.id,
                                              recipientName: v.businessName,
                                              recipientGstin: v.gstin,
                                              recipientPhone: v.phone,
                                              recipientCity: v.city,
                                            );
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatConversationScreen(conversation: directChat),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CommunityController>();

    final myCity = ctrl.currentCity.trim().toLowerCase();
    final myMerchantId = ctrl.currentMerchantId.trim().toLowerCase();
    final myMerchantName = ctrl.currentMerchantName.trim().toLowerCase();

    final filteredChannels = ctrl.channels.where((c) {
      final matchesCity = c.regionCity.trim().toLowerCase().contains(myCity) ||
          myCity.contains(c.regionCity.trim().toLowerCase());
      final isJoined = ctrl.isChannelJoined(c.id);
      final isCreatedByMe = (c.creatorMerchantId != null && c.creatorMerchantId!.trim().toLowerCase() == myMerchantId) ||
          (c.creatorMerchantName != null && c.creatorMerchantName!.trim().toLowerCase() == myMerchantName);

      // Show local city channels, channels joined by user, and channels created by user
      if (!matchesCity && !isJoined && !isCreatedByMe) return false;

      if (_searchQuery.isEmpty) return true;
      return c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.regionCity.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredDirectChats = ctrl.directChats.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.directRecipientGstin ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Community & Messaging'),
        actions: [
          // Master Messaging ON/OFF Toggle in AppBar
          Row(
            children: [
              Text(
                ctrl.isMessagingEnabled ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ctrl.isMessagingEnabled ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              Switch(
                value: ctrl.isMessagingEnabled,
                activeThumbColor: Colors.green,
                onChanged: (val) async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ctrl.setMessagingEnabled(val);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'B2B Messaging & Notifications Enabled'
                            : 'B2B Messaging turned OFF. Sync requests paused.',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            tooltip: 'Discover Communities',
            onPressed: () => _openDiscoverCommunitiesModal(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.purple.shade900,
                backgroundColor: Colors.purple.shade50,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => _openCreateCommunityModal(context),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.forum_outlined, size: 20),
              text: 'Regional Channels (${ctrl.channels.length})',
            ),
            Tab(
              icon: const Icon(Icons.mark_chat_unread_outlined, size: 20),
              text: 'Direct Chats (${ctrl.directChats.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messaging OFF Warning Banner
          if (!ctrl.isMessagingEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Icon(Icons.power_settings_new, color: Colors.red.shade800, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'B2B Messaging is Turned OFF',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                        Text(
                          'Background requests and sync are halted. Turn ON to send & receive messages.',
                          style: TextStyle(fontSize: 11.5, color: Colors.red.shade800),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => ctrl.setMessagingEnabled(true),
                    child: const Text('Turn ON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Current Merchant Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.business, color: Colors.blueAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected as: ${ctrl.currentMerchantName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        'Region: ${ctrl.currentCity} • Tax ID: ${ctrl.currentProperty?.gstNo.isNotEmpty == true ? ctrl.currentProperty!.gstNo : "Registered"}',
                        style: TextStyle(fontSize: 11.5, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Live @Mention Alert Notification Banner
          if (ctrl.unreadMentionsCount > 0 && ctrl.latestMention != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade400, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alternate_email, color: Colors.amber, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ctrl.latestMention!.senderName} mentioned you',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        Text(
                          ctrl.latestMention!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: Colors.brown.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(40, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => ctrl.clearMentions(),
                    child: const Text('Dismiss', style: TextStyle(fontSize: 11, color: Colors.brown)),
                  ),
                ],
              ),
            ),
          ],

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search channels or direct conversations...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Regional Channels
                filteredChannels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No regional channels found in ${ctrl.currentCity}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Community'),
                              onPressed: () => _openCreateCommunityModal(context),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredChannels.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final conv = filteredChannels[i];
                          return _buildConversationTile(ctx, conv);
                        },
                      ),

                // 2. Direct Private Chats
                filteredDirectChats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No private direct conversations yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Start 1-on-1 Chat'),
                              onPressed: () => _openNewDirectChatModal(context),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredDirectChats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final conv = filteredDirectChats[i];
                          return _buildConversationTile(ctx, conv);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ctrl.isMessagingEnabled
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Direct Chat'),
              onPressed: () => _openNewDirectChatModal(context),
            )
          : null,
    );
  }

  Widget _buildConversationTile(BuildContext context, ChatConversation conv) {
    final ctrl = context.watch<CommunityController>();
    final displayTitle = conv.getDisplayTitle(ctrl.currentMerchantId, ctrl.currentMerchantName);
    final lastMsg = conv.lastMessage;
    final timeStr = lastMsg != null
        ? DateFormat('hh:mm a').format(lastMsg.createdAt.toLocal())
        : DateFormat('hh:mm a').format(conv.updatedAt.toLocal());

    final isMeLastMsg = lastMsg != null && (
        lastMsg.senderId.trim().toLowerCase() == ctrl.currentMerchantId.trim().toLowerCase() ||
        (ctrl.currentMerchantName.trim().isNotEmpty && lastMsg.senderName.trim().toLowerCase() == ctrl.currentMerchantName.trim().toLowerCase())
    );

    final subtitleText = lastMsg != null
        ? (isMeLastMsg ? 'You: ${lastMsg.content}' : '${lastMsg.senderName}: ${lastMsg.content}')
        : (conv.isDirect ? 'Private 1-on-1 business chat' : conv.description);

    final unread = ctrl.getUnreadCount(conv.id);
    final isMuted = ctrl.isMuted(conv.id);

    // Blocked counterpart check
    final counterpartId = conv.isDirect
        ? (conv.creatorMerchantId == ctrl.currentMerchantId ? conv.directRecipientId : conv.creatorMerchantId)
        : null;
    final isCounterpartBlocked = counterpartId != null && ctrl.isBlocked(counterpartId);

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: conv.isDirect ? Colors.blue.shade100 : Colors.purple.shade100,
        child: Text(
          displayTitle.replaceAll(RegExp(r'^#\s*'), '').trim().isNotEmpty
              ? displayTitle.replaceAll(RegExp(r'^#\s*'), '').trim()[0].toUpperCase()
              : (conv.isDirect ? 'D' : '#'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: conv.isDirect ? Colors.blue.shade900 : Colors.purple.shade900,
          ),
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!conv.isDirect && conv.regionCity.isNotEmpty && !conv.regionCity.toLowerCase().contains(ctrl.currentCity.toLowerCase())) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '📍 ${conv.regionCity}',
                      style: TextStyle(fontSize: 9.5, color: Colors.purple.shade800, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                if (isMuted) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.volume_off_rounded, size: 14, color: Colors.grey),
                ],
                if (isCounterpartBlocked) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Blocked',
                      style: TextStyle(fontSize: 9.5, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 11,
              color: unread > 0 ? Colors.blueAccent : Colors.grey.shade500,
              fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              subtitleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: unread > 0 ? Colors.black87 : Colors.grey.shade600,
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(conversation: conv),
          ),
        );
      },
    );
  }
}

