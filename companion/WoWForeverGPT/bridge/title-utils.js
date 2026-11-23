'use strict';

function autoTitle(text) {
  // 로캘에 영향을 받는 대소문자 변환을 한글에 적용하지 않는다.
  // Lua 제목 규칙과 똑같이 첫 5개 단어, Unicode 코드 포인트 24개를 사용한다.
  const words = String(text || '').match(/[^\x09-\x0d ]+/g) || [];
  const title = words.map(word => word.replace(/^[\x21-\x2f\x3a-\x40\x5b-\x60\x7b-\x7e]+|[\x21-\x2f\x3a-\x40\x5b-\x60\x7b-\x7e]+$/g, ''))
    .filter(Boolean).slice(0, 5).join(' ');
  return Array.from(title).slice(0, 24).join('').replace(/^[a-z]/, ch => String.fromCharCode(ch.charCodeAt(0) - 32));
}

function repairChatTitle(chat) {
  // 손상된 UTF-8을 디코딩한 대체 문자(�)가 있는 제목만 복구한다.
  // 메시지 본문·사용자가 정상적으로 붙인 이름·대화 ID는 변경하지 않는다.
  if (typeof chat.name === 'string' && !chat.name.includes('\ufffd')) return false;
  const first = (chat.messages || []).find(message => message.role === 'user' && typeof message.text === 'string');
  if (!first) return false;
  const restored = autoTitle(first.text);
  if (!restored) return false;
  chat.name = restored;
  return true;
}

module.exports = { autoTitle, repairChatTitle };
