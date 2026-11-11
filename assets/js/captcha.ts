import { assertNotNull } from './utils/assert';
import { delegate, leftClick } from './utils/events';
import { clearEl, makeEl } from './utils/dom';

function insertCaptcha(_event: Event, target: HTMLInputElement) {
  const box = assertNotNull(target.closest<HTMLElement>('.js-captcha-box'));

  const script = makeEl('script', { src: 'https://hcaptcha.com/1/api.js', async: true, defer: true });
  const frame = makeEl('div', { className: 'h-captcha' });

  frame.dataset.sitekey = target.dataset.sitekey;

  clearEl(box);

  box.insertAdjacentElement('beforeend', frame);
  box.insertAdjacentElement('beforeend', script);
}

export function bindCaptchaLinks() {
  delegate(document, 'click', { '.js-captcha': leftClick(insertCaptcha) });
}
