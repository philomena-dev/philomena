import postcss from 'postcss';
import postcssFloorSupports from '../postcss-floor-supports.ts';

const run = (css: string) =>
  postcss([postcssFloorSupports()]).process(css, { from: undefined }).css.replace(/\s+/g, ' ').trim();

describe('postcss-floor-supports', () => {
  it('settles the conditions on selectors that the build drops', () => {
    expect(run('@supports not selector(:user-invalid) { .a {} }')).toBe('.a {}');
    expect(run('@supports selector(:has(a)) { .a {} } .b {}')).toBe('.b {}');
    expect(run('@supports selector(:hover) or (gap: 0) { .a {} }')).toBe(
      '@supports selector(:hover) or (gap: 0) { .a {} }',
    );
    expect(run('@supports selector(:has(a)) or selector(:user-invalid) { .a {} }')).toBe('');
    expect(run('@supports (not selector(:has(a))) and (not selector(:user-invalid)) { .a {} }')).toBe('.a {}');
    expect(run('@supports (gap: 0) and selector(:has(a)) { .a {} }')).toBe('');
    expect(run('@supports not (gap: 0) { .a {} } @supports --x { .b {} }')).toBe(
      '@supports not (gap: 0) { .a {} } @supports --x { .b {} }',
    );
    expect(run('@supports (display: grid) and (gap: 0) { .a {} }')).toBe(
      '@supports (display: grid) and (gap: 0) { .a {} }',
    );
    // The build twins :focus-visible instead of dropping it, so whether a browser has it is decided at runtime
    expect(run('@supports not selector(:focus-visible) { .a {} }')).toBe(
      '@supports not selector(:focus-visible) { .a {} }',
    );
  });
});
