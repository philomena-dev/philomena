import postcss from 'postcss';
import postcssFloorSelectors from '../postcss-floor-selectors.ts';

const lower = (css: string) => postcss([postcssFloorSelectors()]).process(css, { from: undefined }).css;

describe('postcss-floor-selectors', () => {
  it('expands :where() and :is() into alternatives at their own specificity, at least that of :is()', () => {
    expect(lower(':where(a, .b) > :where(p, ul) {}')).toBe('a > p, a > ul, .b > p, .b > ul {}');
    expect(lower('.x:where(a, *):hover, *:where(.y) {}')).toBe('a.x:hover, .x:hover, *.y {}');
    expect(lower('a:where(a, b), *:where(a) {}')).toBe('a, a {}');
    expect(lower(':is(blockquote, .blockquote):before {}')).toBe(
      'blockquote:not(.does-not-exist):before, .blockquote:before {}',
    );
    expect(lower(':is(#a, b) {}')).toBe('#a, b:not(#does-not-exist) {}');
    expect(lower(':is(b, a.c) {}')).toBe('b:not(.does-not-exist), a.c {}');
    expect(lower(':is(.a, b.c) {}')).toBe('.a:not(does-not-exist), b.c {}');
  });

  it('gives :not() one compound at a time', () => {
    expect(lower('.a:not(.b, :is(.c, .d)) {}')).toBe('.a:not(.b):not(.c):not(.d) {}');
    expect(lower('.a:not(:not(.b, .c)) {}')).toBe('.a:not(:not(.b):not(.c)) {}');
    expect(() => lower('a:not(.tag a) {}')).toThrow(':not(.tag a) has no form');
    expect(() => lower(':where(.a .b) {}')).toThrow('has a combinator');
  });

  it('drops the selectors that a floor browser can not match, keeping enhancements and vendor ones', () => {
    expect(lower('.a:has(b), .c {} .d:has(e) {} .f:user-invalid {}')).toBe('.c {}');
    expect(lower('.popup::backdrop, ::-webkit-scrollbar {}')).toBe('.popup::backdrop, ::-webkit-scrollbar {}');
    expect(lower('@keyframes spin { from {} to {} }')).toBe('@keyframes spin { from {} to {} }');
  });
});
