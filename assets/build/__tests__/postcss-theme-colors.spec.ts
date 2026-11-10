import postcss from 'postcss';
import postcssThemeColors from '../postcss-theme-colors.ts';

const theme = '/srv/css/themes/purple.css';
const legacy = '/srv/css/legacy.css';
const run = (css: string, from?: string) =>
  postcss([postcssThemeColors({ themes: [theme], keep: [legacy] })])
    .process(css, { from })
    .css.replace(/\s+/g, ' ')
    .trim();

describe('postcss-theme-colors', () => {
  it('keeps only the color tokens of a theme stylesheet', () => {
    const css =
      '@charset "UTF-8"; :root { --z-menu: 6; --text-color: #fff; color: red } ' +
      '@media (prefers-color-scheme: light) { :root { --text-color: #000 } } ' +
      '@media (min-width: 800px) { :root { --header-height: 2rem } } ' +
      '@supports (color: red) { @media print { :root { /* sizes */ --tag-border: 0px } } }';

    expect(run(css, theme)).toBe(
      '@charset "UTF-8"; :root { --text-color: #fff } @media (prefers-color-scheme: light) { :root { --text-color: #000 } }',
    );
  });

  it('keeps every declaration of the stylesheets it is told to keep', () => {
    const root = postcss.parse(':root { --z-menu: 6 }', { from: theme });
    root.append(postcss.parse(':root { --input-border: #000 }', { from: legacy }).nodes);

    expect(postcss([postcssThemeColors({ themes: [theme], keep: [legacy] })]).process(root).css).toBe(
      ':root { --input-border: #000 }',
    );
  });

  it('leaves every other stylesheet alone', () => {
    const css = ':root { --z-menu: 6 }';

    expect(run(css, '/srv/css/application.css')).toBe(css);
    expect(run(css)).toBe(css);
    expect(postcss([postcssThemeColors()]).process(css, { from: theme }).css).toBe(css);
  });
});
