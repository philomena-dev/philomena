import postcss from 'postcss';
import cssCompat from '../css-compat.ts';

const run = (css: string, force?: boolean) =>
  postcss(cssCompat({ force })).process(css, { from: 'css/a.css' }).css.replace(/\s+/g, ' ');

describe('css-compat', () => {
  it('lowers logical properties to left-to-right ones but keeps start and end alignment', () => {
    expect(run('.a { margin-inline: 1px 2px; text-align: start }')).toBe(
      '.a { margin-left: 1px; margin-right: 2px; text-align: start }',
    );
  });

  it('renders the fallbacks only when forced', () => {
    const css = '.a { display: flex; gap: 1px }';

    expect(run(css)).toContain('@supports not (list-style-type: "")');
    expect(run(css, true)).not.toContain('@supports');
    expect(run(css, true)).toContain('.a > * + * { margin-left: 1px }');
  });
});
