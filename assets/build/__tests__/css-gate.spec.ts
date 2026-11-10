import cssGate, { checkCss } from '../css-gate.ts';

describe('css-gate', () => {
  it.each([
    ['nesting', '.a { .b { color: red } }', 'nesting'],
    ['the nesting selector', '.a { & .b { color: red } }', 'css.selectors.nesting'],
    ['nested at-rules', '.a { @media (min-width: 1px) { color: red } }', 'css.selectors.nesting'],
    ['an unknown pseudo-class', '.a:hovering { color: red }', 'no floor browser matches'],
    ['an unknown function', '.a { width: size(1px) }', 'css.types.size'],
    ['@supports font-tech()', '@supports font-tech(color-colrv1) { .a { color: red } }', 'supports.font-tech'],
    ['@layer', '@layer base { .a { color: red } }', 'css.at-rules.layer'],
    ['color-mix()', '.a { color: color-mix(in srgb, red, blue) }', 'color-mix'],
    ['oklch()', '.a { color: oklch(50% 0.1 100) }', 'oklch'],
    ['lab()', '.a { --c: lab(50% 10 10) }', 'css.types.color.lab'],
    ['relative color', '.a { color: rgb(from red r g b) }', 'rgb.relative_syntax'],
    ['container queries', '@container (min-width: 1px) { .a { color: red } }', 'css.at-rules.container'],
    ['container-type', '.a { container-type: inline-size }', 'css.properties.container-type'],
    ['dvh', '.a { height: 100dvh }', 'viewport_percentage_units_dynamic'],
    ['svh', '.a { height: 100svh }', 'viewport_percentage_units_small'],
    ['subgrid', '.a { grid-template-columns: subgrid }', 'grid-template-columns.subgrid'],
    ['@property', '@property --a { syntax: "<length>"; inherits: false }', 'css.at-rules.property'],
    [':has()', '.a:has(.b) { color: red }', 'css.selectors.has'],
    [':is()', ':is(.a, .b) { color: red }', 'css.selectors.is'],
    [':where()', ':where(.a) { color: red }', 'css.selectors.where'],
    [':focus-visible', '.a:focus-visible { color: red }', 'css.selectors.focus-visible'],
    [':not() lists', '.a:not(.b, .c) { color: red }', 'not.selector_list'],
    ['complex :not()', '.a:not(.b .c) { color: red }', 'not.selector_list'],
    ['alignment to the writing mode in a flex container', '.a { justify-content: start }', 'justify-content.start'],
    ['aspect-ratio', '.a { aspect-ratio: 1 }', 'css.properties.aspect-ratio'],
    ['inset', '.a { inset: 0 }', 'css.properties.inset'],
    ['margin-inline', '.a { margin-inline: 0 }', 'css.properties.margin-inline'],
    ['padding-block', '.a { padding-block: 0 }', 'css.properties.padding-block'],
    ['translate', '.a { translate: 1px }', 'css.properties.translate'],
    ['a feature that only a negated @supports tests', '@supports not (inset: 0) { .a { inset: 0 } }', 'inset'],
    ['media ranges', '@media (width >= 1px) { .a { color: red } }', 'range_syntax'],
    ['a selector list that some browser drops', '.a, .b:focus-visible { color: red }', 'split the rule'],
    ['an unprefixed property without its prefix', '.a { user-select: none }', 'css.properties.user-select'],
    ['an unknown property', '.a { colour: red }', 'css.properties.colour'],
  ])('rejects %s', (_, css, problem) => {
    expect(checkCss(css).join('\n')).toContain(problem);
  });

  it('accepts what the floor browsers have and what the build emits', () => {
    expect(
      checkCss(`
        @namespace xhtml url("http://www.w3.org/1999/xhtml");
        * xhtml|* { all: unset; display: revert }
        @media (min-width: 600px) and (prefers-reduced-motion) { .a:not(.b):not(.c) > .d + .e { margin: 0 } }
        .a { -webkit-user-select: none; user-select: none; width: -moz-fit-content; width: fit-content }
        .a.focus-visible { outline: 1px solid; accent-color: red }
        .a { display: flex; gap: 1px }
        .grid { display: grid; gap: 1px; grid-template-columns: repeat(2, minmax(0, 1fr)) }
        ::-webkit-scrollbar { width: 1px } .a { -webkit-line-break: after-white-space; -webkit-unknown: 1 }
        @supports (color: lab(from red l 1 1% / calc(alpha + 0.1))) { :root { --a: lab(from red l a b) } }
        @keyframes spin { to { transform: rotate(1turn) } } @-webkit-keyframes spin { to { opacity: 1 } }
        [type="a" i] { outline: 0 } .a:-moz-focusring { outline: 0 } ::-webkit-details-marker { display: none }
        :root { --a: rgba(0, 0, 0, 0.5); color: var(--a, hsla(0, 0%, 0%, 1)); width: calc((1px + 2px) * 2) }
        .a { background: -webkit-linear-gradient(red, blue) }
        @supports ((display: grid)) or selector(:hover) { .a { color: red } } @media (-webkit-min-device-pixel-ratio: 2) { .a { color: red } }
      `),
    ).toEqual([]);
  });

  it('fails the build on the stylesheets that need what the floor lacks', () => {
    const error = vi.fn();
    const bundle = {
      'css/a.css': { type: 'asset', fileName: 'css/a.css', source: '.a { inset: 0 }' },
      'css/b.css': { type: 'asset', fileName: 'css/b.css', source: '.b { top: 0 }' },
      'js/a.js': { type: 'chunk', fileName: 'js/a.js', code: '' },
    };
    const { generateBundle } = cssGate() as unknown as { generateBundle: (...args: unknown[]) => void };

    generateBundle.call({ error }, {}, bundle);
    expect(error).toHaveBeenCalledWith(
      expect.stringMatching(/^CSS the floor browsers can't use:\n {2}css\/a\.css: \.a \{ inset \}/),
    );

    error.mockClear();
    generateBundle.call({ error }, {}, { 'css/b.css': bundle['css/b.css'] });
    expect(error).not.toHaveBeenCalled();
  });
});
