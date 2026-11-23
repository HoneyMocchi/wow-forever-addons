#!/usr/bin/env node
'use strict';
// One-shot installer.
//
//   node setup.js [--wow "<client folder>"] [--project "<default work folder>"] [--account <name>]
//
// Finds the WoW: Forever client, copies the addon into Interface\AddOns, writes
// bridge/config.json from the example (if missing), and builds the slot pool.
// Re-running is safe: existing config and generated files are kept. A config
// still on the beta client moves to Forever once Forever is installed.
//
// An install of this project under its old name (wow-claude: the WoWClaude
// addon, WoWClaude_S### slots, WoWClaude.lua saved data) is migrated: the saved
// data is carried over so chats survive, the old folders are removed so two
// addons don't fight over /ai and /r, and config.json is brought up to date.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

if (Number(process.versions.node.split('.')[0]) < 22) {
  console.error('Node.js 22 이상을 설치한 뒤 다시 실행해 주세요.');
  process.exit(1);
}

const ROOT = __dirname;
const ADDON_SRC = path.join(ROOT, 'addon', 'WoWForeverGPT');
const BRIDGE = path.join(ROOT, 'bridge');
const CONFIG = path.join(BRIDGE, 'config.json');
const EXAMPLE = path.join(BRIDGE, 'config.example.json');
const { sameFolder } = require(path.join(BRIDGE, 'protocol.js'));

const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a.startsWith('--')) args[a.slice(2)] = process.argv[i + 1] && !process.argv[i + 1].startsWith('--') ? process.argv[++i] : true;
}

function isClient(dir) {
  try {
    if (!fs.existsSync(dir)) return false;
    const items = fs.readdirSync(dir);
    // Windows: the game exe. macOS: the .app bundle. Linux (Wine): the Wine exe.
    return items.some(f => /^Wow.*\.exe$/i.test(f) || /\.app$/i.test(f));
  } catch { return false; }
}

// The client folder an existing config.json points at.
function configuredClient() {
  try { return path.dirname(path.dirname(JSON.parse(fs.readFileSync(CONFIG, 'utf8')).addonDir)); } catch { return null; }
}

function findClient() {
  if (args.wow) {
    if (isClient(args.wow)) return path.resolve(args.wow);
    throw new Error(`--wow "${args.wow}" does not look like a WoW client folder (needs Interface\\ and a game binary)`);
  }
  // A re-run stays on its client, unless that's the beta: Forever replaced it.
  const current = configuredClient();
  if (current && isClient(current) && path.basename(current) !== '_classic_beta_') return current;
  let roots;
  if (process.platform === 'win32') {
    roots = [process.env['ProgramFiles(x86)'], process.env.ProgramFiles, 'D:\\', 'E:\\', 'D:\\Games', 'E:\\Games', 'C:\\Games', 'D:\\Game', 'E:\\Game', 'C:\\Game']
      .filter(Boolean).map(r => path.join(r, 'World of Warcraft'));
  } else if (process.platform === 'darwin') {
    roots = ['/Applications/World of Warcraft', path.join(os.homedir(), 'Applications', 'World of Warcraft')];
  } else {
    // Linux: the client lives inside a Wine prefix.
    roots = [process.env.WINEPREFIX, path.join(os.homedir(), '.wine'),
      path.join(os.homedir(), 'Games', 'battlenet')]
      .filter(Boolean).flatMap(p => ['Program Files (x86)', 'Program Files'].map(pf => path.join(p, 'drive_c', pf, 'World of Warcraft')));
  }
  if (current) roots.unshift(path.dirname(current));
  // Tests search a fake install tree and nothing else, never a real game.
  if (process.env.WOWFOREVERGPT_TEST_WOW_ROOT) roots = [process.env.WOWFOREVERGPT_TEST_WOW_ROOT];
  for (const root of roots) {
    // The beta folder can outlive the beta: Forever goes first.
    for (const flavor of ['_forever_']) {
      const dir = path.join(root, flavor);
      if (isClient(dir)) return dir;
    }
  }
  throw new Error('와우 포에버 폴더를 찾지 못했습니다. 직접 지정하세요: node setup.js --wow "<path to World of Warcraft/_forever_>"');
}

function findAccount(client) {
  const base = path.join(client, 'WTF', 'Account');
  let names = [];
  try { names = fs.readdirSync(base).filter(n => n !== 'SavedVariables' && fs.statSync(path.join(base, n)).isDirectory()); } catch {}
  if (args.account) {
    if (!names.includes(args.account)) throw new Error(`Account "${args.account}" not found under ${base}`);
    return args.account;
  }
  // The game creates this folder at the first login. Everything else can be
  // installed before that (slots must exist when the game launches); the bridge
  // finds the account by itself once it appears.
  if (!names.length) return null;
  if (names.length > 1) console.log(`Several accounts found (${names.join(', ')}); using "${names[0]}". Pass --account to choose another.`);
  return names[0];
}

function copyAddon(client) {
  const dest = path.join(client, 'Interface', 'AddOns', 'WoWForeverGPT');
  fs.mkdirSync(dest, { recursive: true });
  let copied = 0;
  for (const f of fs.readdirSync(ADDON_SRC)) {
    const target = path.join(dest, f);
    if (f === 'Inbox.lua' && fs.existsSync(target)) continue; // the bridge owns it once running
    fs.copyFileSync(path.join(ADDON_SRC, f), target);
    copied++;
  }
  return { dest, copied };
}

function savedVariablesFile(client, account) {
  return account ? path.join(client, 'WTF', 'Account', account, 'SavedVariables', 'WoWForeverGPT.lua') : '';
}

// The game exe without .exe, as the capture looks for it.
function processNameOf(client) {
  const exe = fs.readdirSync(client).find(f => /^Wow.*\.exe$/i.test(f) || /\.app$/i.test(f));
  if (!exe) return null;
  let processName = exe.replace(/\.exe$/i, '');
  // macOS: the process name is the executable inside the .app bundle, not the bundle name.
  if (process.platform === 'darwin' && exe.toLowerCase().endsWith('.app')) {
    const macosDir = path.join(client, exe, 'Contents', 'MacOS');
    try {
      const bins = fs.readdirSync(macosDir).filter(f => fs.statSync(path.join(macosDir, f)).isFile());
      if (bins.length) processName = bins[0];
    } catch {}
  }
  return processName;
}

function pointAtClient(cfg, client, account) {
  cfg.addonDir = path.join(client, 'Interface', 'AddOns');
  cfg.inboxFile = path.join(cfg.addonDir, 'WoWForeverGPT', 'Inbox.lua');
  cfg.savedVariablesFile = savedVariablesFile(client, account);
  const processName = processNameOf(client);
  if (processName) cfg.capture = { ...cfg.capture, processName };
}

function writeConfig(client, account) {
  const example = JSON.parse(fs.readFileSync(EXAMPLE, 'utf8'));
  if (fs.existsSync(CONFIG)) {
    const cfg = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));
    const notes = [];
    // Bridge settings already on disk override the bundled catalog. Add the
    // new models once and upgrade the old stock default, retaining custom options.
    const savedGPT = cfg.models?.gpt;
    if (Array.isArray(savedGPT?.options)) {
      const added = example.models.gpt.options.slice(0, 2)
        .filter(model => !savedGPT.options.some(existing => existing?.id === model.id));
      if (added.length) {
        savedGPT.options.unshift(...added);
        if (savedGPT.default === 'gpt-6.1-sol') savedGPT.default = example.models.gpt.default;
        notes.push('OpenAI model catalog');
      }
    }
    if (!sameFolder(cfg.addonDir, path.join(client, 'Interface', 'AddOns'))) {
      pointAtClient(cfg, client, account);
      notes.push(`moved to ${path.basename(client)}, process ${cfg.capture.processName}`);
    } else if (account && !cfg.savedVariablesFile) {
      cfg.savedVariablesFile = savedVariablesFile(client, account);
      notes.push('savedVariablesFile');
    }
    if (notes.length) {
      fs.writeFileSync(CONFIG, JSON.stringify(cfg, null, 2) + '\n');
      console.log(`config   : ${CONFIG} updated (${notes.join(', ')}); everything else kept`);
    } else {
      console.log(`config   : ${CONFIG} already exists, keeping it`);
    }
    return cfg;
  }
  const cfg = example;
  pointAtClient(cfg, client, account);
  fs.writeFileSync(CONFIG, JSON.stringify(cfg, null, 2) + '\n');
  console.log(`config   : wrote ${CONFIG}`);
  return cfg;
}

try {
  const client = findClient();
  console.log(`client   : ${client}`);
  const account = findAccount(client);
  console.log(`account  : ${account || 'none yet (the game creates it at your first login; the bridge picks it up then)'}`);
  const { dest, copied } = copyAddon(client);
  console.log(`addon    : ${copied} file(s) -> ${dest}`);
  writeConfig(client, account);
  console.log('게임 안으로 답을 돌려보낼 슬롯을 준비하고 있습니다.');
  const r = spawnSync(process.execPath, [path.join(BRIDGE, 'install-slots.js')], { stdio: 'inherit' });
  if (r.status !== 0) throw new Error('install-slots.js failed');
  console.log('설치 완료. 와우를 완전히 종료한 뒤 다시 실행하고 GPT-Start.cmd를 켜세요.');
} catch (e) {
  console.error('설치 실패:', e.message);
  process.exit(1);
}
