import 'package:flutter/material.dart';
import 'package:prepal2/core/di/service_locator.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum BusinessStatus { initial, loading, loaded, error, success }

class BusinessModel {
  final String id;
  final String userId;
  final String businessName;
  final String businessType;
  final String location;
  final String contactNumber;
  final String website;
  final String? createdAt;

  const BusinessModel({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.businessType,
    required this.location,
    required this.contactNumber,
    required this.website,
    this.createdAt,
  });

  factory BusinessModel.fromMap(Map<String, dynamic> map) {
    return BusinessModel(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      businessType: map['businessType'] as String? ?? '',
      location: map['location'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      website: map['website'] as String? ?? '',
      createdAt: map['createdAt'] as String?,
    );
  }
}

class BusinessProvider extends ChangeNotifier {
  static const String _kCachedBusinesses = 'cached_businesses';
  static const String _kCachedCurrentBusinessId = 'cached_current_business_id';
  static const String _kAuthUserKey = 'auth_user';

  BusinessStatus _status = BusinessStatus.initial;
  String? _errorMessage;
  BusinessModel? _currentBusiness;
  List<BusinessModel> _businesses = [];

  BusinessProvider() {
    _hydrateFromCache();
  }

  BusinessStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == BusinessStatus.loading;
  BusinessModel? get currentBusiness => _currentBusiness;
  List<BusinessModel> get businesses => _businesses;
  bool get hasBusiness => _currentBusiness != null;

  String _scopedKey(String baseKey, String userId) => '${baseKey}_$userId';

  Future<String?> _currentUserId([SharedPreferences? prefs]) async {
    final preferences = prefs ?? await SharedPreferences.getInstance();
    final rawUser = preferences.getString(_kAuthUserKey);
    if (rawUser == null || rawUser.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        final id = decoded['id'] as String?;
        if (id != null && id.trim().isNotEmpty) {
          return id.trim();
        }
      }
    } catch (_) {
      // Ignore malformed cached auth payloads.
    }

    return null;
  }

  Future<void> _syncCurrentBusinessToApiClient() async {
    final business = _currentBusiness;
    if (business == null || business.id.isEmpty) return;

    await serviceLocator.apiClient.setBusinessId(business.id);
    if (business.businessType.trim().isNotEmpty) {
      await serviceLocator.apiClient.setBusinessType(business.businessType);
    }
  }

  Future<void> _hydrateFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _currentUserId(prefs);
      final businessesKey = userId == null
          ? _kCachedBusinesses
          : _scopedKey(_kCachedBusinesses, userId);
      final currentBusinessKey = userId == null
          ? _kCachedCurrentBusinessId
          : _scopedKey(_kCachedCurrentBusinessId, userId);

      final raw =
          prefs.getString(businessesKey) ?? prefs.getString(_kCachedBusinesses);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final cached = decoded
          .whereType<Map<String, dynamic>>()
          .map(BusinessModel.fromMap)
          .where((b) => b.id.isNotEmpty)
          .toList(growable: false);

      if (cached.isEmpty) return;

      _businesses = cached;

      final preferredId =
          prefs.getString(currentBusinessKey) ??
          prefs.getString(_kCachedCurrentBusinessId);
      _currentBusiness = preferredId == null
          ? cached.first
          : cached.firstWhere(
              (b) => b.id == preferredId,
              orElse: () => cached.first,
            );

      await _syncCurrentBusinessToApiClient();
      _status = BusinessStatus.loaded;
      notifyListeners();
    } catch (_) {
      // Ignore cache parse issues and continue with remote source.
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final businessesKey = userId == null
        ? _kCachedBusinesses
        : _scopedKey(_kCachedBusinesses, userId);
    final currentBusinessKey = userId == null
        ? _kCachedCurrentBusinessId
        : _scopedKey(_kCachedCurrentBusinessId, userId);
    final payload = _businesses
        .map(
          (b) => {
            'id': b.id,
            'userId': b.userId,
            'businessName': b.businessName,
            'businessType': b.businessType,
            'location': b.location,
            'contactNumber': b.contactNumber,
            'website': b.website,
            'createdAt': b.createdAt,
          },
        )
        .toList(growable: false);

    await prefs.setString(businessesKey, jsonEncode(payload));

    if (_currentBusiness != null && _currentBusiness!.id.isNotEmpty) {
      await prefs.setString(currentBusinessKey, _currentBusiness!.id);
    }

    await _syncCurrentBusinessToApiClient();
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    if (userId != null) {
      await prefs.remove(_scopedKey(_kCachedBusinesses, userId));
      await prefs.remove(_scopedKey(_kCachedCurrentBusinessId, userId));
    }
    await prefs.remove(_kCachedBusinesses);
    await prefs.remove(_kCachedCurrentBusinessId);
  }

  // ── Load all businesses on app start ───────────────────────
  Future<void> loadBusinesses() async {
    if (_businesses.isEmpty) {
      await _hydrateFromCache();
    }

    _status = BusinessStatus.loading;
    notifyListeners();

    try {
      final ds = serviceLocator.businessRemoteDataSource;
      final list = await ds.getAllBusinesses();
      final remoteBusinesses = list
          .map((m) => BusinessModel.fromMap(m))
          .toList();

      if (remoteBusinesses.isNotEmpty) {
        _businesses = remoteBusinesses;
        _currentBusiness = _businesses.first;
        await _saveCache();
      } else if (_businesses.isEmpty) {
        _currentBusiness = null;
      }

      await _syncCurrentBusinessToApiClient();
      _status = BusinessStatus.loaded;
    } catch (e) {
      // Keep any cached businesses on network failure.
      if (_businesses.isEmpty) {
        _currentBusiness = null;
      }
      _status = BusinessStatus.loaded;
    }

    notifyListeners();
  }

  // ── Create business (BusinessDetailsScreen) ─────────────────
  Future<bool> registerBusiness({
    required String businessName,
    required String businessType,
    required String location,
    // contactNumber and website kept for UI compatibility
    // but API only accepts: businessName, businessType, location
    String? contactNumber,
    String? contactAddress,
    String? website,
  }) async {
    _status = BusinessStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final ds = serviceLocator.businessRemoteDataSource;
      final hasExistingBusiness =
          _currentBusiness != null && _currentBusiness!.id.isNotEmpty;

      final result = hasExistingBusiness
          ? await ds.updateBusiness(
              id: _currentBusiness!.id,
              updates: {
                'businessName': businessName,
                'businessType': businessType,
                'location': location,
              },
            )
          : await ds.createBusiness(
              businessName: businessName,
              businessType: businessType,
              location: location,
            );

      final mergedBusiness = <String, dynamic>{
        ...result,
        'contactNumber': contactNumber?.trim() ?? '',
        'website': website?.trim() ?? '',
      };

      _currentBusiness = BusinessModel.fromMap(mergedBusiness);
      final existingIndex = _businesses.indexWhere(
        (b) => b.id == _currentBusiness!.id,
      );
      if (existingIndex == -1) {
        _businesses.insert(0, _currentBusiness!);
      } else {
        _businesses[existingIndex] = _currentBusiness!;
      }

      await _saveCache();

      _status = BusinessStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      _status = BusinessStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> reset({bool clearCache = false}) async {
    _status = BusinessStatus.initial;
    _errorMessage = null;
    _currentBusiness = null;
    _businesses = [];
    if (clearCache) {
      await _clearCache();
    } else {
      await _hydrateFromCache();
      return;
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '');
}
