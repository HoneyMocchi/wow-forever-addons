'use strict';

// 모델이 과거 대화의 인용 형식을 따라도 작은 채팅창에는 참고 링크를 노출하지 않는다.
// 필요한 링크도 Markdown 대신 마지막 줄의 순수 URL로만 출력한다.
function formatAnswer(text, question) {
  const urls = [];
  let answer = text.replace(/\[([^\]]*)\]\((https?:\/\/[^\s)]+)\)/g, (_, label, url) => {urls.push(url); return '';});
  answer = answer.replace(/https?:\/\/[^\s<>`]+/g, url => {urls.push(url.replace(/[.,。]+$/, ''));return '';});
  answer = answer.replace(/[][^]*[]/g, '').replace(/^\s*(?:출처|참고\s*자료|참고\s*링크)\s*[:：].*$/gm, '')
    .replace(/[ \t]+$/gm,'').replace(/\n{3,}/g,'\n\n').trim();
  if (/링크|주소|다운로드|계산기|지도|\burl\b|\blink\b/i.test(question)) {
    const valid = [...new Set(urls)].filter(url => {try {const u=new URL(url);return ['http:','https:'].includes(u.protocol);} catch {return false;}});
    const count = /여러|모두|각각|전부/.test(question) ? 3 : 1;
    if (valid.length) answer += '\n' + valid.slice(0,count).join('\n');
  }
  return answer;
}
module.exports = {formatAnswer};
