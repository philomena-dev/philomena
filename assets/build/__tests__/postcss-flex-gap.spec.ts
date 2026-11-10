import postcss from 'postcss';
import postcssFlexGap from '../postcss-flex-gap.ts';
import { lacking } from '../floor.ts';

const run = (css: string) =>
  postcss([postcssFlexGap()]).process(css, { from: undefined }).css.replace(/\s+/g, ' ').replace(/"/g, "'");

const fallback = (rules: string) => `@supports not (list-style-type: '') { ${rules} }`;

describe('postcss-flex-gap', () => {
  it('selects exactly the floor browsers without flex gap', () => {
    expect(lacking('css.properties.list-style-type.string')).toEqual(lacking('css.properties.gap.flex_context'));
  });

  it('spaces the children of a nowrap row or column', () => {
    expect(run('.a { display: flex; /* row */ gap: 1px 2px }')).toBe(
      `.a { display: flex; /* row */ gap: 1px 2px } ${fallback('.a { row-gap: 0; column-gap: 0 } .a > * + * { margin-left: 2px }')}`,
    );
    expect(run('.a { flex-flow: column-reverse; row-gap: normal !important }')).toBe(
      `.a { flex-flow: column-reverse; row-gap: normal !important } ${fallback(
        '.a { row-gap: 0 !important; column-gap: 0 !important } .a > * + * { margin-bottom: 0 !important }',
      )}`,
    );
  });

  it('gives the children of a wrapping container its gaps at their end, and leaves grids alone', () => {
    expect(run('.a { display: flex; flex-flow: wrap } .a.b { column-gap: 3px } .c { display: grid; gap: 1px }')).toBe(
      `.a { display: flex; flex-flow: wrap } .a.b { column-gap: 3px } ${fallback(
        '.a.b { row-gap: 0; column-gap: 0; margin-right: calc(-1 * 3px); margin-bottom: calc(-1 * 0) } ' +
          '.a.b > * { margin-right: 3px; margin-bottom: 0 }',
      )} .c { display: grid; gap: 1px }`,
    );
  });

  it('takes back the margins of a rule for the same elements that lays them out another way', () => {
    expect(run('.a { display: flex; gap: 1px } .a.b { flex-direction: column; display: grid; gap: 0 }')).toContain(
      fallback('.a.b > * { margin-left: 0 }'),
    );
  });

  it('refuses gaps that have no margin form', () => {
    expect(() => run('.a { display: flex; gap: inherit }')).toThrow('has no margin fallback');
    expect(run('@keyframes a { to { gap: inherit } }')).toBe('@keyframes a { to { gap: inherit } }');
  });
});
