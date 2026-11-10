import postcss from 'postcss';
import postcssFloorValues from '../postcss-floor-values.ts';

const run = (css: string) => postcss([postcssFloorValues()]).process(css, { from: undefined }).css;

describe('postcss-floor-values', () => {
  it('replaces the declarations a floor browser lacks with ones that render the same', () => {
    expect(
      run('.a { overflow-wrap: anywhere; justify-content: end; float: inline-start; overflow-wrap: normal }'),
    ).toBe('.a { word-break: break-word; justify-content: flex-end; float: left; overflow-wrap: normal }');
  });
});
