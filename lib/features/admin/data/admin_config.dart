/// Yönetici erişimi ön-yükleme (bootstrap) yapılandırması.
///
/// Bu e-postalar İLK yöneticiler içindir: kullanıcı bu adresle giriş yapıp
/// "Yönetici erişimini etkinleştir" dediğinde sunucudaki `claimAdminAccess`
/// CF `admin:true` custom claim'ini yazar. GÜVENLİK: bu liste yalnızca
/// UI görünürlüğü + bootstrap içindir; ASIL yetki kararı sunucudadır (CF aynı
/// listeyi doğrular) ve okuma izni Firestore kuralındaki `token.admin`'e bağlıdır.
/// Yani buraya bir e-posta eklemek tek başına kimseyi yönetici YAPMAZ —
/// `functions/index.js`'teki ADMIN_BOOTSTRAP_EMAILS ile eşleşmeli ve
/// kullanıcı bootstrap akışını çalıştırmalıdır.
const Set<String> kBootstrapAdminEmails = {
  'nflx.tr.avs1@gmail.com',
};

/// Verilen e-posta bootstrap listesinde mi? (Küçük harfe indirger.)
bool isBootstrapAdminEmail(String? email) =>
    email != null && kBootstrapAdminEmails.contains(email.trim().toLowerCase());
