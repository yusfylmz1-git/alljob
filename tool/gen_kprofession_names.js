'use strict';
const fs = require('fs');
const p = require('../assets/data/professions.json');
const lines = p.map(
    (x) => `  '${x.code}': '${String(x.nameTR).replace(/'/g, "\\'")}',`,
);
lines.push(`  'quick_support': 'Hızlı Destek',`);
const out =
    `/// Meslek/kategori kodu → Türkçe ad. professions.json ile senkron tut.\n` +
    `/// \`quick_support\` yalnızca İLAN kategorisidir (usta mesleği değil).\n` +
    `const kProfessionNames = <String, String>{\n${lines.join('\n')}\n};\n`;
fs.writeFileSync('tool/_kprof.txt', out);
console.log('codes', lines.length);
