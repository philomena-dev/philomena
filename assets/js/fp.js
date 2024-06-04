/**
 * FP version 4
 *
 * Not reliant on deprecated properties,
 * and potentially more accurate at what it's supposed to do.
 */

import { $ } from './utils/dom';
import store from './utils/store';

// http://stackoverflow.com/a/34842797
function hashCode(str) {
  return str.split('').reduce((prevHash, currVal) =>
    ((prevHash << 5) - prevHash) + currVal.charCodeAt(0), 0) >>> 0;
}

async function createFp() {
  let kb = 'none';
  let mem = '1';
  let ua = 'none';

  if (navigator.keyboard) {
    kb = (await navigator.keyboard.getLayoutMap()).entries().toArray().sort().map(e => `${e[0]}${e[1]}`).join('');
  }

  if (navigator.deviceMemory) {
    mem = navigator.deviceMemory.toString();
  }

  if (navigator.userAgentData) {
    const uadata = navigator.userAgentData;
    let brands = 'none';

    if (uadata.brands && uadata.brands.length > 0) {
      brands = uadata.brands.filter(e => !e.brand.match(/.*ot.*rand.*/gi)).map(e => `${e.brand}${e.version}`).join('');
    }

    ua = `${brands}${uadata.mobile}${uadata.platform}`;
  }

  let width = store.get('cached_rem_size');
  const body = $('body');

  if (!width && body) {
    const testElement = document.createElement('span');
    testElement.style.minWidth = '1rem';
    testElement.style.maxWidth = '1rem';
    testElement.style.position = 'absolute';

    body.appendChild(testElement);

    width = testElement.clientWidth.toString();

    body.removeChild(testElement);

    store.set('cached_rem_size', width);
  }

  if (!width) {
    width = '0';
  }

  const prints = [
    navigator.userAgent,
    navigator.hardwareConcurrency.toString(),
    navigator.maxTouchPoints.toString(),
    navigator.language,
    kb,
    mem,
    ua,
    width,

    screen.height.toString(),
    screen.width.toString(),
    screen.colorDepth.toString(),
    screen.pixelDepth.toString(),

    window.devicePixelRatio.toString(),
    new Date().getTimezoneOffset().toString(),
  ];

  return hashCode(prints.join(''));
}

async function setFpCookie() {
  let fp = store.get('cached_ses_value');

  if (!fp) {
    const m = document.cookie.match(/_ses=([a-f\d]+)/);

    if (m && m[1]) {
      fp = m[1];
    }
  }

  if (!fp || fp.charAt(0) !== 'd') {
    // The prepended 'd' acts as a crude versioning mechanism.
    try {
      fp = `d${await createFp()}`;
    }
    // If it fails, use fakeprint "d1836832948" as a last resort.
    catch (err) {
      fp = 'd1836832948';
    }

    store.set('cached_ses_value', fp);
  }

  document.cookie = `_ses=${fp}; path=/; SameSite=Lax`;
}

export { setFpCookie };
