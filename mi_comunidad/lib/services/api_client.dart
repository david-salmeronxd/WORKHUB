import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://us-central1-workhub-4561e.cloudfunctions.net/api',
  );
  static const Duration requestTimeout = Duration(seconds: 5);
  static String? token;

  static Future<Map<String, dynamic>> request(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await http.get(uri, headers: headers).timeout(requestTimeout),
      'POST' => await http.post(uri, headers: headers, body: encodedBody).timeout(requestTimeout),
      'DELETE' => await http.delete(uri, headers: headers).timeout(requestTimeout),
      _ => throw ArgumentError('Metodo HTTP no soportado'),
    };
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'Error de API (${response.statusCode})');
    }
    return decoded;
  }
}