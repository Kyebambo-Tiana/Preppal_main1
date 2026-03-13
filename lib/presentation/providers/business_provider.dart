import 'package:flutter/material.dart';
import 'package:prepal2/core/di/service_locator.dart';

enum BusinessStatus { initial, loading, loaded, error, success }

class BusinessModel {
  final String id;
  final String userId;
  final String businessName;
  final String businessType;
  final String location;
  final String? createdAt;

  const BusinessModel({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.businessType,
    required this.location,
    this.createdAt,
  });

  factory BusinessModel.fromMap(Map<String, dynamic> map) {
    return BusinessModel(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      businessType: map['businessType'] as String? ?? '',
      location: map['location'] as String? ?? '',
      createdAt: map['createdAt'] as String?,
    );
  }
}

class BusinessProvider extends ChangeNotifier {
  BusinessStatus _status = BusinessStatus.initial;
  String? _errorMessage;
  BusinessModel? _currentBusiness;
  List<BusinessModel> _businesses = [];

  BusinessStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == BusinessStatus.loading;
  BusinessModel? get currentBusiness => _currentBusiness;
  List<BusinessModel> get businesses => _businesses;
  bool get hasBusiness => _currentBusiness != null;

  // ── Load all businesses on app start ───────────────────────
  Future<void> loadBusinesses() async {
    _status = BusinessStatus.loading;
    notifyListeners();

    try {
      final ds = serviceLocator.businessRemoteDataSource;
      final list = await ds.getAllBusinesses();
      _businesses = list.map((m) => BusinessModel.fromMap(m)).toList();

      if (_businesses.isNotEmpty) {
        _currentBusiness = _businesses.first;
      }

      _status = BusinessStatus.loaded;
    } catch (e) {
      // Silently handle — user may not have a business yet
      _businesses = [];
      _currentBusiness = null;
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

      _currentBusiness = BusinessModel.fromMap(result);
      final existingIndex = _businesses.indexWhere(
        (b) => b.id == _currentBusiness!.id,
      );
      if (existingIndex == -1) {
        _businesses.insert(0, _currentBusiness!);
      } else {
        _businesses[existingIndex] = _currentBusiness!;
      }

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

  void reset() {
    _status = BusinessStatus.initial;
    _errorMessage = null;
    _currentBusiness = null;
    _businesses = [];
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '');
}
