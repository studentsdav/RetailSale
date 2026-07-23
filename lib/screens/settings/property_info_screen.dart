import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../controllers/settings/property_info_controller.dart';
import '../../core/auth/token_storage.dart';
import '../../models/common/property_info_model.dart';
import '../../utils/branding_storage.dart';

class PropertyInfoScreen extends StatefulWidget {
  final int outletid;
  const PropertyInfoScreen({super.key, required this.outletid});

  @override
  State<PropertyInfoScreen> createState() => _PropertyInfoScreenState();
}

class _PropertyInfoScreenState extends State<PropertyInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  late final PropertyInfoController ctrl;
  final _propertyName = TextEditingController();
  final _legalName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pin = TextEditingController();
  final _contactPerson = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _gstNo = TextEditingController();
  final _panNo = TextEditingController();
  final _fssaiNo = TextEditingController();
  final _drugLicenseNo = TextEditingController();
  final _website = TextEditingController();
  final _thermalFooterNote = TextEditingController();
  String? _logoPath;

  bool _active = true;
  bool _printMobile = true;
  bool _printEmail = true;
  bool _printWebsite = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    ctrl = PropertyInfoController();
    _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    try {
      await ctrl.load();
      final d = ctrl.data;
      if (d == null) return;

      setState(() {
        _propertyName.text = d.propertyName;
        _legalName.text = d.legalName;
        _address.text = d.address;
        _city.text = d.city;
        _state.text = d.state;
        _pin.text = d.pinCode;
        _contactPerson.text = d.contactPerson;
        _mobile.text = d.mobile;
        _email.text = d.email;
        _gstNo.text = d.gstNo;
        _panNo.text = d.panNo;
        _fssaiNo.text = d.fssaiNo;
        _drugLicenseNo.text = d.drugLicenseNo;
        _website.text = d.website;
        _thermalFooterNote.text = d.thermalFooterNote;
        _logoPath = d.logoPath;
        _active = d.isActive;
        _printMobile = d.printMobile;
        _printEmail = d.printEmail;
        _printWebsite = d.printWebsite;
      });
    } catch (e) {}
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );

    final pickedPath = result?.files.single.path;
    if (pickedPath == null) return;

    final user = await TokenStorage.getUser();
    final outletCode = user?['outlet_code']?.toString() ?? '';
    if (outletCode.isEmpty) return;

    final savedPath = await BrandingStorage.saveLogoForOutlet(
      outletCode: outletCode,
      sourcePath: pickedPath,
    );

    if (!mounted) return;
    setState(() => _logoPath = savedPath);
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payload = PropertyInfo(
        propertyName: _propertyName.text,
        legalName: _legalName.text,
        address: _address.text,
        city: _city.text,
        state: _state.text,
        pinCode: _pin.text,
        contactPerson: _contactPerson.text,
        mobile: _mobile.text,
        email: _email.text,
        gstNo: _gstNo.text,
        panNo: _panNo.text,
        fssaiNo: _fssaiNo.text,
        drugLicenseNo: _drugLicenseNo.text,
        logoPath: _logoPath,
        isActive: _active,
        website: _website.text,
        printMobile: _printMobile,
        printEmail: _printEmail,
        printWebsite: _printWebsite,
        thermalFooterNote: _thermalFooterNote.text,
      );

      await ctrl.save(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Property profile updated successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(24),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Property Configuration',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _sectionCard(
                    title: 'General Information',
                    icon: Icons.business_rounded,
                    children: [
                      _field(_propertyName, 'Property Name',
                          prefixIcon: Icons.storefront),
                      _field(_legalName, 'Registered Legal Name',
                          prefixIcon: Icons.gavel),
                    ],
                  ),
                  _sectionCard(
                    title: 'Location & Address',
                    icon: Icons.map_rounded,
                    children: [
                      _field(_address, 'Street Address',
                          width: double.infinity,
                          prefixIcon: Icons.location_on,
                          maxLines: 2),
                      _field(_city, 'City', prefixIcon: Icons.location_city),
                      _field(_state, 'State / Region', prefixIcon: Icons.map),
                      _field(_pin, 'Postal / PIN Code',
                          prefixIcon: Icons.pin_drop, isNumber: true),
                    ],
                  ),
                  _sectionCard(
                    title: 'Contact Details',
                    icon: Icons.contact_mail_rounded,
                    children: [
                      _field(_contactPerson, 'Primary Contact Person',
                          prefixIcon: Icons.person),
                      _field(_mobile, 'Mobile Number',
                          prefixIcon: Icons.phone, isNumber: true),
                      _field(_email, 'Email Address',
                          prefixIcon: Icons.email,
                          validator: (v) => v != null && v.contains('@')
                              ? null
                              : 'Enter a valid email address'),
                      _field(_website, 'Website URL',
                          required: false,
                          prefixIcon: Icons.web_rounded),
                    ],
                  ),
                  _sectionCard(
                    title: 'Compliance & Tax',
                    icon: Icons.receipt_long_rounded,
                    children: [
                      _field(_gstNo, 'GST Identification Number',
                          required: false,
                          prefixIcon: Icons.account_balance),
                      _field(_panNo, 'PAN Number',
                          required: false,
                          prefixIcon: Icons.credit_card),
                      _field(_fssaiNo, 'FSSAI License (Optional)',
                          required: false, prefixIcon: Icons.verified_user),
                      _field(_drugLicenseNo, 'Drug License Number (Optional)',
                          required: false, prefixIcon: Icons.medical_services_outlined),
                    ],
                  ),
                  _sectionCard(
                    title: 'Branding & Status',
                    icon: Icons.branding_watermark_rounded,
                    children: [
                      SizedBox(
                        width: 380,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  image: (_logoPath != null &&
                                          File(_logoPath!).existsSync())
                                      ? DecorationImage(
                                          image: FileImage(File(_logoPath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                width: 48,
                                height: 48,
                                child: _logoPath == null ||
                                        !File(_logoPath!).existsSync()
                                    ? Icon(Icons.image,
                                        color: Colors.blue.shade700)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Property Logo',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text('Appears on invoices/reports\n(Recommended: 200x200 px PNG/JPG)',
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _pickLogo,
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                                child:
                                    Text(_logoPath == null ? 'Upload' : 'Change'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 380,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: SwitchListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: const Text('Active Status',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                                'Inactive properties cannot process transactions',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12)),
                            value: _active,
                            activeThumbColor: Colors.green,
                            onChanged: (v) => setState(() => _active = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _sectionCard(
                    title: 'Invoice & Printing Options',
                    icon: Icons.print_rounded,
                    children: [
                      SizedBox(
                        width: 380,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: SwitchListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: const Text('Print Mobile Number',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                                'Include store phone number on invoices and bills',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12)),
                            value: _printMobile,
                            activeThumbColor: Colors.green,
                            onChanged: (v) => setState(() => _printMobile = v),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 380,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: SwitchListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: const Text('Print Email Address',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                                'Include store email address on invoices and bills',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12)),
                            value: _printEmail,
                            activeThumbColor: Colors.green,
                            onChanged: (v) => setState(() => _printEmail = v),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 380,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: SwitchListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: const Text('Print Website',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                                'Include store website on invoices and bills',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12)),
                            value: _printWebsite,
                            activeThumbColor: Colors.green,
                            onChanged: (v) => setState(() => _printWebsite = v),
                          ),
                        ),
                      ),
                      _field(_thermalFooterNote, 'Thermal Receipt Footer Note',
                          width: double.infinity,
                          prefixIcon: Icons.notes_rounded,
                          required: false,
                          maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 20),
                        ),
                        child: Text('Cancel',
                            style: TextStyle(color: Colors.grey.shade700)),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _save,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save_rounded, size: 20),
                          label: Text(
                              _isLoading ? 'Saving...' : 'Save Configuration',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                      color: Theme.of(context).primaryColor, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool isNumber = false,
    bool required = true,
    int maxLines = 1,
    double width = 380,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569)),
              children: [
                if (required)
                  const TextSpan(
                      text: ' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: c,
            maxLines: maxLines,
            keyboardType: isNumber
                ? TextInputType.number
                : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
            validator: validator ??
                (required
                    ? (v) => v == null || v.trim().isEmpty
                        ? 'This field is required'
                        : null
                    : null),
            style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 20, color: const Color(0xFF94A3B8))
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Theme.of(context).primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
