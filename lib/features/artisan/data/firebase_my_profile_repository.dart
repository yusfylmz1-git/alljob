import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/artisan_profile.dart';
import 'my_profile_repository.dart';

/// Firestore `artisanProfiles/{uid}` ile çalışan [MyProfileRepository].
///
/// displayName ve profil fotoğrafı, listeleme sırasında ekstra okuma yapmamak
/// için profil dökümanına DENORMALIZE edilir (users ile birlikte tutulur).
/// Puanlama alanları (averageRating/totalReviews) burada YAZILMAZ — onlar
/// Cloud Functions'a aittir (PRD §5); kayıt sırasında merge ile korunur.
class FirebaseMyProfileRepository implements MyProfileRepository {
  FirebaseMyProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      _db.collection('artisanProfiles').doc(uid);

  @override
  Future<ArtisanProfile> getMyProfile(String uid) async {
    final snap = await _profileDoc(uid).get();
    if (snap.exists && snap.data() != null) {
      return ArtisanProfile.fromMap(uid, snap.data()!);
    }
    return ArtisanProfile.initial(uid);
  }

  @override
  Future<void> saveMyProfile({
    required String uid,
    required String displayName,
    String? profilePhotoUrl,
    required ArtisanProfile profile,
  }) async {
    // Profil alanları + denormalize edilmiş ad/foto. Puanlama alanlarını
    // ezmemek için toMap içindeki rating alanlarını çıkarıp merge ediyoruz.
    final data = Map<String, dynamic>.from(profile.toMap())
      ..remove('averageRating')
      ..remove('totalReviews')
      ..remove('totalRatingSum')
      ..['displayName'] = displayName
      ..['profilePhotoURL'] = profilePhotoUrl;

    await _profileDoc(uid).set(data, SetOptions(merge: true));

    // users dökümanındaki görünen ad/foto da güncel kalsın.
    await _db.collection('users').doc(uid).set({
      'displayName': displayName,
      'profilePhotoURL': profilePhotoUrl,
    }, SetOptions(merge: true));
  }
}
