import 'package:flutter/material.dart';

enum UserRole { user, admin }

class UserModel {
  final String id;
  final String username;
  final UserRole role;

  UserModel({required this.id, required this.username, required this.role});
}

class AuthService {
  // Notificador del usuario actual iniciado sesión
  static final ValueNotifier<UserModel?> currentUserNotifier =
      ValueNotifier<UserModel?>(null);

  // Usuarios simulados (puedes cambiarlos)
  static final List<Map<String, dynamic>> _usersDB = [
    {
      'username': 'admin',
      'password': '123',
      'role': UserRole.admin,
    },
    {
      'username': 'hazael',
      'password': '123',
      'role': UserRole.user,
    },
  ];

  // Función de Login
  static bool login(String username, String password) {
    final user = _usersDB.firstWhere(
      (u) => u['username'] == username && u['password'] == password,
      orElse: () => {},
    );

    if (user.isNotEmpty) {
      currentUserNotifier.value = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: user['username'],
        role: user['role'],
      );
      return true;
    }
    return false;
  }

  // Cerrar Sesión
  static void logout() {
    currentUserNotifier.value = null;
  }

  // Saber si es Admin
  static bool isAdmin() {
    return currentUserNotifier.value?.role == UserRole.admin;
  }
}