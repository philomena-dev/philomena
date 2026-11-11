import postcss from 'postcss';
import cssCompat from '../css-compat.ts';
import { checkCss } from '../css-gate.ts';

const reset = '*:where(:not(html, iframe, canvas, img, svg, video, audio):not(svg *, symbol *)) { all: unset }';
const run = (css: string) => postcss(cssCompat()).process(css, { from: 'css/a.css' }).css.replace(/\s+/g, ' ');

describe('css-compat', () => {
  it('lowers logical properties to left-to-right ones but keeps start and end alignment', () => {
    expect(run('.a { margin-inline: 1px 2px; text-align: start }')).toBe(
      '.a { margin-left: 1px; margin-right: 2px; text-align: start }',
    );
  });

  it('raises type selectors to the reset once they are lowered', () => {
    expect(run(`${reset} :where(.a), :where(p) {}`)).toContain(` .a, p${':not(does-not-exist)'.repeat(5)} {}`);
  });

  it('keeps native :focus-visible after its class twin, both at the same specificity', () => {
    expect(run('.a {} :where(a, .b):focus-visible { outline: 0 }')).toBe(
      '.a {} a.focus-visible, .b.focus-visible { outline: 0 } a:focus-visible, .b:focus-visible { outline: 0 }',
    );
  });

  it('gives a :focus-visible alternative of :is() a native rule of its own', () => {
    const css = run('.a:is(:focus-visible, .b) { color: red }');

    expect(css).toBe('.a.focus-visible, .a.b { color: red }.a:focus-visible { color: red }');
    expect(checkCss(css)).toEqual([]);
    expect(() => run('.a:not(.b:focus-visible) {}')).toThrow(':not(.b:focus-visible) has no form');
  });
});
