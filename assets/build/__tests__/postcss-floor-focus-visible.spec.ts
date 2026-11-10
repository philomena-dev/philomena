import postcss from 'postcss';
import postcssFloorFocusVisible from '../postcss-floor-focus-visible.ts';

const run = (css: string) =>
  postcss([postcssFloorFocusVisible()]).process(css, { from: undefined }).css.replace(/\s+/g, ' ');

describe('postcss-floor-focus-visible', () => {
  it('writes a rule for :focus-visible with the class of the polyfill, then natively for its own selectors', () => {
    expect(run('.c:hover {} .a:focus-visible, .b { outline: 0 } [title=":focus-visible"] {}')).toBe(
      '.c:hover {} .a.focus-visible, .b { outline: 0 } .a:focus-visible { outline: 0 } [title=":focus-visible"] {}',
    );
  });

  it('keeps a rule that negates :focus-visible native only, which floor browsers drop', () => {
    expect(run('.a:focus:not(:focus-visible) { outline: 0 }')).toBe('.a:focus:not(:focus-visible) { outline: 0 }');
  });
});
