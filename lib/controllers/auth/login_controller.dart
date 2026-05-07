import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';

class LoginController extends ChangeNotifier {
  bool loading = false;
  String? error;

  Future<LoginResult?> login(
      String user, String pass, String role, String outlet) async {
    try {
      loading = true;
      error = null;
      notifyListeners();

      final result = await AuthService.login(user, pass, role, outlet);

      loading = false;
      notifyListeners();

      return result;
    } catch (e) {
      loading = false;

      error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();

      return null;
    }
  }
}
