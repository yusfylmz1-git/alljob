import 'package:flutter/material.dart';

/// Uygulama genelinde tekil `ScaffoldMessenger` anahtarı.
///
/// Belirli bir `BuildContext` olmadan (ör. ön planda gelen push bildirimi)
/// SnackBar göstermek için kullanılır. `MaterialApp.router`'a bağlanır.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
