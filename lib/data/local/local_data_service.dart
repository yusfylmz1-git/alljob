import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../models/geo_models.dart';
import '../models/profession.dart';

/// Coğrafi ve meslek verilerini uygulama paketindeki statik JSON
/// assetlerinden okur (PRD §5). Veriler bir kez yüklenip bellekte tutulur,
/// Firebase'e sorgu atılmaz.
class LocalDataService {
  List<Province>? _provinces;
  List<District>? _districts;
  List<Neighborhood>? _neighborhoods;
  List<Profession>? _professions;

  Future<List<dynamic>> _loadJsonArray(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<List<Province>> getProvinces() async {
    if (_provinces != null) return _provinces!;
    final list = await _loadJsonArray(AppConstants.provincesAsset);
    _provinces = list
        .map((e) => Province.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return _provinces!;
  }

  Future<List<District>> _allDistricts() async {
    if (_districts != null) return _districts!;
    final list = await _loadJsonArray(AppConstants.districtsAsset);
    _districts = list
        .map((e) => District.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _districts!;
  }

  Future<List<Neighborhood>> _allNeighborhoods() async {
    if (_neighborhoods != null) return _neighborhoods!;
    final list = await _loadJsonArray(AppConstants.neighborhoodsAsset);
    _neighborhoods = list
        .map((e) => Neighborhood.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _neighborhoods!;
  }

  /// Seçilen ilin ilçelerini verir (kademeli dropdown için).
  Future<List<District>> getDistricts(String provinceId) async {
    final all = await _allDistricts();
    return all.where((d) => d.provinceId == provinceId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Seçilen ilçenin mahallelerini verir.
  Future<List<Neighborhood>> getNeighborhoods(String districtId) async {
    final all = await _allNeighborhoods();
    return all.where((n) => n.districtId == districtId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<Profession>> getProfessions() async {
    if (_professions != null) return _professions!;
    final list = await _loadJsonArray(AppConstants.professionsAsset);
    _professions = list
        .map((e) => Profession.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _professions!;
  }

  Future<Profession?> professionByCode(String code) async {
    final all = await getProfessions();
    for (final p in all) {
      if (p.code == code) return p;
    }
    return null;
  }
}

// ---- Riverpod providers ----

final localDataServiceProvider = Provider<LocalDataService>((ref) {
  return LocalDataService();
});

final provincesProvider = FutureProvider<List<Province>>((ref) {
  return ref.watch(localDataServiceProvider).getProvinces();
});

final professionsProvider = FutureProvider<List<Profession>>((ref) {
  return ref.watch(localDataServiceProvider).getProfessions();
});

/// Belirli bir ilin ilçeleri (family — il ID'sine göre).
final districtsProvider =
    FutureProvider.family<List<District>, String>((ref, provinceId) {
  return ref.watch(localDataServiceProvider).getDistricts(provinceId);
});

/// Belirli bir ilçenin mahalleleri (family — ilçe ID'sine göre).
final neighborhoodsProvider =
    FutureProvider.family<List<Neighborhood>, String>((ref, districtId) {
  return ref.watch(localDataServiceProvider).getNeighborhoods(districtId);
});
