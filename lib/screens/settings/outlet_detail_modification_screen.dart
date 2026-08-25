import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../controllers/settings/property_info_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';
import '../../models/common/property_info_model.dart';
import '../../utils/branding_storage.dart';

class OutletDetailModificationScreen extends StatefulWidget {
  final int outletId;
  const OutletDetailModificationScreen({super.key, this.outletId = 0});

  @override
  State<OutletDetailModificationScreen> createState() => _OutletDetailModificationScreenState();
}

class _OutletDetailModificationScreenState extends State<OutletDetailModificationScreen> {
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
  final _recoveryPin = TextEditingController();
  final _gstNo = TextEditingController();
  final _panNo = TextEditingController();
  final _fssaiNo = TextEditingController();
  final _drugLicenseNo = TextEditingController();
  final _website = TextEditingController();
  final _thermalFooterNote = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccNo = TextEditingController();
  final _bankIfsc = TextEditingController();
  final _upiId = TextEditingController();
  final _upiPayeeName = TextEditingController();
  final _termsAndConditions = TextEditingController();
  String? _logoPath;

  String _outletIdStr = '1';
  String _outletCodeStr = 'OUTLET001';
  String _outletNameStr = '';

  String _selectedBusinessType = 'Retail Store';
  String _selectedOutletModule = 'RETAIL';

  bool _isEditEnabled = false;
  String _registeredEmail = '';
  bool _isEmailVerified = true;
  bool _isVerifyingEmail = false;
  String? _activeOtpCode;
  bool _isDataLoading = true;

  bool _active = true;
  bool _printMobile = true;
  bool _printEmail = true;
  bool _printWebsite = true;
  bool _printBankDetails = false;
  bool _printUpiQr = false;
  bool _printDigitalSignature = false;
  bool _isLoading = false;

  final List<String> _businessTypeOptions = [
    'Retail Store',
    'Supermarket / Grocery',
    'Pharmacy / Healthcare',
    'Restaurant / Cafe',
    'Hotel / Hospitality',
    'Wholesale Distributor',
    'General Store',
  ];

  final List<String> _moduleOptions = [
    'RETAIL',
    'RESTAURANT',
    'INVENTORY',
    'ALL',
  ];

  @override
  void initState() {
    super.initState();
    ctrl = PropertyInfoController();
    _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    setState(() {
      _isDataLoading = true;
    });

    try {
      final userMap = await TokenStorage.getUser();
      if (userMap != null) {
        _outletIdStr = (userMap['outlet_id'] ?? userMap['outletid'] ?? '1').toString();
        _outletCodeStr = (userMap['outlet_code'] ?? 'OUTLET001').toString();
        _outletNameStr = (userMap['outlet_name'] ?? userMap['property_name'] ?? '').toString();

        final bType = userMap['business_type']?.toString();
        if (bType != null && bType.trim().isNotEmpty) {
          if (!_businessTypeOptions.contains(bType.trim())) {
            _businessTypeOptions.add(bType.trim());
          }
          _selectedBusinessType = bType.trim();
        }

        final mod = userMap['outlet_module']?.toString();
        if (mod != null && mod.trim().isNotEmpty) {
          final upperMod = mod.trim().toUpperCase();
          if (!_moduleOptions.contains(upperMod)) {
            _moduleOptions.add(upperMod);
          }
          _selectedOutletModule = upperMod;
        }
      }

      await ctrl.load();
      final d = ctrl.data;
      if (d != null) {
        _propertyName.text = d.propertyName;
        _legalName.text = d.legalName;
        _address.text = d.address;
        _city.text = d.city;
        _state.text = d.state;
        _pin.text = d.pinCode;
        _contactPerson.text = d.contactPerson;
        _mobile.text = d.mobile;
        _email.text = d.email;
        _registeredEmail = d.email.trim();
        _isEmailVerified = true;
        _recoveryPin.text = d.recoveryPin;

        if (d.businessType.trim().isNotEmpty) {
          if (!_businessTypeOptions.contains(d.businessType.trim())) {
            _businessTypeOptions.add(d.businessType.trim());
          }
          _selectedBusinessType = d.businessType.trim();
        }

        if (d.outletModule.trim().isNotEmpty) {
          final upperMod = d.outletModule.trim().toUpperCase();
          if (!_moduleOptions.contains(upperMod)) {
            _moduleOptions.add(upperMod);
          }
          _selectedOutletModule = upperMod;
        }

        _gstNo.text = d.gstNo;
        _panNo.text = d.panNo;
        _fssaiNo.text = d.fssaiNo;
        _drugLicenseNo.text = d.drugLicenseNo;
        _website.text = d.website;
        _thermalFooterNote.text = d.thermalFooterNote;
        _bankName.text = d.bankName;
        _bankAccNo.text = d.bankAccNo;
        _bankIfsc.text = d.bankIfsc;
        _upiId.text = d.upiId;
        _upiPayeeName.text = d.upiPayeeName;
        _termsAndConditions.text = d.termsAndConditions;
        _logoPath = d.logoPath;
        _active = d.isActive;
        _printMobile = d.printMobile;
        _printEmail = d.printEmail;
        _printWebsite = d.printWebsite;
        _printBankDetails = d.printBankDetails;
        _printUpiQr = d.printUpiQr;
        _printDigitalSignature = d.printDigitalSignature;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isDataLoading = false);
      }
    }
  }

  Future<void> _pickLogo() async {
    if (!_isEditEnabled) return;

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

  void _triggerEmailVerification() async {
    final targetEmail = _email.text.trim();
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address first'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isVerifyingEmail = true);

    try {
      final res = await ApiClient.post(
        ApiEndpoints.sendSetpOtp,
        {'email': targetEmail},
      );

      if (!mounted) return;
      setState(() => _isVerifyingEmail = false);

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Verification code sent to $targetEmail'),
            backgroundColor: Colors.green,
          ),
        );
        _showOtpDialog(targetEmail);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to send verification code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingEmail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting OTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOtpDialog(String targetEmail) {
    final otpCtrl = TextEditingController();
    String? otpError;
    bool isVerifyingCode = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFFFF7A1A), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Email Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A 6-digit verification code was sent to your registered email:',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetEmail,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '• • • • • •',
                      errorText: otpError,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFFF7A1A), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifyingCode ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isVerifyingCode
                      ? null
                      : () async {
                          final entered = otpCtrl.text.trim();
                          if (entered.length < 6) {
                            setDialogState(() {
                              otpError = 'Please enter full 6-digit code';
                            });
                            return;
                          }

                          setDialogState(() {
                            isVerifyingCode = true;
                            otpError = null;
                          });

                          try {
                            final res = await ApiClient.post(
                              ApiEndpoints.verifySetpOtp,
                              {
                                'email': targetEmail,
                                'otp': entered,
                              },
                            );

                            if (res['success'] == true) {
                              Navigator.pop(dialogCtx);
                              setState(() {
                                _isEmailVerified = true;
                                _registeredEmail = targetEmail;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Email $targetEmail verified successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              setDialogState(() {
                                isVerifyingCode = false;
                                otpError = res['message'] ?? 'Invalid verification code.';
                              });
                            }
                          } catch (err) {
                            setDialogState(() {
                              isVerifyingCode = false;
                              otpError = 'Verification failed: $err';
                            });
                          }
                        },
                  icon: isVerifyingCode
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: Text(isVerifyingCode ? 'Verifying...' : 'Verify Code', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _save() async {
    if (!_isEditEnabled) return;
    if (!_formKey.currentState!.validate()) return;

    if (_email.text.trim().toLowerCase() != _registeredEmail.trim().toLowerCase() && !_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Email has been modified. Please send verification code and verify before saving!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
        bankName: _bankName.text,
        bankAccNo: _bankAccNo.text,
        bankIfsc: _bankIfsc.text,
        upiId: _upiId.text,
        upiPayeeName: _upiPayeeName.text,
        termsAndConditions: _termsAndConditions.text,
        printBankDetails: _printBankDetails,
        printUpiQr: _printUpiQr,
        printDigitalSignature: _printDigitalSignature,
        businessType: _selectedBusinessType,
        outletModule: _selectedOutletModule,
        recoveryPin: _recoveryPin.text,
      );

      await ctrl.save(payload);
      if (!mounted) return;

      setState(() {
        _isEditEnabled = false;
        _registeredEmail = _email.text.trim();
        _isEmailVerified = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Outlet details updated and synced to Google Sheets successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update outlet details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EEE8),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.storefront_outlined, color: Color(0xFFFF7A1A)),
            SizedBox(width: 10),
            Text(
              'Outlet Detail Modification',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(
            tooltip: 'Exit Screen',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 24, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isDataLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF7A1A)),
                  SizedBox(height: 16),
                  Text('Loading Outlet Details...', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. CARD HEADER & EDIT / LOCK TOGGLE
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.storefront_rounded, color: Color(0xFFFF7A1A), size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Store Setup & Registration Details',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isEditEnabled
                                            ? 'Editing Mode Active - Update details & sync to Google Sheets'
                                            : 'Read-Only Mode - Click Edit to unlock fields',
                                        style: TextStyle(fontSize: 12, color: _isEditEnabled ? const Color(0xFFFF7A1A) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      side: BorderSide(color: _isEditEnabled ? const Color(0xFFCBD5E1) : const Color(0xFFFF7A1A)),
                                      backgroundColor: _isEditEnabled ? Colors.transparent : const Color(0xFFFFF7ED),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => setState(() => _isEditEnabled = !_isEditEnabled),
                                    icon: Icon(_isEditEnabled ? Icons.lock_outline : Icons.edit_rounded, size: 16, color: const Color(0xFFFF7A1A)),
                                    label: Text(
                                      _isEditEnabled ? 'Lock View' : 'Edit Details',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF7A1A)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // 2. READ-ONLY SYSTEM METADATA CHIPS
                          _buildOutletSystemMetadataRow(),

                          const SizedBox(height: 24),

                          // 3. STORE & BUSINESS CONFIGURATION GRID
                          _buildSectionTitle('Store & Business Configuration', Icons.business_rounded),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 20,
                            runSpacing: 16,
                            children: [
                              _field(_legalName, 'Registered Legal Name', prefixIcon: Icons.gavel, enabled: _isEditEnabled),
                              _dropdownField(
                                label: 'Business Type',
                                value: _selectedBusinessType,
                                items: _businessTypeOptions,
                                onChanged: _isEditEnabled ? (v) => setState(() => _selectedBusinessType = v!) : null,
                                prefixIcon: Icons.category_rounded,
                              ),
                              _dropdownField(
                                label: 'Business Module',
                                value: _selectedOutletModule,
                                items: _moduleOptions,
                                onChanged: _isEditEnabled ? (v) => setState(() => _selectedOutletModule = v!) : null,
                                prefixIcon: Icons.space_dashboard_rounded,
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // 4. LOCATION & SECURITY DETAILS GRID
                          _buildSectionTitle('Location & Security Details', Icons.location_on_rounded),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 20,
                            runSpacing: 16,
                            children: [
                              _field(_address, 'Street Address', width: double.infinity, prefixIcon: Icons.location_on, maxLines: 2, enabled: _isEditEnabled),
                              _field(_city, 'City', prefixIcon: Icons.location_city, enabled: _isEditEnabled),
                              _field(_state, 'State / Region', prefixIcon: Icons.map, enabled: _isEditEnabled),
                              _field(_pin, 'Postal / PIN Code', prefixIcon: Icons.pin_drop, isNumber: true, enabled: _isEditEnabled),
                              _field(_recoveryPin, 'Manager Recovery PIN (4-Digits)', prefixIcon: Icons.lock_reset_rounded, isNumber: true, enabled: _isEditEnabled, required: false),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // 5. CONTACT INFO & EMAIL VERIFICATION GRID
                          _buildSectionTitle('Contact Information & Email Verification', Icons.contact_mail_rounded),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 20,
                            runSpacing: 16,
                            children: [
                              _field(_contactPerson, 'Primary Contact Person', prefixIcon: Icons.person, enabled: _isEditEnabled),
                              _field(_mobile, 'Contact Phone / Mobile Number', prefixIcon: Icons.phone, isNumber: true, enabled: _isEditEnabled),
                              _emailWithVerificationField(),
                              _field(_website, 'Website URL', required: false, prefixIcon: Icons.web_rounded, enabled: _isEditEnabled),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // 6. TAXATION & LEGAL REGISTRATION GRID
                          _buildSectionTitle('Taxation & Legal Registration', Icons.receipt_long_rounded),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 20,
                            runSpacing: 16,
                            children: [
                              _field(_gstNo, 'GST Identification Number (GSTIN)', required: false, prefixIcon: Icons.account_balance, enabled: _isEditEnabled),
                              _field(_panNo, 'PAN Number', required: false, prefixIcon: Icons.credit_card, enabled: _isEditEnabled),
                              _field(_fssaiNo, 'FSSAI License (Optional)', required: false, prefixIcon: Icons.verified_user, enabled: _isEditEnabled),
                              _field(_drugLicenseNo, 'Drug License Number (Optional)', required: false, prefixIcon: Icons.medical_services_outlined, enabled: _isEditEnabled),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // 7. BANK ACCOUNT & UPI INSTANT QR GRID
                          _buildSectionTitle('Bank Account & UPI Instant QR', Icons.account_balance_rounded),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 20,
                            runSpacing: 16,
                            children: [
                              _field(_bankName, 'Bank Name', prefixIcon: Icons.business_rounded, required: false, enabled: _isEditEnabled),
                              _field(_bankAccNo, 'Account Number', prefixIcon: Icons.credit_card_rounded, required: false, enabled: _isEditEnabled),
                              _field(_bankIfsc, 'IFSC Code', prefixIcon: Icons.code_rounded, required: false, enabled: _isEditEnabled),
                              _field(_upiId, 'UPI VPA ID', prefixIcon: Icons.alternate_email_rounded, required: false, enabled: _isEditEnabled),
                              _field(_upiPayeeName, 'Payee Legal Name', prefixIcon: Icons.person_rounded, required: false, enabled: _isEditEnabled),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // 8. THERMAL BILL FOOTER & TERMS
                          _buildSectionTitle('Thermal Bill Footer & Terms', Icons.border_color_rounded),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 20,
                            runSpacing: 16,
                            children: [
                              _field(_thermalFooterNote, 'Thermal Receipt Footer Note', width: double.infinity, prefixIcon: Icons.subtitles_rounded, required: false, maxLines: 3, enabled: _isEditEnabled),
                              _field(_termsAndConditions, 'Invoice Terms & Conditions', width: double.infinity, prefixIcon: Icons.description_rounded, required: false, maxLines: 4, enabled: _isEditEnabled),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // 9. STORE LOGO & STATUS
                          _buildSectionTitle('Store Logo & Status', Icons.branding_watermark_rounded),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 20,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: 310,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(8),
                                          image: (_logoPath != null && File(_logoPath!).existsSync())
                                              ? DecorationImage(
                                                  image: FileImage(File(_logoPath!)),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: _logoPath == null || !File(_logoPath!).existsSync()
                                            ? const Icon(Icons.image, color: Color(0xFF2563EB))
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Store Logo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text('Bills & Invoices', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed: _isEditEnabled ? _pickLogo : null,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          side: BorderSide(color: _isEditEnabled ? const Color(0xFFFF7A1A) : const Color(0xFFCBD5E1)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          _logoPath == null ? 'Upload' : 'Change',
                                          style: TextStyle(
                                            color: _isEditEnabled ? const Color(0xFFFF7A1A) : const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 310,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                  ),
                                  child: SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    title: const Text('Outlet Active Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('Active for POS sales', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                    value: _active,
                                    activeThumbColor: Colors.green,
                                    onChanged: _isEditEnabled ? (v) => setState(() => _active = v) : null,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 24),

                          // 10. BOTTOM CARD ACTION BUTTONS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                                label: const Text('Exit', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 14),
                              if (_isEditEnabled) ...[
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    side: const BorderSide(color: Color(0xFF94A3B8)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => setState(() => _isEditEnabled = false),
                                  icon: const Icon(Icons.cancel_outlined, color: Color(0xFF64748B), size: 18),
                                  label: const Text('Cancel Edit', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 14),
                              ],
                              SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _isEditEnabled ? const Color(0xFFFF7A1A) : const Color(0xFF64748B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 28),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : (_isEditEnabled ? _save : () => setState(() => _isEditEnabled = true)),
                                  icon: _isLoading
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Icon(_isEditEnabled ? Icons.cloud_upload_rounded : Icons.edit_rounded, size: 20),
                                  label: Text(
                                    _isLoading
                                        ? 'Syncing to Google Sheets...'
                                        : (_isEditEnabled ? 'Save Modifications & Sync Google Sheets' : 'Enable Editing'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFFF7A1A), size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildOutletSystemMetadataRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          _readOnlyMetaTile('Outlet ID (Non-Editable)', _outletIdStr, Icons.tag_rounded),
          _readOnlyMetaTile('Outlet Code (Non-Editable)', _outletCodeStr, Icons.qr_code_rounded),
          _field(_propertyName, 'Store / System Name', width: 310, prefixIcon: Icons.storefront, enabled: _isEditEnabled),
        ],
      ),
    );
  }

  Widget _readOnlyMetaTile(String label, String value, IconData icon) {
    return SizedBox(
      width: 310,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFFF7A1A)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value.isEmpty ? '--' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                ],
              ),
            ),
            const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _emailWithVerificationField() {
    final isEmailChanged = _email.text.trim().toLowerCase() != _registeredEmail.trim().toLowerCase();
    final isVerified = _isEmailVerified && !isEmailChanged;

    return SizedBox(
      width: 310,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: const TextSpan(
                  text: 'Email Address',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(isVerified ? Icons.check_circle : Icons.warning_amber_rounded, size: 12, color: isVerified ? Colors.green.shade800 : Colors.amber.shade900),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Verified' : 'Verification Needed',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isVerified ? Colors.green.shade800 : Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            enabled: _isEditEnabled,
            onChanged: (v) {
              setState(() {
                _isEmailVerified = v.trim().toLowerCase() == _registeredEmail.trim().toLowerCase();
              });
            },
            validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address' : null,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _isEditEnabled && !isVerified
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A1A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isVerifyingEmail ? null : _triggerEmailVerification,
                        child: _isVerifyingEmail
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Send Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    )
                  : (isVerified ? const Icon(Icons.verified_rounded, color: Colors.green, size: 18) : null),
              filled: true,
              fillColor: _isEditEnabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF7A1A), width: 2)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    required IconData prefixIcon,
  }) {
    final effectiveItems = List<String>.from(items);
    if (value.trim().isNotEmpty && !effectiveItems.contains(value.trim())) {
      effectiveItems.add(value.trim());
    }
    final selectedVal = effectiveItems.contains(value.trim()) ? value.trim() : (effectiveItems.isNotEmpty ? effectiveItems.first : '');

    return SizedBox(
      width: 310,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedVal.isNotEmpty ? selectedVal : null,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: onChanged != null ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF7A1A), width: 2)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            items: effectiveItems
                .map((e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    ))
                .toList(),
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
    bool enabled = true,
    int maxLines = 1,
    double width = 310,
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              children: [
                if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: c,
            enabled: enabled,
            maxLines: maxLines,
            keyboardType: isNumber ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
            validator: validator ?? (required ? (v) => v == null || v.trim().isEmpty ? 'This field is required' : null : null),
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF94A3B8)) : null,
              filled: true,
              fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF7A1A), width: 2)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
            ),
          ),
        ],
      ),
    );
  }
}
