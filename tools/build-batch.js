'use strict';
// 使い方: node tools/build-batch.js <batch名> [開始question_no]
//   例:   node tools/build-batch.js batch-001 1
//
// 入力: tools/input/<batch名>.json
//   [{ "dom":"D1", "f":"security", "d":3,
//      "q":"問題文",
//      "c":["正答の選択肢","誤答1","誤答2","誤答3"],
//      "e":"解説(選択肢記号ではなく内容で説明すること。並べ替え後も破綻しないように)" }, ...]
//   "f" は categories マスタの9分類のいずれか:
//   compute / storage / database / network / security /
//   resilience / integration / analytics_migration / cost
//
// 出力: tools/out/<batch名>.sql   (questions への INSERT 文)
//   - c[0] を正答として、ア/イ/ウ/エ の正答分布が均等になるよう毎回割り当てる

const fs = require('fs');
const path = require('path');

const batch = process.argv[2];
const startNo = parseInt(process.argv[3] || '1', 10);
if (!batch) {
  console.error('batch名を指定してください。例: node tools/build-batch.js batch-001 1');
  process.exit(1);
}

const LETTERS = ['ア', 'イ', 'ウ', 'エ'];
const inPath = path.join(__dirname, 'input', batch + '.json');
const items = JSON.parse(fs.readFileSync(inPath, 'utf8'));

function hash(s) { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0; return h; }

const counts = { 'ア': 0, 'イ': 0, 'ウ': 0, 'エ': 0 };
function pickLetter(seed) {
  const min = Math.min(...LETTERS.map(l => counts[l]));
  const cands = LETTERS.filter(l => counts[l] === min);
  const L = cands[hash(seed) % cands.length];
  counts[L]++;
  return L;
}

const q = s => "'" + String(s).replace(/'/g, "''") + "'";
const jb = obj => q(JSON.stringify(obj)) + '::jsonb';

const VALID_CATEGORIES = new Set([
  'compute', 'storage', 'database', 'network', 'security',
  'resilience', 'integration', 'analytics_migration', 'cost'
]);

let no = startNo;
const rows = items.map(item => {
  if (!Array.isArray(item.c) || item.c.length !== 4) {
    throw new Error('c は4要素の配列である必要があります: ' + JSON.stringify(item.q).slice(0, 40));
  }
  if (!VALID_CATEGORIES.has(item.f)) {
    throw new Error('f が9分類のいずれでもありません: ' + item.f + ' (' + JSON.stringify(item.q).slice(0, 40) + ')');
  }
  const correctText = item.c[0];
  const others = item.c.slice(1);
  const target = pickLetter(item.q);
  const nc = {};
  let oi = 0;
  for (const l of LETTERS) nc[l] = (l === target) ? correctText : others[oi++];
  const row = `(${q(item.dom || 'D1')}, ${q('gen-' + batch)}, ${no}, ${q(item.f)}, ${item.d || 3}, ${q(item.q)}, ${jb(nc)}, ${q(target)}, ${q(item.e)}, ${q('generated')})`;
  no++;
  return row;
});

const outDir = path.join(__dirname, 'out');
fs.mkdirSync(outDir, { recursive: true });
const head = 'insert into questions (exam_type, year, question_no, category_id, difficulty, body, choices, official_answer, explanation, source) values\n';
const outPath = path.join(outDir, batch + '.sql');
fs.writeFileSync(outPath, head + rows.join(',\n') + ';\n');

console.log('wrote', path.relative(process.cwd(), outPath), '-', rows.length, 'rows (question_no', startNo, '..', no - 1 + ')');
console.log('official_answer distribution:', JSON.stringify(counts));
