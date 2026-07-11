// Yasal metinlerin statik HTML sayfalarını üretir (Firebase Hosting).
//
// Tek kaynak `lib/features/legal/legal_docs.dart`tır (saf Dart). Metin
// değişince:  dart run tool/generate_legal_html.dart
// sonra:      firebase deploy --only hosting
//
// Çıktı: hosting/{slug}.html (+ index.html). Üretilen dosyalar commit'lenir.
import 'dart:io';

import 'package:usta_cepte/features/legal/legal_docs.dart';

void main() {
  final outDir = Directory('hosting');
  outDir.createSync(recursive: true);

  final docs = [...kLegalDocs, legalDeletion];
  for (final doc in docs) {
    final file = File('${outDir.path}/${doc.slug}.html');
    file.writeAsStringSync(_page(doc));
    stdout.writeln('yazıldı: ${file.path}');
  }

  final index = File('${outDir.path}/index.html');
  index.writeAsStringSync(_indexPage(docs));
  stdout.writeln('yazıldı: ${index.path}');
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Kaçışlanmış metindeki URL ve e-postaları tıklanabilir yapar.
String _linkify(String escaped) => escaped
    .replaceAllMapped(
      RegExp(r'https?://[^\s<]+'),
      (m) => '<a href="${m[0]}">${m[0]}</a>',
    )
    .replaceAllMapped(
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
      (m) => '<a href="mailto:${m[0]}">${m[0]}</a>',
    );

String _body(String body) {
  final paragraphs = body.split('\n\n');
  final buf = StringBuffer();
  for (final p in paragraphs) {
    final lines = p.split('\n');
    // Tamamı madde işaretli veya numaralı satırlarsa liste olarak bas.
    final isBullets = lines.every((l) => l.startsWith('• '));
    final isNumbered = lines.every((l) => RegExp(r'^\d+\. ').hasMatch(l));
    if (isBullets || isNumbered) {
      buf.writeln(isNumbered ? '<ol>' : '<ul>');
      for (final l in lines) {
        final text = isNumbered
            ? l.replaceFirst(RegExp(r'^\d+\. '), '')
            : l.substring(2);
        buf.writeln('  <li>${_linkify(_esc(text))}</li>');
      }
      buf.writeln(isNumbered ? '</ol>' : '</ul>');
    } else {
      buf.writeln('<p>${_linkify(_esc(p)).replaceAll('\n', '<br>')}</p>');
    }
  }
  return buf.toString();
}

const _style = '''
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body {
  margin: 0; padding: 0 20px 64px;
  font: 16px/1.6 -apple-system, "Segoe UI", Roboto, Ubuntu, sans-serif;
  background: #f7f7f9; color: #1d2733;
}
@media (prefers-color-scheme: dark) {
  body { background: #12161c; color: #e6e9ee; }
  header p, .updated, footer { color: #98a2b3 !important; }
  main { background: #1a2029 !important; border-color: #2a3341 !important; }
  a { color: #7fb2ff; }
}
header { max-width: 760px; margin: 0 auto; padding: 36px 0 16px; }
header h1 { margin: 0 0 4px; font-size: 26px; }
header .brand { font-weight: 800; color: #e8611a; letter-spacing: .2px; }
header p { margin: 0; color: #5b6675; }
.updated { font-size: 13px; color: #5b6675; margin-top: 6px; }
main {
  max-width: 760px; margin: 16px auto 0; padding: 8px 28px 28px;
  background: #fff; border: 1px solid #e4e7ec; border-radius: 14px;
}
main h2 { font-size: 17px; margin: 26px 0 8px; }
main p, main li { font-size: 15px; }
a { color: #0b57d0; text-decoration: none; }
a:hover { text-decoration: underline; }
footer {
  max-width: 760px; margin: 24px auto 0; color: #5b6675; font-size: 13px;
  text-align: center;
}
ul, ol { padding-left: 22px; margin: 8px 0; }
li { margin: 4px 0; }
''';

String _shell({
  required String title,
  required String content,
}) =>
    '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title — Usta Cepte</title>
<style>$_style</style>
</head>
<body>
<header>
  <div class="brand">Usta Cepte</div>
  <h1>$title</h1>
  <p class="updated">Son güncelleme: $kLegalUpdated</p>
</header>
$content
<footer>Usta Cepte · İletişim: <a href="mailto:$kLegalContactEmail">$kLegalContactEmail</a></footer>
</body>
</html>
''';

String _page(LegalDoc doc) {
  final buf = StringBuffer('<main>\n');
  for (final s in doc.sections) {
    if (s.heading != null) buf.writeln('<h2>${_esc(s.heading!)}</h2>');
    buf.write(_body(s.body));
  }
  buf.writeln('</main>');
  return _shell(title: doc.title, content: buf.toString());
}

String _indexPage(List<LegalDoc> docs) {
  final buf = StringBuffer('<main>\n<p>Yasal metinlerimiz:</p>\n<ul>\n');
  for (final d in docs) {
    buf.writeln('  <li><a href="${d.slug}.html">${_esc(d.title)}</a></li>');
  }
  buf.writeln('</ul>\n</main>');
  return _shell(
    title: 'Yasal Metinler',
    content: buf.toString(),
  );
}
