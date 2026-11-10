import postcss from 'postcss';
import postcssFloorReset from '../postcss-floor-reset.ts';

const reset =
  '*:where(:not(html, iframe, canvas, img, svg, video, audio):not(svg *, symbol *)) { all: unset; display: revert }';
const run = (css: string) => postcss([postcssFloorReset()]).process(css, { from: undefined }).css;

describe('postcss-floor-reset', () => {
  it('unsets HTML elements by namespace and gives the replaced elements back their browser styles', () => {
    expect(run(`@import "a.css";\n${reset}\na {}`)).toBe(
      '@import "a.css";\n@namespace xhtml url("http://www.w3.org/1999/xhtml");\n* xhtml|* { all: unset; display: revert }\n' +
        'iframe, canvas, img, video, audio{ all: revert; box-sizing: border-box }\na {}',
    );
    expect(run(reset)).toMatch(/^@namespace xhtml url\("http:\/\/www.w3.org\/1999\/xhtml"\);\n\* xhtml\|\*/);
    expect(run('*:where(:not(html)) {}')).toBe('*:where(:not(html)) {}');
  });
});
