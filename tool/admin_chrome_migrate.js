'use strict';
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'lib', 'features', 'admin', 'presentation');
const skip = new Set([
  'admin_app.dart',
  'admin_chrome.dart',
  'admin_dashboard_screen.dart',
  'paged_footer.dart',
]);

for (const f of fs.readdirSync(dir)) {
  if (!f.endsWith('.dart') || skip.has(f)) continue;
  const fp = path.join(dir, f);
  let s = fs.readFileSync(fp, 'utf8');
  if (!s.includes('GradientAppBar')) {
    console.log('skip (no GradientAppBar)', f);
    continue;
  }
  const orig = s;

  s = s.replace(/import '[^']*gradient_app_bar\.dart';\r?\n/g, '');
  if (!s.includes("admin_chrome.dart")) {
    if (s.includes("package:flutter_riverpod/flutter_riverpod.dart")) {
      s = s.replace(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\n",
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'admin_chrome.dart';\n",
      );
    } else {
      s = s.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'admin_chrome.dart';\n",
      );
    }
  }

  // Remove standalone logout action buttons (shell has logout).
  s = s.replace(
    /\n\s*IconButton\(\s*\n\s*tooltip: 'Çıkış',\s*\n\s*icon: const Icon\(Icons\.logout_rounded\),\s*\n\s*onPressed: \(\) =>\s*\n\s*ref\.read\(authControllerProvider\.notifier\)\.signOut\(\),\s*\n\s*\),/g,
    '',
  );

  s = s.replace(
    /appBar:\s*const GradientAppBar\(/g,
    'appBar: AdminChrome.pageHeader(\n        context: context,',
  );
  s = s.replace(
    /appBar:\s*GradientAppBar\(/g,
    'appBar: AdminChrome.pageHeader(\n        context: context,',
  );

  s = s.replace(
    /return Scaffold\(\n(\s*)appBar: AdminChrome/g,
    'return Scaffold(\n$1backgroundColor: AdminChrome.surface,\n$1appBar: AdminChrome',
  );

  if (s !== orig) {
    fs.writeFileSync(fp, s);
    console.log('updated', f);
  } else {
    console.log('unchanged', f);
  }
}
