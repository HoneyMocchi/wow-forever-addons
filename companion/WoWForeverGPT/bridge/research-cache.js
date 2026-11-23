'use strict';
const fs = require('node:fs');
const path = require('node:path');

// 캐릭터별 답변이 아니라 웹에서 조사한 일반 게임 사실만 최대 60개/6시간 보관한다.
// 클라이언트 빌드가 다르면 재사용하지 않고 최신/패치 질문은 항상 캐시를 우회한다.
const TTL = 6 * 60 * 60 * 1000;
function freshQuestion(q) { return /최신|패치|핫픽스|긴급.?수정|오늘|현재.?버전|다시.?검색|재검색|latest|hotfix|patch|refresh/i.test(q); }
function buildOf(context) { return context.match(/; build=([^\n]+)/)?.[1]?.trim() || ''; }
function tokens(text) { return [...new Set((text.toLowerCase().match(/[가-힣a-z0-9]{2,}/g) || []).filter(s => !['포에버','forever','알려줘','어떻게','지금','사제'].includes(s)))]; }
function createCache(file, now = () => Date.now()) {
  let entries;
  try { entries = JSON.parse(fs.readFileSync(file, 'utf8')); } catch { entries = []; }
  if (!Array.isArray(entries)) entries = [];
  function valid(e, build) {
    return e && e.build === build && Number.isFinite(e.at) && now() - e.at < TTL && now() >= e.at && typeof e.topic === 'string' && typeof e.summary === 'string' && /^https?:\/\//.test(e.url);
  }
  return {
    select(question, context) {
      const build = buildOf(context);
      if (!build || freshQuestion(question)) return [];
      // 질문 용어와 겹치는 주제만 선택한다. 막연한 후속 질문은 직전 대화로 처리한다.
      const query = tokens(question);
      return entries.filter(e => valid(e, build)).map(e => ({e, score: tokens(e.topic + ' ' + e.summary).filter(t => query.some(q => t.includes(q) || q.includes(t))).length}))
        .filter(x => x.score > 0).sort((a,b) => b.score-a.score).slice(0,3).map(({e}) => ({topic:e.topic, summary:e.summary, url:e.url, checkedAt:new Date(e.at).toISOString()}));
    },
    save(notes, context, searched) {
      const build = buildOf(context);
      // 모델이 검색하지 않은 요청에서는 새 지식을 저장하지 않는다. 스냅샷도 저장하지 않는다.
      if (!build || !searched || !Array.isArray(notes)) return;
      entries = entries.filter(e => e && Number.isFinite(e.at) && now()-e.at<TTL);
      for (const n of notes.slice(0,3)) {
        if (!n || typeof n.topic !== 'string' || typeof n.summary !== 'string' || typeof n.url !== 'string') continue;
        let url;
        try { url = new URL(n.url); } catch { continue; }
        if (!['https:','http:'].includes(url.protocol) || url.username || url.password) continue;
        const note = {topic:n.topic.slice(0,100), summary:n.summary.slice(0,700), url:url.href.slice(0,1000), build, at:now()};
        entries = entries.filter(e => !(e.build===build && e.topic===note.topic && e.url===note.url));
        entries.push(note);
      }
      entries = entries.slice(-60);
      // 임시 파일을 같은 폴더에 만든 후 교체해 중간에 종료돼도 JSON 손상을 줄인다.
      fs.mkdirSync(path.dirname(file), {recursive:true});
      const tmp = file + '.tmp';
      fs.writeFileSync(tmp, JSON.stringify(entries));
      fs.renameSync(tmp, file);
    },
  };
}
module.exports = {createCache, freshQuestion};
