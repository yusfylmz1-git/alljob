Claude:
1-Usta modu açıldığında yada mağaza ilk açılışta eğer telefon numarası eklemediyse zorunlu olarak eklesin. Hatta bölge ve en az bir meslek seçimi yapsın. mağaza açarkende eğer telefon eklenmemişse telefon istensin. ayrıca kategori seçimi en az 1 olsun.
2- Usta veya Mağaza açmak isteyen kişiler telefon numrası doğrulaması yapması zorunlu olacak. Eğer telefon doğrulaması yapmazsa kaydetmesin.
3- Eğer telefon numrası doğrulanmış kişi ise mesajlarda profil fotosnun yanında whatsapp iconuda çıksın ve tıklanınca direk whatsapp a bağlansın.
4-Mağaza da kategori seçimlerini elden geçirelim. Olası Mağaza senaryoları için çeşitlendirelim. Ayrıca profilde görünen satış kategorileri çok fazla olduğunda profil de kötü bir görünüm oluyor. bunu da düzeltelim.

---

## ✅ TAMAMLANDI — 2026-08-14

Dördü de uygulandı. `flutter analyze` temiz · 686 test geçiyor ·
regresyon testi: `test/saglayici_telefon_kapisi_test.dart` (13 test).

| # | Durum | Nerede |
|---|---|---|
| 1 | ✅ | `lib/features/auth/application/provider_phone_gate.dart` (yeni ortak kapı) — usta + mağaza kaydında telefon zorunlu. Meslek/bölge/kategori zorunluluğu zaten vardı. |
| 2 | ✅ | Aynı kapı: `phoneVerified` false → **kaydetmez**, doğrulama sayfası açılır. |
| 3 | ✅ | `chat_screen.dart` → `_WhatsappAction` (AppBar). `wa.me` bağlantısı. |
| 4 | ✅ | `product_category.dart` 14→28 kategori · `lib/core/widgets/collapsible_chips.dart` (+N daha) |

### Kararlar / dikkat

- **WhatsApp ikonu iki koşul ister:** `phoneVerified` **ve** `publicPhone`
  dolu. Hassas `phoneNumber` alanı kullanılmaz — kullanıcının profilinde
  yayınlamadığı numarayı sohbette göstermek gizlilik sızıntısı olurdu.
  Yani numarasını doğrulamış ama "profilimde görünmesin" demiş kişide ikon
  ÇIKMAZ. (Doğrulama sonrası çıkan rıza sayfasında "göster" seçilirse çıkar.)
- **Eski kategori kodları değişmedi** (CLAUDE.md kural 6). Yalnız yeni kod
  eklendi; mevcut ürünlerin kategorisi kopmaz.
- **Mevcut sağlayıcılar etkilenmez:** kapı yalnız KAYIT anında çalışır,
  zaten doğrulanmış kullanıcıda sessizce geçer.

### ⚠️ Ayrı konu: 11 kırık test devralındı

Bu oturumun işi değil. `profile_screen.dart` bu oturumdan ÖNCE yeniden
yazılmış (+689/−270) ve kaynak-metin tarayan testler eski dizgileri arıyor
(`otherModeUnreadProvider`, `label: 'İlanlarım'`). Ayrıntı ve karar
sorusu: `ILERLEME_NOTLARI.md` → "Son Durum".
