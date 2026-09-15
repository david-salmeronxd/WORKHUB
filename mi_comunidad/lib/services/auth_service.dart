import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';

enum UserRole { user, admin }

class UserModel {
  final String id;
  final String username;
  final UserRole role;

  UserModel({required this.id, required this.username, required this.role});
}

class AuthService {
  static bool lastRequestTimedOut = false;
  // Notificador del usuario actual iniciado sesión
  static final ValueNotifier<UserModel?> currentUserNotifier =
      ValueNotifier<UserModel?>(null);

  static Future<bool> login(String email, String password) async {
    lastRequestTimedOut = false;
    try {
      final response = await ApiClient.request('POST', '/auth/login', body: {'email': email, 'password': password});
      ApiClient.token = response['token'] as String?;
      final user = response['data'] as Map<String, dynamic>;
      currentUserNotifier.value = UserModel(
        id: user['id'].toString(),
        username: user['email'] as String,
        role: user['isAdmin'] == true ? UserRole.admin : UserRole.user,
      );
      return true;
    } on TimeoutException {
      lastRequestTimedOut = true;
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> register(String email, String password, String firstName) async {
    lastRequestTimedOut = false;
    try {
      final response = await ApiClient.request('POST', '/auth/register', body: {'email': email, 'password': password, 'firstName': firstName});
      ApiClient.token = response['token'] as String?;
      final user = response['data'] as Map<String, dynamic>;
      currentUserNotifier.value = UserModel(
        id: user['id'].toString(),
        username: user['email'] as String,
        role: user['isAdmin'] == true ? UserRole.admin : UserRole.user,
      );
      return true;
    } on TimeoutException {
      lastRequestTimedOut = true;
      return false;
    } catch (_) {
      return false;
    }
  }

  // Cerrar Sesión
  static void logout() {
    ApiClient.token = null;
    currentUserNotifier.value = null;
  }

  // Saber si es Admin
  static bool isAdmin() {
    return currentUserNotifier.value?.role == UserRole.admin;
  }
}