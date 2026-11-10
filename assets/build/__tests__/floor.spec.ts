import { buildTarget, floor, lacking, oldest } from '../floor.ts';

describe('floor', () => {
  it('takes the oldest version of every browser in .browserslistrc', () => {
    expect(oldest(['chrome 90', 'chrome 85', 'chrome 99', 'ios_saf 14.5-14.8', 'ios_saf 14.0-14.4'])).toEqual({
      chrome: '85',
      ios_saf: '14.0',
    });
    expect(() => oldest(['opera 71'])).toThrow('does not map');

    expect(floor).toEqual({ chrome: '85', edge: '85', firefox: '81', safari: '14.1', safari_ios: '14.5' });
    expect([...buildTarget].sort()).toEqual(['chrome85', 'edge85', 'firefox81', 'ios14.5', 'safari14.1']);
  });

  it('names the floor browsers that lack a feature as the CSS spells it', () => {
    expect(lacking('css.selectors.has')).toEqual(expect.arrayContaining(['chrome', 'firefox', 'safari']));
    expect(lacking('css.selectors.not')).toEqual([]);
    expect(lacking('css.properties.user-select', '-webkit-user-select')).not.toContain('safari');
    expect(lacking('css.properties.user-select', '-khtml-user-select')).toContain('safari');
    expect(lacking('css.selectors.is', '-webkit-any')).not.toContain('chrome');
    expect(lacking('css.selectors.is')).toEqual(['chrome', 'edge']);
    expect(lacking('css.properties.no-such-property')).toBeUndefined();
  });
});
