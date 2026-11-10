import { polyfillFocusVisible } from '../focus-visible';

describe('polyfillFocusVisible', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    document.documentElement.classList.remove('js-focus-visible');
  });

  it('leaves browsers with :focus-visible alone', () => {
    vi.stubGlobal('CSS', { supports: (condition: string) => condition === 'selector(:focus-visible)' });
    polyfillFocusVisible();

    expect(document.documentElement).not.toHaveClass('js-focus-visible');
  });

  it('polyfills browsers without :focus-visible', () => {
    vi.stubGlobal('CSS', { supports: () => false });
    polyfillFocusVisible();

    expect(document.documentElement).toHaveClass('js-focus-visible');
  });
});
