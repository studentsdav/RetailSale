import 'package:flutter/material.dart';

import '../../core/auth/token_storage.dart';
import '../../models/auth/user_model.dart';

class UserController extends ChangeNotifier {
  UserModel? currentUser;

  bool get isLoggedIn => currentUser != null;

  void setUser(UserModel user) {
    currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    currentUser = null;
    notifyListeners();
  }

  // Optional: load user from token or storage later
  Future<void> clearUser() async {
    currentUser = null;
    notifyListeners();
  }
}
