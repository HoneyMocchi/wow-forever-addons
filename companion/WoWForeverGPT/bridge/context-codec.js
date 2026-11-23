'use strict';

// SC1 전송 사전: Lua의 CONTEXT_WORDS와 순서가 동일해야 한다.
// 이미 배포한 번호는 재배치하지 않는다. 변경이 필요하면 새 버전 접두사를 사용한다.
const words = [
  'Character: level=', '; class=', '; race=', '; faction=', '; name=',
  'Game: World of Warcraft Forever; client=', '; build=', 'Location: ',
  'Talents (points spent): ', 'Purchased talents: ', 'Talents: not available; do not infer a specialization',
  'Current primary stats: ', 'Position: map=',
  'Equipped (names/IDs only; full item stats are not attached):',
  ': empty or unreadable', 'Selected quest: #', 'Professions: ',
  '[Snapshot truncated: omitted fields are unknown.]', 'none (0 spent)', 'not readable', ' [partial]',
  '주무기: ', '보조무기: ', '원거리: ', '가슴: ', '다리: ', '머리: ', '어깨: ',
  '손목: ', '손: ', '허리: ', '발: ', '반지1: ', '반지2: ', '장신구1: ', '장신구2: ', '목: ', '등: ',
];
// SC2 추가 사전은 Lua CONTEXT_EXTRA와 순서가 같아야 한다. SC1 사전은 그대로 둔다.
const extraWords = [
  'Target: ', '; level=', '; type=', 'Quest objective: ',
  'Ranged weapon: ', 'Ranged tooltip: ',
  'Known spells (partial; omission does not mean unlearned): ', 'Known spells: not readable',
];
const codes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const repeatCodes = codes + '-_';
const { isUtf8 } = require('node:buffer');

function unpackDictionary(text, dictionary) {
  // 한 번만 치환하여 원문의 ~A 같은 문자열을 압축 코드로 다시 해석하지 않는다.
  return text.replace(/~([\s\S])/g, (_, code) => {
    if (code === '_') return '~';
    const index = codes.indexOf(code);
    if (index < 0 || index >= dictionary.length) throw new Error('캐릭터 정보 압축 코드가 올바르지 않습니다.');
    return dictionary[index];
  });
}

function unpackRepeats(text) {
  // 참조 거리는 UTF-16 문자 수가 아닌 Lua와 같은 UTF-8 바이트 수다.
  // 길이와 거리를 검사하고 출력 상한을 둬 손상된 화면 패킷을 안전하게 거부한다.
  const input = Buffer.from(text, 'utf8');
  const output = Buffer.alloc(8192);
  let used = 0;
  const append = byte => {
    if (used >= output.length) throw new Error('캐릭터 정보 압축 해제 한도를 초과했습니다.');
    output[used++] = byte;
  };
  for (let i = 0; i < input.length;) {
    if (input[i] !== 94) { append(input[i++]); continue; } // ^ 이외는 원문 바이트
    if (input[i + 1] === 94) { append(94); i += 2; continue; }
    if (i + 3 >= input.length) throw new Error('캐릭터 정보 반복 코드가 잘렸습니다.');
    const values = [input[i + 1], input[i + 2], input[i + 3]].map(b => repeatCodes.indexOf(String.fromCharCode(b)));
    if (values.some(v => v < 0)) throw new Error('캐릭터 정보 반복 코드가 올바르지 않습니다.');
    const distance = values[0] * 64 + values[1] + 1;
    const length = values[2] + 5;
    if (distance > used) throw new Error('캐릭터 정보 반복 참조 범위를 벗어났습니다.');
    // 겹치는 참조도 한 바이트씩 복사하여 같은 문구의 긴 반복을 정확히 복원한다.
    for (let k = 0; k < length; k++) append(output[used - distance]);
    i += 4;
  }
  const result = output.subarray(0, used);
  if (!isUtf8(result)) throw new Error('캐릭터 정보 UTF-8 복원이 올바르지 않습니다.');
  return result.toString('utf8');
}

function unpackContext(text) {
  // 패킷마다 완전한 현재 스냅샷을 복원한다. 캐릭터 상태 캐시/차분 전송은 사용하지 않는다.
  if (typeof text !== 'string') return '';
  if (text.startsWith('SC2\n')) return unpackDictionary(unpackRepeats(text.slice(4)), [...words, ...extraWords]);
  if (text.startsWith('SC1\n')) return unpackDictionary(text.slice(4), words);
  return text; // /reload 전의 원문 패킷도 계속 지원한다.
}

module.exports = { unpackContext };
