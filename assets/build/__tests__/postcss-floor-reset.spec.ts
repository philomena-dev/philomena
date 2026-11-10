import postcss from 'postcss';
import postcssFloorReset from '../postcss-floor-reset.ts';

const reset =
  '*:where(:not(html, iframe, canvas, img, svg, video, audio):not(svg *, symbol *)) { all: unset; display: revert }';
const run = (css: string) => postcss([postcssFloorReset()]).process(css, { from: undefined }).css;
const raised = ':not(does-not-exist)'.repeat(5);

describe('postcss-floor-reset', () => {
  it('unsets the HTML elements but the replaced ones, at the place of the reset among the other rules', () => {
    expect(run(`@charset "UTF-8";\n.fa {}\n${reset}\nul li, ::placeholder, a:hover {}\n@keyframes a { to {} }`)).toBe(
      `@charset "UTF-8";\n@namespace xhtml url("http://www.w3.org/1999/xhtml");\n.fa {}\n` +
        '* xhtml|*:not(iframe):not(canvas):not(img):not(video):not(audio) { all: unset; display: revert }\n' +
        `ul li${raised}, ::placeholder, a:hover {}\n@keyframes a { to {} }`,
    );
  });

  it('leaves stylesheets without the reset alone', () => {
    expect(run('*:where(:not(html)) {} h1 {}')).toBe('*:where(:not(html)) {} h1 {}');
  });
});
