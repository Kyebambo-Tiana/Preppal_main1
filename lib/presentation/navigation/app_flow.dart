import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prepal2/presentation/providers/business_provider.dart';
import 'package:prepal2/presentation/screens/auth/business_details_screen.dart';
import 'package:prepal2/presentation/screens/auth/inventory_details_screen.dart';
import 'package:prepal2/presentation/screens/main_shell.dart';

class AppFlow {
  static const String _kAuthUserKey = 'auth_user';
  static const String _kInventoryOnboardingCompleted =
      'inventory_onboarding_completed';

  static Future<Widget> nextScreenAfterAuth(BuildContext context) async {
    final businessProvider = context.read<BusinessProvider>();
    await businessProvider.loadBusinesses();

    if (!businessProvider.hasBusiness) {
      return const BusinessDetailsScreen();
    }

    final prefs = await SharedPreferences.getInstance();
    final inventoryDone =
        prefs.getBool(_scopedPrefsKey(_kInventoryOnboardingCompleted, prefs)) ??
        prefs.getBool(_kInventoryOnboardingCompleted) ??
        false;

    return inventoryDone ? const MainShell() : const InventoryDetailsScreen();
  }

  static String _scopedPrefsKey(String baseKey, SharedPreferences prefs) {
    final rawUser = prefs.getString(_kAuthUserKey);
    if (rawUser == null || rawUser.isEmpty) return baseKey;

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        final userId = decoded['id'] as String?;
        if (userId != null && userId.trim().isNotEmpty) {
          return '${baseKey}_${userId.trim()}';
        }
      }
    } catch (_) {
      // Ignore malformed cached auth payloads.
    }

    return baseKey;
  }
}
