import 'package:flutter/material.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  Future<bool> checkAuth() async {
    final token = await ApiService.getToken();
    if (token == null) return false;
    try {
      _user = await ApiService.get('/auth/profile');
      notifyListeners();
      return true;
    } catch (_) {
      await ApiService.clearToken();
      return false;
    }
  }

  Future<void> register(String name, String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.post('/auth/register', {'name': name, 'phone': phone, 'password': password});
      await ApiService.setToken(res['token']);
      _user = res['user'];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.post('/auth/login', {'phone': phone, 'password': password});
      await ApiService.setToken(res['token']);
      _user = res['user'];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPin(String pin) async {
    await ApiService.post('/auth/set-pin', {'pin': pin});
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }
}
