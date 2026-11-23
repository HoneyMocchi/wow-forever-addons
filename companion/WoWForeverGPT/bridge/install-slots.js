#!/usr/bin/env node
'use strict';
// Creates the reply-slot addons and signal files that the no-reload transport needs.
// WoW only indexes addon folders and files at launch, so run this once, then restart
// the game. Safe to re-run: existing files are left alone.

const fs = require('fs');
const path = require('path');

const cfg = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));
const addons = cfg.addonDir;
const N = cfg.slots || 200;
const ACT = cfg.actMax || 60;
const PRESENCE = cfg.presenceMax || 2000;
const iface = cfg.tocInterface || '16001';

if (!fs.existsSync(path.join(addons, 'WoWForeverGPT', 'WoWForeverGPT.toc'))) {
  console.error('WoWForeverGPT addon not found under ' + addons);
  process.exit(1);
}

let made = 0, kept = 0;
function ensure(file, content) {
  if (fs.existsSync(file)) { kept++; return; }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
  made++;
}

for (let i = 1; i <= N; i++) {
  const name = 'WoWForeverGPT_S' + String(i).padStart(3, '0');
  const dir = path.join(addons, name);
  ensure(path.join(dir, name + '.toc'), [
    '## Interface: ' + iface,
    '## Title: 와우 AI 응답 슬롯 ' + String(i).padStart(3, '0'),
    '## Notes: 와우 AI 답변 수신에 사용합니다. 활성화 상태로 두세요.',
    '## LoadOnDemand: 1',
    '## Dependencies: WoWForeverGPT',
    '',
    'Inbox.lua',
    '',
  ].join('\n'));
  ensure(path.join(dir, 'Inbox.lua'), 'WoWForeverGPT_SlotData = nil\n');
  ensure(path.join(addons, 'WoWForeverGPT', 'sig', String(i).padStart(3, '0') + '.wav'), '');
  ensure(path.join(addons, 'WoWForeverGPT', 'ack', String(i).padStart(3, '0') + '.wav'), '');
  // Heartbeat files: one per agent action, flipped valid by the bridge as it works.
  for (let k = 1; k <= ACT; k++) {
    ensure(path.join(addons, 'WoWForeverGPT', 'act', String(i).padStart(3, '0'), String(k).padStart(2, '0') + '.wav'), '');
  }
}

// Presence files: the bridge flips one every 30 s so the game can show "connected".
for (let k = 1; k <= PRESENCE; k++) {
  ensure(path.join(addons, 'WoWForeverGPT', 'presence', String(k).padStart(4, '0') + '.wav'), '');
}

// Control files for the addon's self-test: one always empty, one always valid.
ensure(path.join(addons, 'WoWForeverGPT', 'ctl', 'empty.wav'), '');
ensure(path.join(addons, 'WoWForeverGPT', 'ctl', 'valid.wav'), require('./protocol').SILENT_WAV);

console.log(`응답 슬롯 ${N}개 · 새 파일 ${made}개 · 기존 파일 ${kept}개`);
if (made > 0) console.log('새 파일을 읽을 수 있도록 와우를 완전히 종료한 뒤 다시 실행하세요.');
