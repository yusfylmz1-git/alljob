// Yasal metinlerin statik HTML sayfalarını üretir (Firebase Hosting).
//
// Tek kaynak `lib/features/legal/legal_docs.dart`tır (saf Dart). Metin
// değişince:  dart run tool/generate_legal_html.dart
// sonra:      firebase deploy --only hosting:alljob1
//
// Çıktı: hosting/{slug}.html
// NOT: marketing `hosting/index.html` ASLA üzerine yazılmaz.
import 'dart:io';

import 'package:sepette_hizmet/features/legal/legal_docs.dart';

void main() {
  final outDir = Directory('hosting');
  outDir.createSync(recursive: true);

  final docs = [...kLegalDocs, legalDeletion];
  for (final doc in docs) {
    final file = File('${outDir.path}/${doc.slug}.html');
    file.writeAsStringSync(_page(doc));
    stdout.writeln('yazıldı: ${file.path}');
  }
  stdout.writeln(
    'Not: hosting/index.html (tanıtım) dokunulmadı — yalnız yasal sayfalar.',
  );
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

/// Marka paleti: AppColors (primary #EA580C, secondary #15304B, ink #101828).
const _style = r'''
:root {
  --bg: #fafafb;
  --card: #ffffff;
  --ink: #101828;
  --ink-2: #475467;
  --ink-3: #667085;
  --line: #e4e7ec;
  --brand: #ea580c;
  --brand-deep: #c2410c;
  --navy: #15304b;
  --soft: #ffedd5;
  color-scheme: light;
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body {
  margin: 0;
  padding: 0 0 calc(48px + env(safe-area-inset-bottom, 0px));
  font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
  background:
    radial-gradient(ellipse 90% 50% at 0% -10%, rgba(234,88,12,.08), transparent 55%),
    var(--bg);
  color: var(--ink);
  -webkit-font-smoothing: antialiased;
}
.top {
  position: sticky; top: 0; z-index: 20;
  background: rgba(250,250,251,.92);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--line);
  padding: max(10px, env(safe-area-inset-top, 0px)) 16px 10px;
}
.top-inner {
  max-width: 760px; margin: 0 auto;
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
}
.brand {
  display: inline-flex; align-items: center; gap: 10px;
  color: var(--ink); font-weight: 800; letter-spacing: -.02em;
  text-decoration: none; font-size: .98rem;
}
.brand img { width: 32px; height: 32px; object-fit: contain; border-radius: 8px; }
.back {
  display: inline-flex; align-items: center; gap: 6px;
  min-height: 40px; padding: 0 12px;
  border-radius: 999px; border: 1px solid var(--line);
  background: #fff; color: var(--ink-2); font-weight: 600; font-size: .86rem;
  text-decoration: none;
}
.back:hover { border-color: rgba(234,88,12,.35); color: var(--brand-deep); }
.wrap { max-width: 760px; margin: 0 auto; padding: 20px 16px 0; }
header h1 {
  margin: 8px 0 6px; font-size: clamp(1.45rem, 5vw, 1.75rem);
  letter-spacing: -.03em; line-height: 1.2; color: var(--navy);
}
.updated { margin: 0; font-size: .84rem; color: var(--ink-3); font-weight: 600; }
main {
  margin-top: 16px; padding: 8px 18px 22px;
  background: var(--card); border: 1px solid var(--line);
  border-radius: 16px;
  box-shadow: 0 1px 2px rgba(16,24,40,.04), 0 8px 24px rgba(16,24,40,.04);
}
main h2 {
  font-size: 1.02rem; margin: 22px 0 8px; color: var(--navy);
  letter-spacing: -.02em;
}
main p, main li { font-size: .95rem; color: var(--ink-2); }
main p { margin: 0 0 12px; }
main a { color: var(--brand-deep); font-weight: 600; text-decoration: none; }
main a:hover { text-decoration: underline; text-underline-offset: 2px; }
ul, ol { padding-left: 1.2em; margin: 8px 0 14px; }
li { margin: 6px 0; }
footer {
  max-width: 760px; margin: 22px auto 0; padding: 0 16px;
  color: var(--ink-3); font-size: .8rem; text-align: center;
}
footer a { color: var(--brand-deep); text-decoration: none; font-weight: 600; }
@media (min-width: 640px) {
  .wrap { padding: 28px 20px 0; }
  main { padding: 12px 28px 28px; border-radius: 18px; }
}
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
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#EA580C">
<title>$title — $kAppBrandName</title>
<link rel="icon" type="image/png" href="favicon.png">
<link rel="apple-touch-icon" href="assets/apple-touch-icon.png">
<style>$_style</style>
</head>
<body>
<div class="top">
  <div class="top-inner">
    <a class="brand" href="/">
      <img src="assets/logo-64.png" width="32" height="32" alt="">
      <span>$kAppBrandName</span>
    </a>
    <a class="back" href="/">← Ana sayfa</a>
  </div>
</div>
<div class="wrap">
<header>
  <h1>$title</h1>
  <p class="updated">Son güncelleme: $kLegalUpdated</p>
</header>
$content
</div>
<footer>$kAppBrandName · <a href="mailto:$kLegalContactEmail">$kLegalContactEmail</a></footer>
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
