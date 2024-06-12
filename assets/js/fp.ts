/**
 * FP version 4
 *
 * Not reliant on deprecated properties,
 * and potentially more accurate at what it's supposed to do.
 */

import { $ } from './utils/dom';
import store from './utils/store';

interface RealKeyboard {
  getLayoutMap: () => Promise<Map<string, string>>
}

interface RealUserAgentData {
  brands: [{brand: string, version: string}],
  mobile: boolean,
  platform: string,
}

interface RealNavigator extends Navigator {
  deviceMemory: number | null,
  keyboard: RealKeyboard | null,
  userAgentData: RealUserAgentData | null,
}

/**
 * Creates a 53-bit long hash of a string.
 *
 * @param {string} str The string to hash.
 * @param {number} seed The seed to use for hash generation.
 * @return {number} The resulting hash as a 53-bit number.
 * @see {@link https://stackoverflow.com/a/8831937}
 */
function cyrb53(str: string, seed: number = 0x16fe7b0a): number {
  let h1 = 0xdeadbeef ^ seed;
  let h2 = 0x41c6ce57 ^ seed;

  for (let i = 0, ch; i < str.length; i++) {
    ch = str.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }

  h1  = Math.imul(h1 ^ h1 >>> 16, 2246822507);
  h1 ^= Math.imul(h2 ^ h2 >>> 13, 3266489909);
  h2  = Math.imul(h2 ^ h2 >>> 16, 2246822507);
  h2 ^= Math.imul(h1 ^ h1 >>> 13, 3266489909);

  return 4294967296 * (2097151 & h2) + (h1 >>> 0);
}

/** Creates a semi-unique string from browser attributes.
 *
  * @async
  * @return {Promise<string>} Hexadecimally encoded 53 bit number padded to 7 bytes.
  */
async function createFp(): Promise<string> {
  const nav = navigator as RealNavigator;
  let kb = 'none';
  let mem = '1';
  let ua = 'none';

  if (nav.keyboard) {
    kb = Array.from((await nav.keyboard.getLayoutMap()).entries()).sort().map(e => `${e[0]}${e[1]}`).join('');
  }

  if (nav.deviceMemory) {
    mem = nav.deviceMemory.toString();
  }

  if (nav.userAgentData) {
    const uadata = nav.userAgentData;
    let brands = 'none';

    if (uadata.brands && uadata.brands.length > 0) {
      brands = uadata.brands.filter(e => !e.brand.match(/.*ot.*rand.*/gi)).map(e => `${e.brand}${e.version}`).join('');
    }

    ua = `${brands}${uadata.mobile}${uadata.platform}`;
  }

  let width: string | null = store.get('cached_rem_size');
  const body = $<HTMLBodyElement>('body');

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

  const prints: string[] = [
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

  return cyrb53(prints.join('')).toString(16).padStart(14, '0');
}

/**
 * Sets the `_ses` cookie.
 *
 * If `cached_ses_value` is present in local storage, uses it to set the `_ses` cookie.
 * Otherwise if the `_ses` cookie already exits, uses its value instead.
 * Otherwise attempts to generate a new value for the `_ses` cookie
 * based on various browser attributes.
 * Failing all previous methods, sets the `_ses` cookie to a fallback value.
 *
 * @async
 */
export async function setSesCookie() {
  let fp: string | null = store.get('cached_ses_value');

  if (!fp) {
    const m = document.cookie.match(/_ses=([a-f0-9]+)/);

    if (m && m[1]) {
      fp = m[1];
    }
  }

  if (!fp || fp.charAt(0) !== 'd' || fp.length !== 15) {
    // The prepended 'd' acts as a crude versioning mechanism.
    try {
      fp = `d${await createFp()}`;
    }
    // If it fails, use fakeprint "d015c342859dde3" as a last resort.
    catch {
      fp = 'd015c342859dde3';
    }

    store.set('cached_ses_value', fp);
  }

  document.cookie = `_ses=${fp}; path=/; SameSite=Lax`;
}
