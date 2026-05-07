import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory/screens/auth/inventorylogin.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../controllers/public/outlet_controller.dart';
import '../../controllers/public/recovery_controller.dart';
import '../../core/config/app_config.dart';

enum SetupMode { newClient, existingClient, recoverId }

enum FlowStep { initial, otpVerification }

class OutletSetupScreen extends StatefulWidget {
  const OutletSetupScreen({super.key});

  @override
  State<OutletSetupScreen> createState() => _OutletSetupScreenState();
}

class _OutletSetupScreenState extends State<OutletSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Base Fields
  final _outletCode = TextEditingController();
  final _outletName = TextEditingController();
  String _outletType = 'HOTEL';

  // Enterprise Recovery Fields
  final _contactEmail = TextEditingController();
  final _contactPhone = TextEditingController();
  final _recoveryPin = TextEditingController();
  final _taxId = TextEditingController();
  bool _isEmailVerified = false;
  bool _isOtpSentForSetup = false;
  final _setupOtpCode = TextEditingController();
  // OTP Verification Field
  final _otpCode = TextEditingController();

  // State Management
  SetupMode _mode = SetupMode.newClient;
  FlowStep _step = FlowStep.initial;

  bool _isLoading = false;
  bool _obscurePin = true;
  bool _forgotPinMode = false;

  final outletCtrl = OutletController();
  final recoveryCtrl = RecoveryController();

  @override
  void initState() {
    super.initState();
    _generateAndSetNewCode();
  }

  @override
  void dispose() {
    _outletCode.dispose();
    _outletName.dispose();
    _contactEmail.dispose();
    _contactPhone.dispose();
    _recoveryPin.dispose();
    _taxId.dispose();
    _otpCode.dispose();
    super.dispose();
  }

  // ================= STATE SWITCHERS =================

  void _generateAndSetNewCode() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    _outletCode.text =
        "OUTLET${now.year}${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}";
  }

  void _switchMode(SetupMode newMode) {
    setState(() {
      _mode = newMode;
      _step = FlowStep.initial;
      _forgotPinMode = false;

      _formKey.currentState?.reset();
      _outletName.clear();
      _contactEmail.clear();
      _contactPhone.clear();
      _recoveryPin.clear();
      _taxId.clear();
      _otpCode.clear();

      if (_mode == SetupMode.newClient) {
        _generateAndSetNewCode();
      } else {
        _outletCode.clear();
      }
    });
  }

  Future<void> _addOutletToConfig(String newOutletCode) async {
    if (!AppConfig.outlets.contains(newOutletCode)) {
      List<String> updatedOutlets = List.from(AppConfig.outlets)
        ..add(newOutletCode);
      await AppConfig.saveConfig(AppConfig.baseUrl, updatedOutlets);
    }
  }

  // ================= CORE LOGIC: MODE 1 (NEW SETUP) =================

  Future<void> _saveNew() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final code = _outletCode.text.trim();
      final response = await outletCtrl.createOutlet({
        'outlet_code': code,
        'outlet_name': _outletName.text.trim(),
        'outlet_type': _outletType,
        'contact_email': _contactEmail.text.trim(),
        'contact_phone': _contactPhone.text.trim(),
        'recovery_pin': _recoveryPin.text.trim(),
        'tax_id': _taxId.text.trim(),
      });

      await _addOutletToConfig(code);
      if (!mounted) return;

      if (response['data'] != null &&
          response['data']['admin_credentials'] != null) {
        final creds = response['data']['admin_credentials'];
        await _showCredentialsDialog(
            code, creds['username'], creds['password']);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Business profile configured successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= CORE LOGIC: MODE 2 (LINK EXISTING & FULL RECOVER) =================

  Future<void> _verifyExistingPin() async {
    if (!_formKey.currentState!.validate()) return;

    // Show non-dismissible loading dialog for the recovery process
    _showRecoveryLoadingDialog();

    try {
      final code = _outletCode.text.trim();
      final pin = _recoveryPin.text.trim();

      // 1. Verify PIN via Backend
      final verifyRes = await recoveryCtrl.verifyPin(code, pin);

      // 2. Execute full system recovery (Downloads DB and Configs)
      await recoveryCtrl.executeRecovery(
          verifyRes['folderId'], verifyRes['clientData']);

      // 3. Save locally
      await _addOutletToConfig(code);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showRecoveryCompleteDialog(); // Show Success Dialog
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog on error
      _showError(e.toString());
    }
  }

  Future<void> _requestOtpForExisting({bool isResend = false}) async {
    if (_outletCode.text.trim().isEmpty) {
      _showError("Business ID is required to send OTP.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      final res = await recoveryCtrl.requestOtp(
          outletCode: _outletCode.text.trim(), isResend: isResend);

      if (!mounted) return;
      setState(() => _step = FlowStep.otpVerification);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'OTP sent successfully.'),
            backgroundColor: Colors.blue),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpAndLink() async {
    if (_otpCode.text.trim().isEmpty) {
      _showError("OTP Code is required.");
      return;
    }

    // Show non-dismissible loading dialog for the recovery process
    _showRecoveryLoadingDialog();

    try {
      final code = _outletCode.text.trim();
      final otp = _otpCode.text.trim();

      // 1. Verify the OTP (Backend returns folderId and clientData)
      final verifyRes =
          await recoveryCtrl.verifyOtp(outletCode: code, otp: otp);

      // 2. Execute full system recovery
      await recoveryCtrl.executeRecovery(
          verifyRes['folderId'], verifyRes['clientData']);

      // 3. Save locally
      await _addOutletToConfig(code);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showRecoveryCompleteDialog(); // Show Success Dialog
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog on error
      _showError(e.toString());
    }
  }

  // ================= CORE LOGIC: MODE 3 (RECOVER ID) =================

  Future<void> _findOutletAndSendOtp({bool isResend = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await recoveryCtrl.requestOtp(
          contactStr: _contactEmail.text.trim(), isResend: isResend);

      if (!mounted) return;
      setState(() => _step = FlowStep.otpVerification);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'OTP sent to your email/phone.'),
            backgroundColor: Colors.blue),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyRecoveryOtp() async {
    if (_otpCode.text.trim().isEmpty) {
      _showError("OTP Code is required.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await recoveryCtrl.verifyOtp(
          contactStr: _contactEmail.text.trim(), otp: _otpCode.text.trim());

      List<dynamic> recoveredOutlets =
          response['data']['outlets'] ?? [response['data']];

      if (!mounted) return;

      _showRecoveredOutletsDialog(recoveredOutlets);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message.replaceAll('Exception:', '').trim()),
        backgroundColor: Colors.red));
  }

  Future<void> _sendSetupOtp() async {
    final email = _contactEmail.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError("Please enter a valid email address first.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final msg = await outletCtrl.sendSetupOtp(email);

      if (!mounted) return;
      setState(() => _isOtpSentForSetup = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.blue),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifySetupOtp() async {
    if (_setupOtpCode.text.trim().isEmpty) {
      _showError("Please enter the OTP.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await outletCtrl.verifySetupOtp(
          _contactEmail.text.trim(), _setupOtpCode.text.trim());

      if (!mounted) return;
      setState(() {
        _isEmailVerified = true;
        _isOtpSentForSetup = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Email Verified Successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetEmailVerification() {
    setState(() {
      _isEmailVerified = false;
      _isOtpSentForSetup = false;
      _setupOtpCode.clear(); // Clear the old OTP input
    });
  }
  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(blurRadius: 30, color: Colors.black.withOpacity(.08))
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildModeSelector(),
                  const Divider(height: 40),

                  // Dynamic Form Rendering
                  if (_mode == SetupMode.newClient) _buildNewSetupForm(),
                  if (_mode == SetupMode.existingClient)
                    _buildExistingClientForm(),
                  if (_mode == SetupMode.recoverId) _buildRecoverIdForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Center(
            child: Icon(Icons.storefront, size: 60, color: Colors.blue)),
        if (AppConfig.outlets.isNotEmpty)
          Positioned(
            left: 0,
            child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context)),
          )
      ],
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<SetupMode>(
      segments: const [
        ButtonSegment(
            value: SetupMode.newClient,
            label: Text("New Registration"),
            icon: Icon(Icons.add_business)),
        ButtonSegment(
            value: SetupMode.existingClient,
            label: Text("Link Existing"),
            icon: Icon(Icons.link)),
        ButtonSegment(
            value: SetupMode.recoverId,
            label: Text("Recover Business ID"),
            icon: Icon(Icons.search)),
      ],
      selected: {_mode},
      onSelectionChanged: (Set<SetupMode> newSelection) =>
          _switchMode(newSelection.first),
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ---------------- FORM: NEW SETUP ----------------
  Widget _buildNewSetupForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputField(
            controller: _outletCode,
            label: "Business ID",
            hint: "",
            icon: Icons.tag,
            readOnly: true),
        const SizedBox(height: 18),
        _inputField(
            controller: _outletName,
            label: "Business Name *",
            hint: "Hotel / Restaurant / Warehouse / Retail Name",
            icon: Icons.business),
        const SizedBox(height: 18),
        _dropdown(),
        const SizedBox(height: 24),
        _buildSectionHeader("Recovery & Verification Data"),
        const SizedBox(height: 16),
        _inputField(
          controller: _recoveryPin,
          label: "Recovery PIN (Min. 4 chars) *",
          hint: "Create a secure PIN",
          icon: Icons.lock_outline,
          obscureText: _obscurePin,
          suffixIcon: IconButton(
              icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePin = !_obscurePin)),
          validator: (v) =>
              v == null || v.trim().length < 4 ? "Min 4 chars required." : null,
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _inputField(
                controller: _contactEmail,
                label: "Contact Email *",
                hint: "admin@example.com",
                icon: Icons.email_outlined,
                required: true,
                // Lock the field if OTP is sent OR verified to prevent typos during verification
                readOnly: _isEmailVerified || _isOtpSentForSetup,
              ),
            ),
            const SizedBox(width: 12),

            // STATE 1: EMAIL IS VERIFIED
            if (_isEmailVerified)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 36),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        tooltip: "Change Email",
                        onPressed: _resetEmailVerification,
                      ),
                    ],
                  ),
                ),
              )

            // STATE 2: OTP IS SENT (Waiting for verification)
            else if (_isOtpSentForSetup)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: OutlinedButton.icon(
                    onPressed: _resetEmailVerification,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Email'),
                  ),
                ),
              )

            // STATE 3: READY TO SEND
            else
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: FilledButton.tonal(
                    onPressed: _isLoading ? null : _sendSetupOtp,
                    child: const Text('Send Code'),
                  ),
                ),
              ),
          ],
        ),
        if (_isOtpSentForSetup && !_isEmailVerified) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _inputField(
                  controller: _setupOtpCode,
                  label: "Enter OTP Code *",
                  hint: "123456",
                  icon: Icons.password,
                  isNumber: true,
                  required: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: FilledButton(
                    onPressed: _isLoading ? null : _verifySetupOtp,
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Verify'),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _inputField(
          controller: _contactPhone,
          label: "Contact Phone (Opt)",
          hint: "+1 234 567",
          icon: Icons.phone_outlined,
          required: false,
        ),
        const SizedBox(height: 28),
        _buildActionButton(
          "Create Business Profile",
          _isEmailVerified
              ? _saveNew
              : () {
                  _showError(
                      "You must verify your email address before creating the business profile.");
                },
        ),
      ],
    );
  }

  // ---------------- FORM: LINK EXISTING ----------------
  Widget _buildExistingClientForm() {
    if (_step == FlowStep.otpVerification) {
      return _buildOtpVerificationSection(
        "Verify OTP to Link Device",
        _verifyOtpAndLink,
        () => _requestOtpForExisting(isResend: true),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputField(
            controller: _outletCode,
            label: "Business ID *",
            hint: "Enter existing code",
            icon: Icons.tag),
        const SizedBox(height: 18),
        if (!_forgotPinMode) ...[
          _inputField(
            controller: _recoveryPin,
            label: "Recovery PIN *",
            hint: "Enter your 4+ digit PIN",
            icon: Icons.lock,
            obscureText: _obscurePin,
            suffixIcon: IconButton(
                icon:
                    Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePin = !_obscurePin)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _forgotPinMode = true),
              child: const Text("Forgot PIN? Use OTP instead"),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton("Verify & Recover System", _verifyExistingPin),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: const Text(
                "We will send a one-time password (OTP) to the email or phone number registered with this Business ID.",
                style: TextStyle(color: Colors.blue)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _forgotPinMode = false),
              child: const Text("I remember my PIN"),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton("Send OTP", _requestOtpForExisting),
        ]
      ],
    );
  }

  // ---------------- FORM: RECOVER ID ----------------
  Widget _buildRecoverIdForm() {
    if (_step == FlowStep.otpVerification) {
      return _buildOtpVerificationSection(
        "Verify OTP to Reveal ID",
        _verifyRecoveryOtp,
        () => _findOutletAndSendOtp(isResend: true),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: const Text(
              "Forgot your Business ID? Enter your registered email or phone number to find it.",
              style: TextStyle(color: Colors.deepOrange)),
        ),
        const SizedBox(height: 24),
        _inputField(
          controller: _contactEmail,
          label: "Registered Email or Phone *",
          hint: "Enter email or phone",
          icon: Icons.search,
        ),
        const SizedBox(height: 28),
        _buildActionButton("Find Business ID & Send OTP", _findOutletAndSendOtp),
      ],
    );
  }

  Future<void> _showRecoveredOutletsDialog(List<dynamic> outlets) async {
    // If they only have 1 outlet, pre-select it. Otherwise, leave it null.
    int? selectedIndex = outlets.length == 1 ? 0 : null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.fact_check, color: Colors.green),
                SizedBox(width: 12),
                Text('Select Your Business'),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      "A copy of these business IDs has been sent to your email. Select the business you want to set up on this device:",
                      style: TextStyle(color: Colors.green, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Scrollable list of Checkboxes
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Container(
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: outlets.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final outlet = outlets[index];
                          final code = outlet['outlet_code'] ?? 'UNKNOWN';
                          final name =
                              outlet['property_name'] ?? 'Unknown Property';

                          return CheckboxListTile(
                            activeColor: Colors.blue,
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text("Code: $code"),
                            value: selectedIndex == index,
                            onChanged: (bool? value) {
                              if (value == true) {
                                // Acting as a radio button - only one can be checked
                                setDialogState(() => selectedIndex = index);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: selectedIndex == null
                    ? null // Disable button if nothing is checked
                    : () {
                        final selectedCode =
                            outlets[selectedIndex!]['outlet_code'];
                        Navigator.pop(context); // close dialog

                        // Push the selected code into the main UI and switch modes
                        setState(() {
                          _outletCode.text = selectedCode;
                          _mode = SetupMode.existingClient; // Move to Link Mode
                          _step = FlowStep.initial;
                          _forgotPinMode = false;
                        });
                      },
                child: const Text("Use Selected Business"),
              )
            ],
          );
        },
      ),
    );
  }

  // ---------------- SHARED WIDGETS ----------------

  Widget _buildOtpVerificationSection(
      String buttonLabel, VoidCallback onSubmit, VoidCallback onResend) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200)),
          child: const Row(
            children: [
              Icon(Icons.mark_email_read, color: Colors.green),
              SizedBox(width: 12),
              Expanded(
                  child: Text(
                      "An OTP has been sent. Please enter it below to verify your identity.",
                      style: TextStyle(color: Colors.green))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _inputField(
            controller: _otpCode,
            label: "6-Digit OTP Code *",
            hint: "123456",
            icon: Icons.password,
            isNumber: true,
            validator: (v) => v == null || v.length < 4 ? "Invalid OTP" : null),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = FlowStep.initial),
              child: const Text("Change Details"),
            ),
            TextButton.icon(
              onPressed: _isLoading ? null : onResend,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Resend OTP"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionButton(buttonLabel, onSubmit),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.shield, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _inputField(
      {required TextEditingController controller,
      required String label,
      required String hint,
      required IconData icon,
      bool readOnly = false,
      bool obscureText = false,
      bool required = true,
      bool isNumber = false,
      Widget? suffixIcon,
      TextInputAction textInputAction = TextInputAction.next,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      textInputAction: textInputAction,
      onFieldSubmitted: (_) {
        if (textInputAction == TextInputAction.next) {
          FocusScope.of(context).nextFocus();
        } else {
          FocusScope.of(context).unfocus();
        }
      },
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      validator: validator ??
          (required
              ? (v) => v == null || v.trim().isEmpty ? "Required field" : null
              : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? const Color(0xffE9ECEF) : const Color(0xffF7F9FC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _dropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _outletType,
      decoration: InputDecoration(
          labelText: "Business Type",
          prefixIcon: const Icon(Icons.category),
          filled: true,
          fillColor: const Color(0xffF7F9FC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      items: const [
        DropdownMenuItem(value: 'HOTEL', child: Text('Hotel')),
        DropdownMenuItem(value: 'RESTAURANT', child: Text('Restaurant')),
        DropdownMenuItem(value: 'WAREHOUSE', child: Text('Warehouse')),
        DropdownMenuItem(value: 'RETAIL', child: Text('Retail')),
        DropdownMenuItem(value: 'CAFE', child: Text('Cafe')),
        DropdownMenuItem(value: 'BAR', child: Text('Bar'))
      ],
      onChanged: (v) => setState(() => _outletType = v!),
    );
  }

  // ================= DIALOGS =================

  /// Show this while downloading DB and configs during existing client link
  void _showRecoveryLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                "Recovering Business Data...",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Downloading database and configurations.\nPlease do not close the app.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show this after recovery completes successfully
  void _showRecoveryCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text("Recovery Complete"),
          ],
        ),
        content: const Text(
            "Your device has been successfully linked and the business database has been fully restored from the cloud."),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const InventoryLoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Proceed to Login"),
          )
        ],
      ),
    );
  }

  Future<void> _showRecoveredCodeDialog(String code) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 12),
          Text('Business Found')
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your verified Business ID is:"),
            const SizedBox(height: 12),
            SelectableText(code,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              setState(() {
                _outletCode.text = code;
                _mode = SetupMode.existingClient; // switch to existing mode
                _step = FlowStep.initial;
                _forgotPinMode = false;
              });
            },
            child: const Text("Use this ID"),
          )
        ],
      ),
    );
  }

  Future<void> _showCredentialsDialog(
      String outletCode, String username, String password) async {
    final String exportText =
        "=== SYSTEM SETUP CREDENTIALS ===\nDate: ${DateTime.now().toString().split('.')[0]}\nBusiness ID: $outletCode\nAdmin Username: $username\nAdmin Password: $password\n================================\nPlease keep this file secure.";

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool hasSaved = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(children: [
                Icon(Icons.admin_panel_settings, color: Colors.blue, size: 32),
                SizedBox(width: 12),
                Text('Setup Complete')
              ]),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200)),
                        child: const Text(
                            "Save these credentials immediately. The password is encrypted and cannot be shown again.",
                            style:
                                TextStyle(color: Colors.brown, fontSize: 13))),
                    const SizedBox(height: 24),
                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300)),
                        child: Column(children: [
                          _credentialRow('Business ID', outletCode),
                          const Divider(height: 24),
                          _credentialRow('Username', username),
                          const Divider(height: 24),
                          _credentialRow('Password', password)
                        ])),
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: exportText));
                            setState(() => hasSaved = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied!'),
                                    backgroundColor: Colors.green));
                          },
                          icon: const Icon(Icons.copy, size: 20),
                          label: const Text("Copy"),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final Directory? dir =
                                  await getDownloadsDirectory();
                              final file = File(p.join(dir!.path,
                                  'Admin_Credentials_$outletCode.txt'));
                              await file.writeAsString(exportText);
                              setState(() => hasSaved = true);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Saved to Downloads!'),
                                      backgroundColor: Colors.green));
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Failed to save.'),
                                      backgroundColor: Colors.red));
                            }
                          },
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text("Save"),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: hasSaved
                          ? () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const InventoryLoginScreen()))
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Continue"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _credentialRow(String label, String value) {
    return Row(children: [
      SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13))),
      Expanded(
          child: SelectableText(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87)))
    ]);
  }
}
