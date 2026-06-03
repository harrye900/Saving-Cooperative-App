import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://ajosave-backend.onrender.com/api';
  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() => _storage.read(key: 'token');
  static Future<void> setToken(String token) => _storage.write(key: 'token', value: token);
  static Future<void> clearToken() => _storage.delete(key: 'token');

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: await _headers(), body: jsonEncode(body));
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> put(String path, [Map<String, dynamic>? body]) async {
    final res = await http.put(Uri.parse('$baseUrl$path'), headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    return _handleResponse(res);
  }

  static Map<String, dynamic> _handleResponse(http.Response res) {
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data is List ? {'data': data} : data;
    }
    throw Exception(data['message'] ?? 'Request failed');
  }

  static Future<List<dynamic>> getList(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception('Request failed');
  }
}
