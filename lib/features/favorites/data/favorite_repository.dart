import '../../../data/models/favorite.dart';

/// Favori usta verisi soyutlaması (#14). Döküman ID'si deterministiktir
/// ([Favorite.idFor]) — her müşteri-usta çifti için tek kayıt.
abstract interface class FavoriteRepository {
  /// Favoriyi ekler/çıkarır. Yeni durumu (favoride mi?) döner.
  Future<bool> toggle(Favorite favorite);

  /// Müşterinin takip ettiği ustalar — canlı akış, en yeni en üstte.
  Stream<List<Favorite>> watchFavorites(String customerUid);

  /// Ustayı takip eden müşteriler ("Sizi Takip Edenler") — en yeni en üstte.
  /// Eski kayıtlarda müşteri adı yoksa `users` dökümanından tamamlanır.
  Stream<List<Favorite>> watchFollowers(String artisanUid);

  Future<bool> isFavorite({
    required String customerUid,
    required String artisanUid,
  });
}
