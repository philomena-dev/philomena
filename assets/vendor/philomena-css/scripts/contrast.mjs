#!/usr/bin/env node
/*
 * Checks the contrast rule of the design against the built stylesheet (run `pnpm run build` first): text and
 * labels, the borders of controls, focus rings, and button text are at least 4.5:1 (WCAG 2) from what they sit on. Other surfaces
 * are printed for information only. Prints every pair for both themes and exits with 1 when one fails. Usage: node scripts/contrast.mjs [stylesheet]
 */
import { readFileSync } from 'node:fs';

const stylesheet = process.argv[2] ?? new URL('../dist/philomena.css', import.meta.url);
const css = readFileSync(stylesheet, 'utf8');
// The dark theme's colors are on :root, the light theme's in the :root[data-theme="light"] block
const block = selector => {
  const open = css.indexOf(`${selector} {`);
  if (open < 0) throw new Error(`No ${selector} block in the stylesheet`);
  return css.slice(open, css.indexOf('\n}', open));
};
const collect = text => {
  const tokens = new Map();
  for (const match of text.matchAll(/(--[a-z0-9-]+-color):\s*([^;]+);/g)) {
    if (!tokens.has(match[1])) tokens.set(match[1], match[2].trim());
  }
  return tokens;
};
const themes = { dark: collect(block(':root')), light: collect(block(':root[data-theme="light"]')) };

const hslToRgb = (hue, saturation, lightness) => {
  const h = ((hue % 360) + 360) % 360;
  const s = saturation / 100;
  const l = lightness / 100;
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  const sectors = [
    [c, x, 0],
    [x, c, 0],
    [0, c, x],
    [0, x, c],
    [x, 0, c],
    [c, 0, x],
  ];
  const [r, g, b] = sectors[Math.min(5, Math.floor(h / 60))];
  return [(r + m) * 255, (g + m) * 255, (b + m) * 255];
};
// An alpha channel may be a number or a percentage
const parseAlpha = (value, percent) => {
  if (value === undefined) return 1;
  return percent ? Number(value) / 100 : Number(value);
};
const parse = value => {
  let m;
  if ((m = value.match(/^#([0-9a-f]{3,8})$/i))) {
    let h = m[1];
    if (h.length <= 4) h = [...h].map(c => c + c).join('');
    const n = parseInt(h.slice(0, 6), 16);
    return { r: n >> 16, g: (n >> 8) & 255, b: n & 255, a: h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1 };
  }
  if ((m = value.match(/^rgba?\(\s*([\d.]+)\s*[, ]\s*([\d.]+)\s*[, ]\s*([\d.]+)\s*(?:[,/]\s*([\d.]+)(%?))?\s*\)$/i))) {
    return { r: Number(m[1]), g: Number(m[2]), b: Number(m[3]), a: parseAlpha(m[4], m[5]) };
  }
  if (
    (m = value.match(
      /^hsla?\(\s*([\d.-]+)(?:deg)?\s*[, ]\s*([\d.]+)%\s*[, ]\s*([\d.]+)%\s*(?:[,/]\s*([\d.]+)(%?))?\s*\)$/i,
    ))
  ) {
    const [r, g, b] = hslToRgb(Number(m[1]), Number(m[2]), Number(m[3]));
    return { r, g, b, a: parseAlpha(m[4], m[5]) };
  }
  throw new Error(`Cannot parse color: ${value}`);
};
const luminance = ({ r, g, b }) => {
  const linear = channel => {
    const c = channel / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
};
// Composites a translucent color over an opaque backdrop
const over = (fg, bg) =>
  fg.a >= 1
    ? fg
    : {
        r: fg.r * fg.a + bg.r * (1 - fg.a),
        g: fg.g * fg.a + bg.g * (1 - fg.a),
        b: fg.b * fg.a + bg.b * (1 - fg.a),
        a: 1,
      };
const ratio = (a, b) => {
  const [l1, l2] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};
const hex = c => `#${[c.r, c.g, c.b].map(v => Math.round(v).toString(16).padStart(2, '0')).join('')}`;

const MIN = 4.5;

let failures = 0;
for (const theme of ['light', 'dark']) {
  // Resolves a token for this theme, composited over its backdrop (a resolved color)
  // A token may point at another one (`var(--tint-color)`); follow the chain to the color
  const resolve = token => {
    let value = themes[theme].get(token);
    for (let hops = 0; value !== undefined && value.startsWith('var(') && hops < 10; hops++) {
      value = themes[theme].get(value.slice(4, -1).trim());
    }
    if (value === undefined) throw new Error(`Missing token ${token} (${theme})`);
    return value;
  };
  const color = (name, backdrop) => over(parse(resolve(`--${name}`)), backdrop);
  const black = { r: 0, g: 0, b: 0, a: 1 };
  const page = color('page-bg-color', black);
  const card = color('surface-color', page);
  const header = color('header-color', page);
  const headerField = color('header-field-color', header);
  const hoveredHeaderField = color('header-field-hover-color', header);
  const well = color('well-color', card);
  const deepWell = color('well-deep-color', card);
  const tint = color('tint-color', card);
  const faintTint = color('tint-faint-color', card);
  const stripe = color('stripe-color', card);
  const hover = color('hover-color', card);
  const hoverWell = color('hover-color', well);
  const white = { r: 255, g: 255, b: 255, a: 1 };
  const types = ['neutral', 'primary', 'success', 'warning', 'danger', 'special'];
  const tags = [
    'default',
    'rating',
    'spoiler',
    'origin',
    'oc',
    'error',
    'character',
    'official',
    'fanmade',
    'species',
    'body',
  ];
  const syntax = ['command', 'flag', 'string', 'number', 'key', 'punctuation'];

  // [label, foreground color, background color]: every pair has to reach MIN
  const checks = [
    // text and labels
    ['page text', color('text-color', page), page],
    ['surface text (labels)', color('text-color', card), card],
    ['muted text on surface', color('muted-text-color', card), card],
    ['link on surface', color('link-color', card), card],
    ['strong link on surface', color('link-strong-color', card), card],
    ['text in well', color('text-color', well), well],
    ['placeholder in well', color('placeholder-color', well), well],
    ['placeholder on hovered well', color('placeholder-color', hoverWell), hoverWell],
    ['text in deep well', color('text-color', deepWell), deepWell],
    ['muted text in deep well', color('muted-text-color', deepWell), deepWell],
    ['strong link in deep well', color('link-strong-color', deepWell), deepWell],
    ['text on tint', color('text-color', tint), tint],
    ['muted text on tint', color('muted-text-color', tint), tint],
    ['bar link on tint', color('bar-link-color', tint), tint],
    ['text on faint tint', color('text-color', faintTint), faintTint],
    ['bar link on faint tint', color('bar-link-color', faintTint), faintTint],
    ['text on stripe', color('text-color', stripe), stripe],
    ['text on hover', color('text-color', hover), hover],
    ['link on hover', color('link-color', hover), hover],
    ['header text', color('header-text-color', header), header],
    ['header brand', color('header-brand-color', header), header],
    ['header field text', color('header-text-color', headerField), headerField],
    ['header field placeholder', color('header-placeholder-color', headerField), headerField],
    ['header field text hovered', color('header-text-color', hoveredHeaderField), hoveredHeaderField],
    [
      'navbar item hovered',
      color('header-text-color', color('hover-shade-color', header)),
      color('hover-shade-color', header),
    ],
    ['combobox header', color('muted-text-color', deepWell), deepWell],
    ['navbar menu icon', color('muted-text-color', well), well],
    ...syntax.map(s => [`code ${s} in well`, color(`syntax-${s}-color`, well), well]),
    [
      'overlay text on white image',
      color('overlay-text-color', color('overlay-color', white)),
      color('overlay-color', white),
    ],
    ['veil text on white image', color('veil-text-color', color('veil-color', white)), color('veil-color', white)],
    // the types: button text, text on tints, bars and washes, badge prefixes
    ...types.flatMap(t => {
      const fill = color(`${t}-color`, card),
        tintBg = color(`${t}-tint-color`, card),
        bar = color(`${t}-bar-color`, card);
      const affix = color(`${t}-affix-color`, card);
      const button = color(`${t}-button-color`, card);
      const rows = [
        [`${t} fill text`, color(`${t}-text-color`, fill), fill],
        [
          `${t} fill text hovered`,
          color(`${t}-text-color`, color('hover-shade-color', fill)),
          color('hover-shade-color', fill),
        ],
        [`${t} button text`, color(`${t}-button-text-color`, button), button],
        [
          `${t} button text hovered`,
          color(`${t}-button-text-color`, color(`${t}-button-hover-color`, button)),
          color(`${t}-button-hover-color`, button),
        ],
        [
          `${t} button text pressed`,
          color(`${t}-button-text-color`, color(`${t}-button-active-color`, button)),
          color(`${t}-button-active-color`, button),
        ],
        [`${t} tint text on tint`, color(`${t}-tint-text-color`, tintBg), tintBg],
        [`${t} text on tint`, color('text-color', tintBg), tintBg],
        [`${t} strong link on tint`, color('link-strong-color', tintBg), tintBg],
        [`${t} tint text on surface`, color(`${t}-tint-text-color`, card), card],
        [`${t} tint text on affix`, color(`${t}-tint-text-color`, affix), affix],
        [`${t} bar text`, color(`${t}-bar-text-color`, bar), bar],
      ];
      const wash = color(`${t}-wash-color`, card);
      rows.push(
        [`${t} text on wash`, color('text-color', wash), wash],
        [`${t} muted text on wash`, color('muted-text-color', wash), wash],
        [`${t} tint text on wash`, color(`${t}-tint-text-color`, wash), wash],
      );
      return rows;
    }),
    // the actions in a media box header, tinted by their kind on the title bar
    ...['spoiler', 'default', 'error'].flatMap(t => [
      [`${t} action on tint bar`, color(`tag-${t}-text-color`, tint), tint],
      [`${t} action filled`, card, color(`tag-${t}-text-color`, card)],
    ]),
    ['comments action filled', card, color('bar-link-color', card)],
    // tags
    ...tags.map(t => [
      `${t} tag text`,
      color(`tag-${t}-text-color`, color(`tag-${t}-color`, card)),
      color(`tag-${t}-color`, card),
    ]),
    ...tags.map(t => [
      `${t} tag count text`,
      color('text-color', color(`tag-${t}-affix-color`, card)),
      color(`tag-${t}-affix-color`, card),
    ]),
    // borders of controls and focus rings
    ['control border on surface', color('control-border-color', card), card],
    ['control border on well', color('control-border-color', well), well],
    ['focus ring on surface', color('focus-color', card), card],
    ['focus ring on well', color('focus-color', well), well],
    ['invalid focus ring on surface', color('danger-tint-text-color', card), card],
    [
      'invalid focus ring on danger tint',
      color('danger-tint-text-color', color('danger-tint-color', card)),
      color('danger-tint-color', card),
    ],
  ];
  // Surfaces that only need to be visible, not to reach a ratio: printed for information
  const informational = [
    ['surface on page', card, page],
    ['header on page', header, page],
    ['tint (container borders, bars) on surface', tint, card],
    ['well on surface', well, card],
    ['deep well on surface', deepWell, card],
    ['accent on surface', color('accent-color', card), card],
    ...types.map(t => [`${t} fill on surface`, color(`${t}-color`, card), card]),
    ...types.map(t => [`${t} tint on surface`, color(`${t}-tint-color`, card), card]),
    ...types.map(t => [`${t} bar on surface`, color(`${t}-bar-color`, card), card]),
    ...types.map(t => [`${t} affix on tint`, color(`${t}-affix-color`, card), color(`${t}-tint-color`, card)]),
  ];

  console.log(`\n${theme.toUpperCase()} THEME   page ${hex(page)}  surface ${hex(card)}`);
  console.log(`  ${'pair'.padEnd(40)} ${'colors'.padEnd(19)}  ratio`);
  for (const [label, fg, bg] of checks) {
    const r = ratio(fg, bg);
    if (r < MIN) failures++;
    console.log(
      `  ${label.padEnd(40)} ${hex(fg)} on ${hex(bg)}  ${r.toFixed(2).padStart(5)}   ${r >= MIN ? 'ok' : 'FAIL'}`,
    );
  }
  for (const [label, fg, bg] of informational) {
    console.log(
      `  ${`(${label})`.padEnd(40)} ${hex(fg)} on ${hex(bg)}  ${ratio(fg, bg).toFixed(2).padStart(5)}   info`,
    );
  }
}

console.log(failures ? `\n${failures} pair(s) below the minimum` : '\nAll pairs meet the minimum ratios');
process.exit(failures ? 1 : 0);
