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
    const css = '@supports not (scrollbar-color: auto) { .a { color: red } }';

    expect(run(css)).toBe(css);
    expect(run(css, true).trim()).toBe('.a { color: red }');
  });
});
