import '../../../data/models/favorite.dart';

/// Favori usta verisi soyutlaması (#14). Döküman ID'si deterministiktir
/// ([Favorite.idFor]) — her müşteri-usta çifti için tek kayıt.
abstract interface class FavoriteRepository {
  /// Favoriyi ekler/çıkarır. Yeni durumu (favoride mi?) döner.
  Future<bool> toggle(Favorite favorite);

  /// Müşterinin favori ustaları — canlı akış, en yeni en üstte.
  Stream<List<Favorite>> watchFavorites(String customerUid);

  Future<bool> isFavorite({
    required String customerUid,
    required String artisanUid,
  });
}
