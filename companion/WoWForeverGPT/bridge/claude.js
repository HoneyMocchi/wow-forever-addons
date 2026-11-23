'use strict';

// Claude 연결: Claude Code CLI(-p)를 claude.ai 로그인으로 실행해 GPT 연결과 같은
// 지침·JSON 형식으로 답변을 받는다. 게임 쪽은 대화별 agent=claude 플래그로 선택한다.

const { execFile } = require('node:child_process');
const { existsSync, statSync, readdirSync, readFileSync } = require('node:fs');
const { mkdtemp, rm } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { buildInstructions, researchCache } = require('./gpt');
const { formatAnswer } = require('./answer-format');

// Claude에는 셸을 주지 않는다. 웹 검색과 페이지 열기만 허용하고 계산은 직접 한다.
const CLAUDE_TOOL_LINE = "웹 검색(WebSearch)과 페이지 열기(WebFetch) 도구를 사용할 수 있습니다. 파일·셸 도구는 없으므로 간단한 계산은 직접 하세요. 웹 검색어에 캐릭터 이름·계정·대화 전체를 보내지 말고 필요한 게임 용어만 사용하세요.";
const instructions = buildInstructions(CLAUDE_TOOL_LINE);
const schema = JSON.stringify(JSON.parse(readFileSync(path.join(__dirname, 'research-response.schema.json'), 'utf8')));

const EXE = process.platform === 'win32' ? 'claude.exe' : 'claude';

function isFile(file) {
  try { return statSync(file).isFile(); } catch { return false; }
}

// 폴더 아래 depth 단계 안에서 실행 파일을 찾는다. 앱 업데이트로 버전 폴더 이름이
// 바뀌므로 경로를 저장하지 않고 매번 확인한다.
function scan(dir, depth, found) {
  if (!dir || !existsSync(dir)) return;
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isFile() && entry.name.toLowerCase() === EXE) found.push(full);
    else if (entry.isDirectory() && depth > 0) scan(full, depth - 1, found);
  }
}

function findClaude() {
  const override = process.env.WOW_CLAUDE_BIN;
  if (override) {
    const target = path.resolve(override);
    if (isFile(target)) return target;
    throw new Error('WOW_CLAUDE_BIN 경로에서 Claude 실행 파일을 찾지 못했습니다.');
  }
  // 1) PATH와 공식 설치 위치(~/.local/bin)
  const dirs = (process.env.PATH || '').split(path.delimiter).filter(Boolean);
  dirs.push(path.join(os.homedir(), '.local', 'bin'));
  for (const dir of dirs) {
    const file = path.join(dir, EXE);
    if (isFile(file)) return file;
  }
  // 2) Claude 데스크톱 앱·VS Code 확장에 포함된 CLI. 가장 최근 것을 쓴다.
  //    탐색기에서 실행하면 앱이 추가한 PATH를 상속하지 않으므로 직접 찾는다.
  const found = [];
  const local = process.env.LOCALAPPDATA;
  if (local) {
    const data = path.join(local, 'Claude-Data');
    if (existsSync(data)) {
      for (const entry of readdirSync(data, { withFileTypes: true })) {
        if (entry.isDirectory()) scan(path.join(data, entry.name, 'claude-code'), 2, found);
      }
    }
  }
  if (process.env.APPDATA) scan(path.join(process.env.APPDATA, 'Claude', 'claude-code'), 2, found);
  const vscode = path.join(os.homedir(), '.vscode', 'extensions');
  if (existsSync(vscode)) {
    for (const entry of readdirSync(vscode, { withFileTypes: true })) {
      if (entry.isDirectory() && /^anthropic\.claude-code-/i.test(entry.name)) {
        const file = path.join(vscode, entry.name, 'resources', 'native-binary', EXE);
        if (isFile(file)) found.push(file);
      }
    }
  }
  found.sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  if (found.length) return found[0];
  throw new Error('Claude CLI를 찾지 못했습니다. Claude 데스크톱 앱을 설치하거나 WOW_CLAUDE_BIN에 claude.exe 경로를 지정해 주세요.');
}

function runClaude(file, args, { input = '', cwd, timeout = 15_000 } = {}) {
  const env = { ...process.env };
  for (const key of Object.keys(env)) {
    // API 키가 있으면 구독 대신 API 과금으로 실행되므로 제거하고 claude.ai 로그인을 쓴다.
    // Claude Code 안에서 브리지를 시험 실행할 때 상속되는 세션 변수도 지운다.
    if (/^(ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|CLAUDECODE|CLAUDE_CODE_ENTRYPOINT|CLAUDE_CODE_SSE_PORT|OPENAI_API_KEY|CODEX_API_KEY|CODEX_ACCESS_TOKEN)$/i.test(key)) {
      delete env[key];
    }
  }
  return new Promise((resolve, reject) => {
    const child = execFile(file, args, {
      cwd, env, timeout, windowsHide: true, encoding: 'utf8', maxBuffer: 8 * 1024 * 1024,
    }, (error, stdout, stderr) => {
      if (error?.code === 'ENOENT') {
        reject(new Error('Claude CLI를 찾지 못했습니다. Claude 데스크톱 앱 설치 상태를 확인해 주세요.'));
      } else if (error?.killed) {
        reject(new Error('Claude 응답 시간이 초과됐습니다. 다시 시도해 주세요.'));
      } else {
        resolve({ ok: !error, stdout, stderr });
      }
    });
    child.stdin.on('error', () => {});
    child.stdin.end(input, 'utf8');
  });
}

function firstJson(text) {
  const s = String(text || '');
  const start = s.indexOf('{');
  const end = s.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try { return JSON.parse(s.slice(start, end + 1)); } catch { return null; }
}

async function checkClaudeLogin(file = findClaude()) {
  const status = await runClaude(file, ['auth', 'status']);
  const info = firstJson(status.stdout);
  if (info && info.loggedIn) return file;
  throw new Error('Claude 계정 로그인이 필요합니다. Claude 데스크톱 앱에 로그인하거나 PowerShell에서 claude auth login을 실행해 주세요.');
}

function explainFailure(text) {
  if (/usage limit|rate.?limit|limit reached|too many requests|\b429\b|overloaded/i.test(text)) {
    return 'Claude 사용 한도에 도달했거나 서버가 혼잡합니다. 잠시 뒤 다시 시도해 주세요.';
  }
  if (/not logged in|\/login|invalid api key|unauthorized|authentication|oauth|\b401\b/i.test(text)) {
    return 'Claude 로그인을 확인해 주세요. 필요하면 claude auth login을 다시 실행하세요.';
  }
  if (/unknown option|unexpected argument|invalid value/i.test(text)) {
    return 'Claude CLI를 최신 버전으로 업데이트해 주세요. Claude 데스크톱 앱 업데이트로도 갱신됩니다.';
  }
  return 'Claude 답변을 가져오지 못했습니다. 인터넷 연결과 Claude 상태를 확인해 주세요.';
}

async function askClaude(question, history, { effort, timeoutMs = 300_000, gameContext = '', onDiagnostics, model = 'sonnet' } = {}) {
  const level = ['low', 'medium', 'high'].includes(effort) ? effort : 'low';
  const cachedResearch = researchCache.select(question, gameContext);
  const file = await checkClaudeLogin();
  // 빈 임시 폴더에서 실행해 개인 파일·프로젝트 설정을 읽지 않게 한다.
  const cwd = await mkdtemp(path.join(os.tmpdir(), 'wow-claude-'));
  try {
    const result = await runClaude(file, [
      '-p', '--output-format', 'json',
      '--json-schema', schema,
      '--model', String(model || 'sonnet'),
      '--effort', level,
      // 사용자 CLAUDE.md·플러그인·훅·MCP를 끄고 웹 도구만 허용한다. 권한 질문은 자동 거부한다.
      '--safe-mode', '--strict-mcp-config',
      '--tools', 'WebSearch,WebFetch',
      '--allowedTools', 'WebSearch,WebFetch',
      '--permission-mode', 'dontAsk', '--permission-prompts', 'none',
      '--no-session-persistence', '--disable-slash-commands',
      '--system-prompt', instructions,
    ], { cwd, input: JSON.stringify({
      currentCharacter: typeof gameContext === 'string' && gameContext ? gameContext.slice(0, 8192) : null,
      cachedResearch,
      history, question,
    }), timeout: timeoutMs });

    const envelope = firstJson(result.stdout);
    if (!result.ok || !envelope || envelope.is_error) {
      throw new Error(explainFailure([envelope?.result, envelope?.subtype, result.stderr, result.stdout].filter(Boolean).join('\n')));
    }
    // --json-schema 결과는 structured_output에 담긴다. 구버전은 result 문자열로 돌려준다.
    let data = envelope.structured_output;
    if (!data && typeof envelope.result === 'string') data = firstJson(envelope.result) || { answer: envelope.result, research: [] };
    const reply = typeof data?.answer === 'string' ? data.answer.trim() : '';
    // 웹 검색은 보조 모델이 수행하기도 하므로 모델별 사용량까지 합산한다.
    // 허용 도구가 웹뿐이라 구조화 출력·답변 2턴을 넘으면 웹 도구를 사용한 것이다.
    const tools = envelope.usage?.server_tool_use || {};
    const helperSearches = Object.values(envelope.modelUsage || {}).reduce((n, m) => n + (Number(m?.webSearchRequests) || 0), 0);
    const searched = helperSearches > 0 || (tools.web_search_requests || 0) > 0 || (tools.web_fetch_requests || 0) > 0 || (envelope.num_turns || 0) > 2;
    try { researchCache.save(data?.research, gameContext, searched); }
    catch { /* 캐시 저장 실패는 정상 답변 전달을 막지 않는다. */ }
    if (typeof onDiagnostics === 'function') onDiagnostics({ searched, cachedReferences: cachedResearch.length, turns: envelope.num_turns, costUsd: envelope.total_cost_usd });
    if (reply) return formatAnswer(reply, question);
    throw new Error('Claude에서 표시할 답변을 받지 못했습니다.');
  } finally {
    await rm(cwd, { recursive: true, force: true }).catch(() => {});
  }
}

module.exports = { askClaude, checkClaudeLogin, findClaude };
