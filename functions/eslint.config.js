// ESLint 9+ "flat config" — Cloud Functions kod denetimi.
//
// NEDEN BU BİÇİM: proje kurulduğunda ESLint 8 çağındaki `.eslintrc` biçimi
// yaygındı; ESLint 9'dan itibaren varsayılan `eslint.config.js`. 2026-08-15
// denetiminde ortaya çıktı ki depoda HİÇBİR lint yapılandırması yoktu —
// yani `functions/` hiç denetlenmiyordu. Bu dosya o boşluğu kapatır.
//
// Çalıştırma: `npm --prefix functions run lint`
// Deploy öncesi otomatik: firebase.json → functions.predeploy

const js = require("@eslint/js");
const globals = require("globals");

module.exports = [
  {
    // Denetim dışı: bağımlılıklar ve üretilmiş dosyalar.
    ignores: ["node_modules/**", "coverage/**"],
  },
  js.configs.recommended,
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
      globals: {
        ...globals.node,
      },
    },
    rules: {
      // ── Gerçek hata yakalayanlar (uyarı değil, HATA) ──────────────────
      "no-undef": "error",

      // Kullanılmayan değişkenler UYARI (hata değil).
      //
      // İlk çalıştırmada 5 ölü tanım buldu: `AUTO_COMPLETE_DAYS`,
      // `DISPUTE_REASON_TR`, `MAX_OPEN_STAFF_NEEDS`, `postSystemMessage`,
      // `jobChatDocs`. Hepsi UI'dan kaldırılan iş akışından kalma
      // (bkz. vault → Bilinen-Tuzaklar → "CF çalışmıyor, log boş").
      //
      // Temizlenmeleri gerekir ama yayın öncesi DEĞİL: 5.000 satırlık para ve
      // güvenlik dosyasında silme yapmak, kazancı sıfır olan bir risktir.
      // "warn" seviyesi görünür tutar ama `predeploy` hook'unu düşürmez.
      //
      // `caughtErrors: "none"`: `catch (e)` içinde `e` kullanılmayan bloklar
      // bilinçlidir (hata yutuluyor, sebebi yorumda yazıyor).
      "no-unused-vars": ["warn", {
        argsIgnorePattern: "^_",
        caughtErrors: "none",
      }],
      // `if (x = 1)` gibi atama/karşılaştırma karışıklığı.
      "no-cond-assign": ["error", "always"],
      // Aynı anahtarın iki kez yazılması (Firestore patch'lerinde sinsi).
      "no-dupe-keys": "error",
      "no-unreachable": "error",

      // ── Biçim (mevcut dosyanın stiline uygun) ─────────────────────────
      "quotes": ["error", "double", {allowTemplateLiterals: true}],
      "semi": ["error", "always"],
      "comma-dangle": ["error", "always-multiline"],
      // Satır uzunluğu UYARI: mevcut dosyada 27 uzun satır var ve hiçbiri
      // kusur değil. "error" olsaydı `predeploy` hook'u HER deploy'u
      // düşürürdü — kapı, geçmesi gereken şeyi de durdurursa kapatılır.
      // Yeni kod için yol gösterici olarak kalır.
      "max-len": ["warn", {
        code: 80,
        // URL ve uzun regex satırlarını kesmek okunabilirliği düşürür.
        ignoreUrls: true,
        ignoreRegExpLiterals: true,
        ignoreTemplateLiterals: true,
      }],
      "object-curly-spacing": ["error", "never"],

      // `indent` BİLEREK KAPALI.
      //
      // index.js Google JS stiliyle yazılmış: devam satırlarında 4 boşluk
      // girinti (`onCall(\n    {...}`). ESLint'in varsayılan `indent` kuralı
      // bunu 2 boşluğa zorlar ve 3.100'den fazla "hata" üretir. `--fix` ile
      // düzeltmek 5.000 satırlık PARA ve GÜVENLİK dosyasını baştan sona
      // yeniden biçimlendirmek demektir — yayın öncesi alınacak en kötü risk,
      // üstelik tek bir gerçek kusur bulmadan.
      //
      // Girintiyi denetlemek isteniyorsa: yayın sonrası, ayrı bir commit'te,
      // `npm run lint:fix` + tam regresyon testi ile yapılmalı.
      "indent": "off",
    },
  },
];
