#!/usr/bin/env node
'use strict';
// WoW Forever GPT Q&A. Receives prompts via the upstream pixel strip,
// calls Codex CLI, and returns text via the upstream reply slots.

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { spawn } = require('child_process');
const P = require('./protocol'); // the pure protocol code, unit-tested in tests/bridge_test.js
const { unpackContext } = require('./context-codec');
const { repairChatTitle } = require('./title-utils');
const { askGPT, recentTurns, checkCodexLogin } = require('./gpt');
const { askClaude, checkClaudeLogin } = require('./claude');

const HERE = __dirname;
const CONFIG_FILE = path.join(HERE, 'config.json');
const STATE_FILE = path.join(HERE, 'state.json');
const LOG_FILE = path.join(HERE, 'bridge.log');
const argv = process.argv.slice(2);
if (argv.includes('--help') || argv.includes('-h')) {
  console.log('사용법: node bridge/bridge.js [--once | --inject "질문"]');
  process.exit(0);
}
let cfg;
try { cfg = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8')); }
catch (e) {
  console.error(`Cannot read ${CONFIG_FILE} (${e.message}).\nRun "node setup.js" in the wow-ai folder first.`);
  process.exit(2); // the supervisor doesn't restart on 2
}
const once = argv.includes('--once');
const injectIdx = argv.indexOf('--inject');
const inject = injectIdx >= 0 ? argv[injectIdx + 1] : null;
const exitWhenIdle = once || inject !== null;
// 게임의 대화별 AI 선택(/wow-ai agent claude 또는 대화 우클릭 → AI 선택)이
// agent= 플래그로 전달된다. 목록에 없는 값이나 빈 값은 기본 AI로 처리한다.
const AGENTS = ['gpt', 'claude'];
const DEFAULT_AGENT = AGENTS.includes(cfg.defaultAgent) ? cfg.defaultAgent : 'gpt';
const claudeCfg = cfg.claude || {};
// 회사(AI)별로 게임에서 고를 수 있는 모델. config.json의 models가 있으면 그 목록을 쓴다.
// 게임이 보낸 모델 ID는 이 목록에 있을 때만 사용하고, 아니면 그 회사의 기본 모델로 바꾼다.
const DEFAULT_MODELS = {
  gpt: { company: 'OpenAI', default: 'gpt-6.2-sol', options: [
    { id: 'gpt-6.2-sol', label: 'Sol 6.2' },
    { id: 'gpt-6.2-astra', label: 'Astra 6.2' },
    { id: 'gpt-6.1-sol', label: 'Sol 6.1' },
    { id: 'gpt-6.1-terra', label: 'Terra 6.1' },
    { id: 'gpt-6-astra', label: 'Astra 6' },
    { id: 'gpt-6-sol', label: 'Sol 6' },
    { id: 'gpt-6-luna', label: 'Luna 6' },
  ] },
  claude: { company: 'Anthropic', default: 'claude-sonnet-5-5', options: [
    { id: 'claude-fable-5-2', label: 'Fable 5.2' },
    { id: 'claude-opus-5-5', label: 'Opus 5.5' },
    { id: 'claude-sonnet-5-5', label: 'Sonnet 5.5' },
    { id: 'claude-haiku-5-5', label: 'Haiku 5.5' },
  ] },
};
const MODEL_ID = /^[A-Za-z0-9._:-]{1,64}$/;
const MODELS = {};
for (const agent of AGENTS) {
  const custom = cfg.models?.[agent];
  const base = custom && Array.isArray(custom.options) ? custom : DEFAULT_MODELS[agent];
  const options = base.options
    .filter(o => o && MODEL_ID.test(String(o.id)))
    .map(o => ({ id: String(o.id), label: String(o.label || o.id).slice(0, 40) }));
  if (!options.length) options.push(...DEFAULT_MODELS[agent].options);
  const def = options.some(o => o.id === base.default) ? base.default : options[0].id;
  MODELS[agent] = { company: String(base.company || DEFAULT_MODELS[agent].company), default: def, options };
}
const pickModel = (agent, id) => (MODELS[agent].options.some(o => o.id === id) ? id : MODELS[agent].default);
if (argv.includes('--auth-check')) {
  // 기본 AI의 로그인은 필수, 다른 AI는 상태만 알린다. 한쪽만 써도 브리지를 켤 수 있다.
  const checks = { gpt: checkCodexLogin, claude: checkClaudeLogin };
  const label = { gpt: 'ChatGPT', claude: 'Claude' };
  (async () => {
    for (const agent of [DEFAULT_AGENT, ...AGENTS.filter(a => a !== DEFAULT_AGENT)]) {
      try { await checks[agent](); console.log(`${label[agent]} 계정 연결 확인`); }
      catch (error) {
        if (agent === DEFAULT_AGENT) { console.error(error.message); process.exitCode = 1; return; }
        console.log(`${label[agent]} 연결 불가(선택 사항): ${error.message}`);
      }
    }
  })();
  return;
}
const SLOTS = cfg.slots || 200;
const MAX_PARALLEL = cfg.maxParallel || 1;
const cap = Object.assign({ enabled: true, processName: 'Wow', cellPx: 4, cellsPerRow: 200, maxRows: 48, intervalMs: 250 }, cfg.capture || {});
// The game-side files. A config.json written for the addon's old name
// (WoWClaude) still works: the paths are derived from addonDir instead.
const INBOX_FILE = cfg.inboxFile && !/WoWClaude/.test(cfg.inboxFile) ? cfg.inboxFile : path.join(cfg.addonDir || '', 'WoWForeverGPT', 'Inbox.lua');
let SAVED_VARS = String(cfg.savedVariablesFile || '').replace(/WoWClaude\.lua$/, 'WoWForeverGPT.lua');
// The client folder holding the AddOns folder.
const CLIENT_DIR = cfg.addonDir ? path.dirname(path.dirname(cfg.addonDir)) : '';

// Set up before the first login there was no account folder to point at: the
// game creates it at login, so keep looking until it shows up.
function findSavedVars() {
  if (SAVED_VARS || !CLIENT_DIR) return;
  const base = path.join(CLIENT_DIR, 'WTF', 'Account');
  try {
    const account = fs.readdirSync(base, { withFileTypes: true }).find(d => d.isDirectory() && d.name !== 'SavedVariables');
    if (account) SAVED_VARS = path.join(base, account.name, 'SavedVariables', 'WoWForeverGPT.lua');
  } catch {}
}

let state = readJson(STATE_FILE, { lastId: 0, sessions: {}, handled: {} });
if (!state.handled) state.handled = {};
if (!state.sessions) state.sessions = {};
// Older versions stored handled[session] as "highest id so far"; expand to a map.
for (const [k, v] of Object.entries(state.handled)) {
  if (typeof v === 'number') {
    const m = {};
    for (let i = 1; i <= v; i++) m[i] = 1;
    state.handled[k] = m;
  }
}

// Bridge-side transcripts. The beta client sometimes wipes addon saved data; since
// every prompt and reply passes through here, this copy lets the addon recover.
const TRANSCRIPT_FILE = path.join(HERE, 'transcripts.json');
let transcripts = readJson(TRANSCRIPT_FILE, { chats: {}, tokens: {} });
if (!transcripts.chats) transcripts.chats = {};
if (!transcripts.tokens) transcripts.tokens = {};
// 이전 클라이언트가 망가뜨린 제목만 시작할 때 복구한다. 대화 본문은 유지한다.
let recoveredTitles = 0;
for (const chat of Object.values(transcripts.chats)) {
  if (repairChatTitle(chat)) recoveredTitles++;
}
if (recoveredTitles) { saveTranscripts(); log(`Recovered ${recoveredTitles} UTF-8 chat title(s)`); }
if (P.pruneStale(state, transcripts)) { saveState(); saveTranscripts(); }
let pendingRestore = null;
// 소리 파일이 게임에 캐시되어도 수신 사실을 확인할 수 있도록 응답 슬롯에
// 세션별 접수증을 함께 싣는다. 최근 64개만 유지해 슬롯 파일이 계속 커지지 않게 한다.
const receipts = new Map();
function rememberReceipt(job) {
  const key = `${job.session || ''}:${job.id}`;
  if (receipts.has(key)) return false;
  receipts.set(key, { session: job.session || '', id: job.id });
  if (receipts.size > 64) receipts.delete(receipts.keys().next().value);
  return true;
}

function saveTranscripts() {
  try { atomicWrite(TRANSCRIPT_FILE, JSON.stringify(transcripts)); } catch (e) { log('could not save transcripts:', e.message); }
}

// Chats the player deleted in game while a run for them was still going: the
// run's late progress and reply must not recreate the transcript.
const forgotten = new Set();

function noteMessage(job, role, text) {
  if (!job.chat) return;
  if (role === 'user') forgotten.delete(job.chat);
  else if (forgotten.has(job.chat)) return;
  const c = transcripts.chats[job.chat] = transcripts.chats[job.chat] || { id: job.chat, name: '', cwd: job.cwd, messages: [] };
  if (job.name) c.name = job.name;
  if (job.cwd) c.cwd = job.cwd;
  const m = { role, text: String(text ?? '').slice(0, 4000), id: job.id, session: job.session || '', t: Math.floor(Date.now() / 1000) };
  if (role === 'user' && job.newSession) m.reset = true;
  if (role === 'assistant' && job.agent) m.agent = job.agent;
  if (role === 'assistant' && job.model) m.model = job.model;
  c.messages.push(m);
  while (c.messages.length > 200) c.messages.shift();
  repairChatTitle(c);
  c.updated = Date.now();
  saveTranscripts();
}

// First message from an addon session token we haven't seen: its saved data is
// fresh (or reset), so offer everything we know once, in the next publish.
function maybeOfferRestore(job) {
  if (!job.session || transcripts.tokens[job.session]) return;
  transcripts.tokens[job.session] = Date.now();
  const chats = Object.values(transcripts.chats)
    .filter(c => c.id !== job.chat && c.messages.length)
    .sort((a, b) => (b.updated || 0) - (a.updated || 0))
    .slice(0, 16)
    .map(c => ({ id: c.id, name: c.name, cwd: c.cwd, messages: c.messages.slice(-40).map(m => ({ ...m, text: m.text.slice(0, 2000) })) }));
  saveTranscripts();
  if (chats.length) {
    pendingRestore = { token: job.session, chats };
    log(`new addon session ${job.session}: offering ${chats.length} chat(s) to restore`);
  }
}

// The player deleted a chat in game. Drop everything we keep for it, so the next
// restore doesn't bring it back and its id can't resume the old agent session.
function forgetChat(job) {
  if (!job.chat) return;
  const had = !!transcripts.chats[job.chat];
  delete transcripts.chats[job.chat];
  forgotten.add(job.chat);
  delete state.sessions[sessKey(job)];
  delete state.sessions[chatKey(job)];
  if (state.sessionCwd) delete state.sessionCwd[sessKey(job)];
  if (state.sessionAgent) delete state.sessionAgent[sessKey(job)];
  if (pendingRestore) pendingRestore.chats = pendingRestore.chats.filter(c => c.id !== job.chat);
  saveTranscripts();
  log(`#${job.id}${job.session ? '@' + job.session : ''} forgot chat ${job.chat}${had ? '' : ' (nothing stored)'}`);
}

let lastMtime = 0;
const running = new Map(); // chatKey -> { job, child }
const queued = new Map();  // chatKey -> job waiting for that chat (or for a free parallel slot)
// 완료 기록은 디스크에 있지만 live는 메모리라 재시작 시 비어 있었다.
// 마지막 질문에 대응하는 완료 응답만 복구한다. 아직 처리 중인 질문에 과거 답변을
// 붙이거나 다른 애드온 세션의 같은 번호를 섞지 않도록 질문/번호/세션을 검증한다.
function recoverCompletedReplies(state, transcripts) {
  const recovered = [];
  const chats = Object.values(transcripts.chats || {}).sort((a, b) => (a.updated || 0) - (b.updated || 0)).slice(-30);
  for (const chat of chats) {
    const messages = chat.messages || [];
    let userIndex = -1;
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role === 'user') { userIndex = i; break; }
    }
    if (userIndex < 0 || !chat.id) continue;
    const user = messages[userIndex];
    const reply = messages.slice(userIndex + 1).find(m => m.id === user.id && (m.role === 'assistant' || m.role === 'system'));
    if (!reply || !Number.isSafeInteger(user.id) || user.id <= 0) continue;
    if (user.session && reply.session && user.session !== reply.session) continue;
    let session = reply.session || user.session;
    if (!session) {
      // 구버전 기록에는 세션이 없다. 해당 번호를 완료한 세션이 유일할 때만 복구한다.
      const candidates = Object.keys(state.handled || {}).filter(s => state.handled[s]?.[user.id]);
      if (candidates.length !== 1) continue;
      session = candidates[0];
    }
    if (!state.handled?.[session]?.[user.id]) continue;
    recovered.push([`${session}:${chat.id}`, { chat: chat.id, id: user.id,
      status: reply.role === 'assistant' ? 'done' : 'error', text: reply.text || '', agent: reply.agent || 'gpt', model: reply.model || '' }]);
  }
  return recovered;
}

const live = new Map(recoverCompletedReplies(state, transcripts));    // chatKey -> latest record shown to the game
let lastPublish = 0;
let publishTimer = null;

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return fallback; }
}

function saveState() {
  atomicWrite(STATE_FILE, JSON.stringify(state, null, 2));
}

function log(...parts) {
  const line = `[${new Date().toISOString()}] ${parts.join(' ')}`;
  console.log(line);
  try { fs.appendFileSync(LOG_FILE, line + '\n'); } catch {}
}

const { pad3, chatKey, sessKey, SILENT_WAV, jobsFromStrip } = P;
const slotNumber = id => P.slotNumber(id, SLOTS);
const alreadyHandled = job => P.alreadyHandled(state, job);
const markHandled = job => P.markHandled(state, job);

function atomicWrite(file, content) {
  const tmp = file + '.tmp';
  fs.writeFileSync(tmp, content);
  fs.renameSync(tmp, file);
}

// Stop a run and whatever it spawned (an npm launcher runs the real binary as a
// child of its own; on Windows a plain kill would leave that one going).
// ---------------------------------------------------------------------------
// What the game reads
// ---------------------------------------------------------------------------

function slotFile(globalName, records) {
  return P.luaTable(globalName, records, { restore: pendingRestore, agent: DEFAULT_AGENT, agents: AGENTS, models: MODELS, acks: [...receipts.values()] });
}

function addonInstalled() {
  return fs.existsSync(path.join(cfg.addonDir, 'WoWForeverGPT', 'WoWForeverGPT.toc'));
}

function slotsInstalled() {
  return fs.existsSync(path.join(cfg.addonDir, 'WoWForeverGPT_S001', 'Inbox.lua'));
}

// The game will load *some* unused slot next, so every slot gets the full picture.
// A missing addon folder (not installed yet, or the game folder moved) must not
// take the bridge down: capture and agent runs keep working, and the game just
// won't see replies until `node setup.js` has run and WoW was restarted.
let warnedNoAddon = false;
function publishNow(urgent = true) {
  lastPublish = Date.now();
  const records = [...live.values()].slice(-30);
  try {
    atomicWrite(INBOX_FILE, slotFile('WoWForeverGPT_Inbox', records, urgent));
  } catch (e) {
    if (!warnedNoAddon) {
      warnedNoAddon = true;
      log(`publish: cannot write ${INBOX_FILE} (${e.code || e.message}); addon not installed? run: node setup.js, then restart WoW`);
    }
    return;
  }
  if (!slotsInstalled()) return;
  const body = slotFile('WoWForeverGPT_SlotData', records, urgent);
  for (let i = 1; i <= SLOTS; i++) {
    try { atomicWrite(path.join(cfg.addonDir, 'WoWForeverGPT_S' + pad3(i), 'Inbox.lua'), body); } catch {}
  }
  // The restore bundle is large; it rides along once and is then dropped.
  // (The game keeps loading fresh slots until it has read one carrying it.)
  if (pendingRestore) { pendingRestore.published = (pendingRestore.published || 0) + 1; if (pendingRestore.published >= 3) pendingRestore = null; }
}

// Final results publish immediately; progress is throttled. `key` is the chat
// (record.session is the agent's session id, a different thing).
function publish(key, record, urgent) {
  live.set(key, record);
  if (urgent) { if (publishTimer) { clearTimeout(publishTimer); publishTimer = null; } publishNow(); return; }
  const wait = (cfg.progressWriteMs || 3000) - (Date.now() - lastPublish);
  if (wait <= 0) publishNow(false);
  else if (!publishTimer) publishTimer = setTimeout(() => { publishTimer = null; publishNow(false); }, wait);
}

function signal(kind, id, on) {
  const file = path.join(cfg.addonDir, 'WoWForeverGPT', kind, pad3(slotNumber(id)) + '.wav');
  try { atomicWrite(file, on ? SILENT_WAV : Buffer.alloc(0)); } catch {}
}

// Heartbeat: act/NNN/kk.wav flips valid for the k-th action of message NNN. The
// game polls the next one for free, so it can show "12 actions, last one 5 s ago"
// without spending a reply slot.
const ACT_MAX = cfg.actMax || 60;
function actFile(id, k) {
  return path.join(cfg.addonDir, 'WoWForeverGPT', 'act', pad3(slotNumber(id)), String(k).padStart(2, '0') + '.wav');
}
function resetBeats(id) {
  for (let k = 1; k <= ACT_MAX; k++) { try { atomicWrite(actFile(id, k), Buffer.alloc(0)); } catch {} }
}
function beat(job) {
  job.beats = (job.beats || 0) + 1;
  if (job.beats > ACT_MAX) return;
  try { atomicWrite(actFile(job.id, job.beats), SILENT_WAV); } catch {}
}

// Presence: every 30 s flip the next presence/NNNN.wav valid so the game can tell
// the bridge is alive without spending a slot. The counter persists across
// restarts so a filename is never reused while the game is still running; the
// files just ahead of the counter are kept empty so the game can't run ahead.
const PRESENCE_MAX = cfg.presenceMax || 2000;
function presenceFile(k) {
  return path.join(cfg.addonDir, 'WoWForeverGPT', 'presence', String(k).padStart(4, '0') + '.wav');
}
function presenceBeat() {
  if (!fs.existsSync(path.join(cfg.addonDir, 'WoWForeverGPT', 'presence'))) return;
  state.presence = ((state.presence || 0) % PRESENCE_MAX) + 1;
  const k = state.presence;
  try { atomicWrite(presenceFile(k), SILENT_WAV); } catch {}
  for (let j = 1; j <= 50; j++) {
    const n = ((k - 1 + j) % PRESENCE_MAX) + 1;
    try { atomicWrite(presenceFile(n), Buffer.alloc(0)); } catch {}
  }
  saveState();
  // 소리 파일 신호가 캐시되거나 누락돼도 다음 슬롯에는 실제 최신 시각이 있어야 한다.
  // 유휴 중 게시를 멈추면 살아 있는 브리지를 오래된 슬롯만 보고 끊겼다고 판단하게 된다.
  publishNow(false);
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

// The reload path: the addon writes its outbox into SavedVariables on /reload.
function readOutbox() {
  let src;
  try { src = fs.readFileSync(SAVED_VARS, 'utf8'); } catch { return null; }
  return P.parseOutbox(src);
}

function submit(job) {
  const newReceipt = rememberReceipt(job);
  // 재시작 전에 처리한 요청도 재전송되면 접수증을 다시 전달한다.
  // 실제 작업은 중복 수행하지 않고 게임의 전송 표시만 정리하게 한다.
  if (alreadyHandled(job)) {
    // 재전송은 AI를 재실행하지 않고 같은 번호의 완료 응답을 다시 알린다.
    // 接수증이 이미 있어도 답변 수신이 누락됐을 수 있으므로 다시 게시한다.
    const completed = live.get(chatKey(job));
    const hasReply = completed && completed.id === job.id && (completed.status === 'done' || completed.status === 'error');
    if (hasReply) signal('sig', job.id, true);
    if (newReceipt || hasReply) publishNow();
    return;
  }
  if (job.forget) {
    // A deleted chat: forget it and ack. No agent run.
    markHandled(job);
    forgetChat(job);
    saveState();
    signal('ack', job.id, true);
    publishNow();
    return;
  }
  if (job.hello) {
    // The addon announcing itself: ack, offer a restore if its data is fresh,
    // and refresh the slots so it can read our clock. No agent run.
    markHandled(job);
    saveState();
    signal('ack', job.id, true);
    maybeOfferRestore(job);
    publishNow();
    log(`hello from session ${job.session}${pendingRestore ? ' (restore offered)' : ''}`);
    return;
  }
  const key = chatKey(job);
  const cur = running.get(key);
  if (cur && cur.job.id === job.id) return;
  const q = queued.get(key);
  if (q && q.id === job.id) return;
  if (cur || running.size >= MAX_PARALLEL) {
    queued.set(key, job);
    publishNow();
    log(`#${job.id}${job.session ? '@' + job.session : ''} queued (${cur ? 'chat busy' : running.size + ' running'})`);
    return;
  }
  runJob(job);
}

function drainQueue() {
  for (const [key, job] of queued) {
    if (running.size >= MAX_PARALLEL) break;
    if (running.has(key)) continue;
    queued.delete(key);
    runJob(job);
  }
}

async function runJob(job) {
  const key = chatKey(job);
  job.agent = AGENTS.includes(job.agent) ? job.agent : DEFAULT_AGENT;
  job.model = pickModel(job.agent, job.model);
  job.cwd = '';
  running.set(key, { job });
  signal('sig', job.id, false);
  resetBeats(job.id);
  signal('ack', job.id, true);
  maybeOfferRestore(job);
  const history = job.newSession ? [] : recentTurns(transcripts.chats[job.chat]?.messages || []);
  noteMessage(job, 'user', job.text);
  publish(key, { chat: job.chat, id: job.id, status: 'working', text: 'AI 답변 중…', agent: job.agent, model: job.model }, true);

  let reply;
  try {
    // 패킷 수신부는 이미 ctx를 읽지만, 이전에는 AI 호출에 전달하지 않았다.
    // 현재 질문에 실린 정보만 전달하여 다른 캐릭터/지난 질문의 상태를 재사용하지 않는다.
    // 화면 신호의 숏코드를 원문으로 복원한 뒤 AI에 전달한다. AI 입력/정보량은 바뀌지 않는다.
    const gameContext = unpackContext(job.ctx);
    log(`#${job.id} character snapshot: ${gameContext ? Buffer.byteLength(job.ctx, 'utf8') + ' wire / ' + Buffer.byteLength(gameContext, 'utf8') + ' restored bytes' : 'not supplied'}`);
    log(`#${job.id} agent: ${job.agent}, model: ${job.model}, effort: ${job.effort || 'low'}`);
    if (job.agent === 'claude') {
      reply = await askClaude(job.text, history, { effort: job.effort, timeoutMs: claudeCfg.timeoutMs || cfg.codexTimeoutMs, gameContext, model: job.model });
    } else {
      reply = await askGPT(job.text, history, { effort: job.effort, timeoutMs: cfg.codexTimeoutMs, gameContext, model: job.model });
    }
  } catch (error) {
    finish(job, 'error', error.message);
    return;
  }
  finish(job, 'done', reply);
}

function finish(job, status, text) {
  if (job.finished) return; // spawn failures fire both 'error' and 'close'
  job.finished = true;
  running.delete(chatKey(job));
  markHandled(job);
  saveState();
  noteMessage(job, status === 'done' ? 'assistant' : 'system', text);
  publish(chatKey(job), { chat: job.chat, id: job.id, status, text, agent: job.agent || DEFAULT_AGENT, model: job.model || '' }, true);
  signal('sig', job.id, true);
  log(`#${job.id}${job.session ? '@' + job.session : ''} ${status} (${text.length}자)`);
  drainQueue();
  if (exitWhenIdle && running.size === 0) process.exit(status === 'done' ? 0 : 1);
}

// ---------------------------------------------------------------------------
// Input loops
// ---------------------------------------------------------------------------

function pollSavedVariables() {
  findSavedVars();
  let st;
  try { st = fs.statSync(SAVED_VARS); } catch { return; }
  if (st.mtimeMs === lastMtime) return;
  lastMtime = st.mtimeMs;
  const job = readOutbox();
  if (job) submit(job);
}

// Windows: capture.ps1 (GDI). macOS: capture_mac.py (native screencapture). Elsewhere: capture_x11.py (Wine/X11).
function captureCommand() {
  // 일부 전체 화면/합성 경로는 GDI에서 검게 읽힌다. DirectX 수신기도 같은 JSON
  // 계약을 사용하며, 기존 PowerShell 방식은 설정으로 되돌릴 수 있게 보존한다.
  if (process.platform === 'win32' && cap.backend === 'dxgi') {
    return [cap.python, ['-X', 'utf8', path.join(HERE, 'capture_dxgi.py'),
      '--cell', String(cap.cellPx), '--cells', String(cap.cellsPerRow), '--max-rows', String(cap.maxRows),
      '--interval-ms', String(cap.intervalMs), '--process-name', cap.processName, '--client-folder', path.basename(CLIENT_DIR)]];
  }
  if (process.platform === 'win32') {
    return ['powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(HERE, 'capture.ps1'),
      '-Cell', String(cap.cellPx), '-Cells', String(cap.cellsPerRow), '-MaxRows', String(cap.maxRows),
      '-IntervalMs', String(cap.intervalMs), '-ProcessName', cap.processName, '-ClientFolder', path.basename(CLIENT_DIR)]];
  }
  if (process.platform === 'darwin') {
    const args = [path.join(HERE, 'capture_mac.py'),
      '--cell', String(cap.cellPx), '--cells', String(cap.cellsPerRow), '--max-rows', String(cap.maxRows),
      '--interval-ms', String(cap.intervalMs), '--process-name', cap.processName];
    if (cap.windowName) args.push('--window-name', cap.windowName);
    return [cap.python || 'python3', args];
  }
  const args = [path.join(HERE, 'capture_x11.py'),
    '--cell', String(cap.cellPx), '--cells', String(cap.cellsPerRow), '--max-rows', String(cap.maxRows),
    '--interval-ms', String(cap.intervalMs), '--process-name', cap.processName];
  if (cap.windowName) args.push('--window-name', cap.windowName);
  if (cap.keepComposited) args.push('--keep-composited');
  return [cap.python || 'python3', args];
}

let captureProcess = null;
let capturePulse = 0;
let captureStarted = 0;
let captureStopping = false;
function writeHealth() {
  try {
    atomicWrite(path.join(HERE, 'health.json'), JSON.stringify({
      processId: process.pid, at: Date.now(), capturePid: captureProcess?.pid || null,
      capturePulse: capturePulse || null,
    }));
  } catch (error) { log('health write:', error.code || error.message); }
  // DXGI 수신기가 종료되지 않고 내부에서 멈춘 경우도 복구한다.
  // 수신기는 창 최소화/신호 없음과 관계없이 생존 신호를 보내므로 정상 유휴를 장애로 오인하지 않는다.
  if (cap.backend === 'dxgi' && captureProcess && !captureStopping &&
      Date.now() - Math.max(capturePulse, captureStarted) > 90000) {
    captureStopping = true;
    log('capture heartbeat stalled; restarting receiver');
    captureProcess.kill();
  }
}
function startCapture() {
  const [cmd, args] = captureCommand();
  const captureEnv = { ...process.env };
  delete captureEnv.OPENAI_API_KEY;
  delete captureEnv.CODEX_API_KEY;
  delete captureEnv.CODEX_ACCESS_TOKEN;
  const ps = spawn(cmd, args, { env: captureEnv, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  captureProcess = ps;
  captureStarted = Date.now();
  capturePulse = 0;
  captureStopping = false;
  const rl = readline.createInterface({ input: ps.stdout });
  rl.on('line', (line) => {
    let ev;
    try { ev = JSON.parse(line); } catch { return; }
    capturePulse = Date.now();
    if (ev.pulse) return; // 생존 확인은 로그를 채우거나 새 AI 질문을 만들지 않는다.
    if (ev.info) { log('capture:', ev.info); return; }
    if (ev.warn) { log('capture:', ev.warn); return; }
    if (ev.error) { log('capture error:', ev.error); return; }
    if (typeof ev.id === 'number') {
      const jobs = jobsFromStrip(ev.id, ev.text);
      log(`strip #${ev.id}: ${jobs.length} message(s)`);
      for (const job of jobs) submit(job);
    }
  });
  ps.stderr.on('data', (d) => log('capture stderr:', String(d).trim().slice(0, 300)));
  ps.on('error', (err) => log(`capture could not start (${cmd}): ${err.message}`));
  ps.on('close', (code) => {
    if (captureProcess === ps) captureProcess = null;
    rl.close();
    log(`capture exited (${code}); restarting in 5 s`);
    setTimeout(startCapture, 5000);
  });
}

function banner() {
  console.log('와우 AI');
  console.log('  연결: ChatGPT 로그인 (Codex CLI), Claude 로그인 (Claude Code CLI)');
  console.log('  기본 AI: ' + DEFAULT_AGENT + ' (대화별 변경: 창 위쪽 모델 버튼 또는 /wow-ai agent claude|gpt)');
  for (const agent of AGENTS) console.log(`  ${MODELS[agent].company} 모델: ${MODELS[agent].options.map(o => o.id).join(', ')} (기본 ${MODELS[agent].default})`);
  console.log('  애드온 폴더: ' + cfg.addonDir);
  console.log('  응답 슬롯: ' + (slotsInstalled() ? '설치됨' : '미설치 (설치.cmd 실행 후 게임 재시작)'));
  console.log('게임에서 /ai 질문을 입력하세요. 이 창을 닫으면 연결이 종료됩니다.\n');
}

findSavedVars();
banner();
// 첫 재접속/재전송 전에 응답 파일부터 복구한다. 새 질문이나 모델 호출은 만들지 않는다.
if (live.size) {
  publishNow();
  for (const record of live.values()) signal('sig', record.id, true);
  log(`Recovered ${live.size} completed reply/replies after restart`);
}
if (inject !== null) {
  submit({ id: state.lastId + 1, session: '', chat: '', text: inject, cwd: '', newSession: false, via: 'inject' });
} else {
  pollSavedVariables();
  if (once) {
    if (running.size === 0) { console.log('nothing pending'); process.exit(0); }
  } else {
    writeHealth();
    setInterval(writeHealth, 5000);
    setInterval(pollSavedVariables, cfg.pollMs || 750);
    presenceBeat();
    setInterval(presenceBeat, cfg.presenceIntervalMs || 30000);
    if (cap.enabled) startCapture();
  }
}
