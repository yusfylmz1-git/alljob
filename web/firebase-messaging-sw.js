// Ustasından — Web push için servis çalışanı (service worker).
//
// Uygulama arka plandayken/kapalıyken gelen FCM bildirimlerini gösterir.
// Dosya adı SABİTTİR: firebase-messaging-sw.js (kök dizinde). firebase_messaging
// web eklentisi bu dosyayı otomatik kaydeder.
//
// NOT: compat SDK importScripts ile yüklenir (service worker'da ES modülü yok).
// Ayarlar lib/firebase_options.dart → DefaultFirebaseOptions.web ile aynıdır.

importScripts(
  "https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyBlyPJ9R_V7eIv6c7jrtSyKdxIltGbnq00",
  appId: "1:839781526307:web:af2928409fc356089aba96",
  messagingSenderId: "839781526307",
  projectId: "alljob1",
  authDomain: "alljob1.firebaseapp.com",
  storageBucket: "alljob1.firebasestorage.app",
});

// messaging örneğini al → arka plan bildirimlerini otomatik gösterir.
firebase.messaging();
