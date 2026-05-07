import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/core/api/endpoints.dart';

import '../../core/config/app_config.dart';

class RecoveryController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  bool _otpSent = false;
  String _savedOutletCode = "";

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get otpSent => _otpSent;

  void resetState() {
    _otpSent = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> requestOtp(String outletCode) async {
    _setLoading(true);
    _savedOutletCode = outletCode;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}${ApiEndpoints.requestOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'outletCode': outletCode, 'isResend': false}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _otpSent = true;
        _errorMessage = null;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = data['message'] ?? "Failed to send OTP.";
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = "Network error. Please check your connection.";
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    _setLoading(true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}${ApiEndpoints.verifyAndRecoverConfig}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'outletCode': _savedOutletCode, 'otp': otp}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _errorMessage = null;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = data['message'] ?? "Invalid OTP.";
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = "Network error while verifying OTP.";
      _setLoading(false);
      return false;
    }
  }

  Future<bool> triggerAutoReinstall() async {
    _setLoading(true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}${ApiEndpoints.triggerAutoReinstall}'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _errorMessage = null;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = data['message'] ?? "Auto-recovery failed.";
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = "Network error while triggering reinstall.";
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
