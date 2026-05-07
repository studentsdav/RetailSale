import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EnterprisePosDemoScreen extends StatefulWidget {
  const EnterprisePosDemoScreen({super.key});

  @override
  State<EnterprisePosDemoScreen> createState() =>
      _EnterprisePosDemoScreenState();
}

class _EnterprisePosDemoScreenState extends State<EnterprisePosDemoScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _voucherController = TextEditingController();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  final List<PosCategory> _categories = const [
    PosCategory(id: 'all', label: 'All Items'),
    PosCategory(id: 'fnb', label: 'Food & Beverage'),
    PosCategory(id: 'electronics', label: 'Electronics'),
    PosCategory(id: 'grocery', label: 'Grocery'),
    PosCategory(id: 'personal-care', label: 'Personal Care'),
    PosCategory(id: 'stationery', label: 'Stationery'),
  ];

  final List<PosPromotion> _promotions = const [
    PosPromotion(
      id: 'promo-flat-5',
      title: 'Rs. 5 Off Any Item',
      subtitle: 'Quick flat discount',
      accentColor: Color(0xFFFFA347),
    ),
    PosPromotion(
      id: 'promo-coke',
      title: 'Free Coke',
      subtitle: 'Bundle add-on',
      accentColor: Color(0xFFFF8A3D),
    ),
    PosPromotion(
      id: 'promo-loyalty',
      title: 'Loyalty 10%',
      subtitle: 'Member-only scheme',
      accentColor: Color(0xFFFFB86C),
    ),
  ];

  late final List<PosProduct> _allProducts = [
    const PosProduct(
      id: 'p-1001',
      name: 'Premium Basmati Rice 5kg',
      sku: 'SKU-RICE-501',
      categoryId: 'grocery',
      price: 699,
      icon: Icons.rice_bowl_outlined,
    ),
    const PosProduct(
      id: 'p-1002',
      name: 'Cold Brew Coffee',
      sku: 'SKU-COF-102',
      categoryId: 'fnb',
      price: 180,
      icon: Icons.local_cafe_outlined,
    ),
    const PosProduct(
      id: 'p-1003',
      name: 'Wireless Headphones',
      sku: 'SKU-AUD-220',
      categoryId: 'electronics',
      price: 2499,
      icon: Icons.headphones_outlined,
    ),
    const PosProduct(
      id: 'p-1004',
      name: 'Hand Sanitizer 500ml',
      sku: 'SKU-CAR-114',
      categoryId: 'personal-care',
      price: 149,
      icon: Icons.health_and_safety_outlined,
    ),
    const PosProduct(
      id: 'p-1005',
      name: 'Notebook A5 Ruled',
      sku: 'SKU-STA-331',
      categoryId: 'stationery',
      price: 60,
      icon: Icons.menu_book_outlined,
    ),
    const PosProduct(
      id: 'p-1006',
      name: 'LED Desk Lamp',
      sku: 'SKU-ELC-089',
      categoryId: 'electronics',
      price: 1199,
      icon: Icons.lightbulb_outline,
    ),
    const PosProduct(
      id: 'p-1007',
      name: 'Orange Juice 1L',
      sku: 'SKU-FNB-701',
      categoryId: 'fnb',
      price: 110,
      icon: Icons.local_drink_outlined,
    ),
    const PosProduct(
      id: 'p-1008',
      name: 'Organic Sugar 1kg',
      sku: 'SKU-GRC-210',
      categoryId: 'grocery',
      price: 72,
      icon: Icons.shopping_bag_outlined,
    ),
  ];

  final List<PosCartLine> _cartLines = [
    const PosCartLine(
      product: PosProduct(
        id: 'p-1002',
        name: 'Cold Brew Coffee',
        sku: 'SKU-COF-102',
        categoryId: 'fnb',
        price: 180,
        icon: Icons.local_cafe_outlined,
      ),
      quantity: 2,
    ),
    const PosCartLine(
      product: PosProduct(
        id: 'p-1003',
        name: 'Wireless Headphones',
        sku: 'SKU-AUD-220',
        categoryId: 'electronics',
        price: 2499,
        icon: Icons.headphones_outlined,
      ),
      quantity: 1,
    ),
  ];

  String _selectedCategoryId = 'all';
  String _activePromoId = 'promo-flat-5';

  @override
  void dispose() {
    _searchController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  List<PosProduct> get _visibleProducts {
    final query = _searchController.text.trim().toLowerCase();
    return _allProducts.where((product) {
      final matchesCategory = _selectedCategoryId == 'all' ||
          product.categoryId == _selectedCategoryId;
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  double get _subTotal =>
      _cartLines.fold<double>(0, (sum, line) => sum + line.lineTotal);

  double get _discounts => _activePromoId.isEmpty ? 0 : 125;

  double get _taxesAndCharges => (_subTotal - _discounts) * 0.09;

  double get _grandTotal => (_subTotal - _discounts) + _taxesAndCharges;

  void _addProduct(PosProduct product) {
    final index =
        _cartLines.indexWhere((line) => line.product.id == product.id);
    setState(() {
      if (index == -1) {
        _cartLines.add(PosCartLine(product: product, quantity: 1));
      } else {
        _cartLines[index] = _cartLines[index]
            .copyWith(quantity: _cartLines[index].quantity + 1);
      }
    });
  }

  void _changeQuantity(PosCartLine line, int delta) {
    final index =
        _cartLines.indexWhere((entry) => entry.product.id == line.product.id);
    if (index == -1) return;

    final nextQuantity = _cartLines[index].quantity + delta;
    setState(() {
      if (nextQuantity <= 0) {
        _cartLines.removeAt(index);
      } else {
        _cartLines[index] = _cartLines[index].copyWith(quantity: nextQuantity);
      }
    });
  }

  void _removeLine(PosCartLine line) {
    setState(() {
      _cartLines.removeWhere((entry) => entry.product.id == line.product.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF7A1A),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F5F7),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xFF1E293B),
            displayColor: const Color(0xFF1E293B),
          ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        margin: EdgeInsets.zero,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF7A1A), width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidebarWidth =
                    constraints.maxWidth.clamp(960.0, 1800.0) * 0.08;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: sidebarWidth.clamp(78.0, 104.0),
                      child: _PosSidebar(
                        onSignOut: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 7,
                      child: _CatalogPane(
                        storeName: 'Famalth Retail Hub',
                        locationId: 'LOC-ID: IN-BLR-04',
                        searchController: _searchController,
                        categories: _categories,
                        selectedCategoryId: _selectedCategoryId,
                        products: _visibleProducts,
                        promotions: _promotions,
                        activePromotionId: _activePromoId,
                        cashierName: 'Priya Nair',
                        cashierRole: 'Cashier / Floor Manager',
                        currency: _currency,
                        onSearchChanged: (_) => setState(() {}),
                        onSearchSubmitted: (_) => setState(() {}),
                        onScanTap: () {},
                        onCategorySelected: (categoryId) {
                          setState(() => _selectedCategoryId = categoryId);
                        },
                        onProductTap: _addProduct,
                        onPromotionTap: (promoId) {
                          setState(() => _activePromoId = promoId);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _CartPane(
                        orderNumber: '#58241',
                        cartLines: _cartLines,
                        voucherController: _voucherController,
                        currency: _currency,
                        subTotal: _subTotal,
                        discounts: _discounts,
                        taxesAndCharges: _taxesAndCharges,
                        total: _grandTotal,
                        onClearOrder: () {
                          setState(() => _cartLines.clear());
                        },
                        onDecreaseQty: (line) => _changeQuantity(line, -1),
                        onIncreaseQty: (line) => _changeQuantity(line, 1),
                        onRemoveLine: _removeLine,
                        onVoucherChanged: (_) {},
                        onPayNow: () {},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class EnterprisePosRetailShell extends StatelessWidget {
  EnterprisePosRetailShell({
    super.key,
    required this.storeName,
    required this.locationId,
    required this.orderNumber,
    required this.cashierName,
    required this.cashierRole,
    required this.categories,
    required this.selectedCategoryId,
    required this.products,
    required this.cartLines,
    required this.promotions,
    required this.activePromotionId,
    required this.searchController,
    required this.voucherController,
    required this.subTotal,
    required this.discounts,
    required this.taxesAndCharges,
    required this.total,
    required this.onCategorySelected,
    required this.onProductTap,
    required this.onPromotionTap,
    required this.onDecreaseQty,
    required this.onIncreaseQty,
    required this.onRemoveLine,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onVoucherChanged,
    required this.onScanTap,
    required this.onClearOrder,
    required this.onPayNow,
    this.onSignOut,
    NumberFormat? currency,
  }) : currency = currency ??
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: 'Rs. ',
              decimalDigits: 2,
            );

  final String storeName;
  final String locationId;
  final String orderNumber;
  final String cashierName;
  final String cashierRole;
  final List<PosCategory> categories;
  final String selectedCategoryId;
  final List<PosProduct> products;
  final List<PosCartLine> cartLines;
  final List<PosPromotion> promotions;
  final String activePromotionId;
  final TextEditingController searchController;
  final TextEditingController voucherController;
  final NumberFormat currency;
  final double subTotal;
  final double discounts;
  final double taxesAndCharges;
  final double total;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<PosProduct> onProductTap;
  final ValueChanged<String> onPromotionTap;
  final ValueChanged<PosCartLine> onDecreaseQty;
  final ValueChanged<PosCartLine> onIncreaseQty;
  final ValueChanged<PosCartLine> onRemoveLine;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<String> onVoucherChanged;
  final VoidCallback onScanTap;
  final VoidCallback onClearOrder;
  final VoidCallback onPayNow;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 90,
          child: _PosSidebar(onSignOut: onSignOut),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 7,
          child: _CatalogPane(
            storeName: storeName,
            locationId: locationId,
            searchController: searchController,
            categories: categories,
            selectedCategoryId: selectedCategoryId,
            products: products,
            promotions: promotions,
            activePromotionId: activePromotionId,
            cashierName: cashierName,
            cashierRole: cashierRole,
            currency: currency,
            onSearchChanged: onSearchChanged,
            onSearchSubmitted: onSearchSubmitted,
            onCategorySelected: onCategorySelected,
            onProductTap: onProductTap,
            onPromotionTap: onPromotionTap,
            onScanTap: onScanTap,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: _CartPane(
            orderNumber: orderNumber,
            cartLines: cartLines,
            voucherController: voucherController,
            currency: currency,
            subTotal: subTotal,
            discounts: discounts,
            taxesAndCharges: taxesAndCharges,
            total: total,
            onClearOrder: onClearOrder,
            onDecreaseQty: onDecreaseQty,
            onIncreaseQty: onIncreaseQty,
            onRemoveLine: onRemoveLine,
            onVoucherChanged: onVoucherChanged,
            onPayNow: onPayNow,
          ),
        ),
      ],
    );
  }
}

class _PosSidebar extends StatelessWidget {
  const _PosSidebar({
    required this.onSignOut,
  });

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFFF7A1A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 28),
          const _SidebarIcon(icon: Icons.home_rounded, selected: true),
          const SizedBox(height: 18),
          const _SidebarIcon(icon: Icons.grid_view_rounded),
          const SizedBox(height: 18),
          const _SidebarIcon(icon: Icons.point_of_sale_rounded),
          const SizedBox(height: 18),
          const _SidebarIcon(icon: Icons.settings_outlined),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: onSignOut,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFF0E3),
              foregroundColor: const Color(0xFFED5F00),
              fixedSize: const Size(52, 52),
            ),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  const _SidebarIcon({
    required this.icon,
    this.selected = false,
  });

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF0E3) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: IconButton(
        onPressed: () {},
        style: IconButton.styleFrom(
          fixedSize: const Size(52, 52),
          foregroundColor:
              selected ? const Color(0xFFFF7A1A) : const Color(0xFF64748B),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _CatalogPane extends StatelessWidget {
  const _CatalogPane({
    required this.storeName,
    required this.locationId,
    required this.searchController,
    required this.categories,
    required this.selectedCategoryId,
    required this.products,
    required this.promotions,
    required this.activePromotionId,
    required this.cashierName,
    required this.cashierRole,
    required this.currency,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onCategorySelected,
    required this.onProductTap,
    required this.onPromotionTap,
    required this.onScanTap,
  });

  final String storeName;
  final String locationId;
  final TextEditingController searchController;
  final List<PosCategory> categories;
  final String selectedCategoryId;
  final List<PosProduct> products;
  final List<PosPromotion> promotions;
  final String activePromotionId;
  final String cashierName;
  final String cashierRole;
  final NumberFormat currency;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<PosProduct> onProductTap;
  final ValueChanged<String> onPromotionTap;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CatalogHeader(
              storeName: storeName,
              locationId: locationId,
              searchController: searchController,
              onSearchChanged: onSearchChanged,
              onSearchSubmitted: onSearchSubmitted,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected = category.id == selectedCategoryId;
                  return FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(category.label),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF475569),
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFFF7A1A),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    onSelected: (_) => onCategorySelected(category.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1100
                      ? 4
                      : constraints.maxWidth > 760
                          ? 3
                          : 2;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.88,
                    ),
                    itemCount: products.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ScanActionCard(onTap: onScanTap);
                      }

                      final product = products[index - 1];
                      return _ProductCard(
                        product: product,
                        currency: currency,
                        onTap: () => onProductTap(product),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _PromoSchemeBar(
              cashierName: cashierName,
              cashierRole: cashierRole,
              promotions: promotions,
              activePromotionId: activePromotionId,
              onPromotionTap: onPromotionTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.storeName,
    required this.locationId,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String storeName;
  final String locationId;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeName,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  locationId,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search for items...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFFFF7A1A),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanActionCard extends StatelessWidget {
  const _ScanActionCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8A3D), Color(0xFFFF6A00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A1A).withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Scan Item Barcode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready for hardware scanner input or manual barcode search.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.currency,
    required this.onTap,
  });

  final PosProduct product;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F2EC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        product.icon,
                        size: 54,
                        color: const Color(0xFFFF7A1A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.sku,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currency.format(product.price),
                  style: const TextStyle(
                    color: Color(0xFFFF7A1A),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoSchemeBar extends StatelessWidget {
  const _PromoSchemeBar({
    required this.cashierName,
    required this.cashierRole,
    required this.promotions,
    required this.activePromotionId,
    required this.onPromotionTap,
  });

  final String cashierName;
  final String cashierRole;
  final List<PosPromotion> promotions;
  final String activePromotionId;
  final ValueChanged<String> onPromotionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0E3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Color(0xFFFF7A1A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cashierName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cashierRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: promotions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final promo = promotions[index];
                final selected = promo.id == activePromotionId;
                return SizedBox(
                  width: 180,
                  child: Material(
                    color:
                        selected ? promo.accentColor : const Color(0xFFFFF7EF),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => onPromotionTap(promo.id),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              promo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFB45309),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              promo.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white.withOpacity(0.88)
                                    : const Color(0xFF7C5A39),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _CartPane extends StatelessWidget {
  const _CartPane({
    required this.orderNumber,
    required this.cartLines,
    required this.voucherController,
    required this.currency,
    required this.subTotal,
    required this.discounts,
    required this.taxesAndCharges,
    required this.total,
    required this.onClearOrder,
    required this.onDecreaseQty,
    required this.onIncreaseQty,
    required this.onRemoveLine,
    required this.onVoucherChanged,
    required this.onPayNow,
  });

  final String orderNumber;
  final List<PosCartLine> cartLines;
  final TextEditingController voucherController;
  final NumberFormat currency;
  final double subTotal;
  final double discounts;
  final double taxesAndCharges;
  final double total;
  final VoidCallback onClearOrder;
  final ValueChanged<PosCartLine> onDecreaseQty;
  final ValueChanged<PosCartLine> onIncreaseQty;
  final ValueChanged<PosCartLine> onRemoveLine;
  final ValueChanged<String> onVoucherChanged;
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEF1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Order',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order Number: $orderNumber',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onClearOrder,
                  child: const Text('Clear Order'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: cartLines.isEmpty
                    ? const _EmptyCartState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: cartLines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final line = cartLines[index];
                          return Dismissible(
                            key: ValueKey(line.product.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) => onRemoveLine(line),
                            child: _CartItemTile(
                              line: line,
                              currency: currency,
                              onDecrease: () => onDecreaseQty(line),
                              onIncrease: () => onIncreaseQty(line),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: voucherController,
              onChanged: onVoucherChanged,
              decoration: const InputDecoration(
                hintText: 'Voucher Code / Scheme Code',
                prefixIcon: Icon(Icons.loyalty_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                      label: 'Sub Total', value: currency.format(subTotal)),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Discounts',
                    value: '- ${currency.format(discounts)}',
                    valueColor: const Color(0xFFB42318),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Tax & Additional Charges',
                    value: currency.format(taxesAndCharges),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1),
                  ),
                  _SummaryRow(
                    label: 'Total',
                    value: currency.format(total),
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onPayNow,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A1A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(68),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.line,
    required this.currency,
    required this.onDecrease,
    required this.onIncrease,
  });

  final PosCartLine line;
  final NumberFormat currency;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(line.product.icon, color: const Color(0xFFFF7A1A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currency.format(line.lineTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF7A1A),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 40,
                  width: 122,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: IconButton(
                          onPressed: onDecrease,
                          icon: const Icon(Icons.remove_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Text(
                        '${line.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Expanded(
                        child: IconButton(
                          onPressed: onIncrease,
                          icon: const Icon(Icons.add_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_checkout_rounded,
                color: Color(0xFFFF7A1A),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No items in cart yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap a product card or scan an item barcode to start a new order.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: emphasized ? 18 : 14,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      color: emphasized ? const Color(0xFF0F172A) : const Color(0xFF475569),
    );
    final valueStyle = TextStyle(
      fontSize: emphasized ? 22 : 15,
      fontWeight: FontWeight.w800,
      color: valueColor ?? const Color(0xFF0F172A),
    );

    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class PosCategory {
  const PosCategory({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class PosPromotion {
  const PosPromotion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color accentColor;
}

class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryId,
    required this.price,
    required this.icon,
  });

  final String id;
  final String name;
  final String sku;
  final String categoryId;
  final double price;
  final IconData icon;
}

class PosCartLine {
  const PosCartLine({
    required this.product,
    required this.quantity,
  });

  final PosProduct product;
  final int quantity;

  double get lineTotal => quantity * product.price;

  PosCartLine copyWith({
    PosProduct? product,
    int? quantity,
  }) {
    return PosCartLine(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
