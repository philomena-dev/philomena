import postcss from 'postcss';
import cssCompat from '../css-compat.ts';

const run = (css: string) => postcss(cssCompat()).process(css, { from: 'css/a.css' }).css.replace(/\s+/g, ' ');

describe('css-compat', () => {
  it('lowers logical properties to left-to-right ones but keeps start and end alignment', () => {
    expect(run('.a { margin-inline: 1px 2px; text-align: start }')).toBe(
      '.a { margin-left: 1px; margin-right: 2px; text-align: start }',
    );
  });

  it('keeps native :focus-visible after its class twin, both at the same specificity', () => {
    expect(run('.a {} :where(a, .b):focus-visible { outline: 0 }')).toBe(
      '.a {} a.focus-visible, .b.focus-visible { outline: 0 } a:focus-visible, .b:focus-visible { outline: 0 }',
    );
  });
});
