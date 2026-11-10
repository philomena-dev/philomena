import cssGate, { checkCss } from '../css-gate.ts';

describe('css-gate', () => {
  it.each([
    ['nesting', '.a { .b { color: red } }', 'nesting'],
    ['the nesting selector', '.a { & .b { color: red } }', 'css.selectors.nesting'],
    ['nested at-rules', '.a { @media (min-width: 1px) { color: red } }', 'css.selectors.nesting'],
    ['an unknown pseudo-class', '.a:hovering { color: red }', 'no floor browser matches'],
    ['an unknown function', '.a { width: size(1px) }', 'css.types.size'],
    ['linear() easing, not the linear keyword', '.a { transition: color 1s linear(0, 1) }', 'linear-function'],
    ['@supports font-tech()', '@supports font-tech(color-colrv1) { .a { color: red } }', 'supports.font-tech'],
    ['@layer', '@layer base { .a { color: red } }', 'css.at-rules.layer'],
    ['color-mix()', '.a { color: color-mix(in srgb, red, blue) }', 'color-mix'],
    ['oklch()', '.a { color: oklch(50% 0.1 100) }', 'oklch'],
    ['lab()', '.a { --c: lab(50% 10 10) }', 'css.types.color.lab'],
    ['relative color', '.a { color: rgb(from red r g b) }', 'rgb.relative_syntax'],
    [
      'a function that a floor browser lacks in every spelling given',
      '.a { background: -webkit-image-set(url(a.png) 1x); background: image-set(url(a.png) 1x) }',
      'css.types.image.image-set (missing in firefox 81)',
    ],
    ['container queries', '@container (min-width: 1px) { .a { color: red } }', 'css.at-rules.container'],
    ['container-type', '.a { container-type: inline-size }', 'css.properties.container-type'],
    ['dvh', '.a { height: 100dvh }', 'viewport_percentage_units_dynamic'],
    ['svh', '.a { height: 100svh }', 'viewport_percentage_units_small'],
    ['subgrid', '.a { grid-template-columns: subgrid }', 'grid-template-columns.subgrid'],
    ['@property', '@property --a { syntax: "<length>"; inherits: false }', 'css.at-rules.property'],
    [':has()', '.a:has(.b) { color: red }', 'css.selectors.has'],
    [':is()', ':is(.a, .b) { color: red }', 'css.selectors.is'],
    [':where()', ':where(.a) { color: red }', 'css.selectors.where'],
    [':focus-visible alone', '.a:focus-visible { color: red }', 'without its .focus-visible twin'],
    [
      ':focus-visible beside a twin that differs',
      '.a.focus-visible { color: red } .a:focus-visible { color: blue }',
      'without its .focus-visible twin',
    ],
    [
      ':focus-visible beside a twin elsewhere',
      '@media print { .a.focus-visible { color: red } } .a:focus-visible { color: red }',
      'without its .focus-visible twin',
    ],
    [
      ':focus-visible apart from its twin',
      '.a.focus-visible { color: red } .a.b { color: blue } .a:focus-visible { color: red }',
      'without its .focus-visible twin',
    ],
    [':not() lists', '.a:not(.b, .c) { color: red }', 'not.selector_list'],
    ['complex :not()', '.a:not(.b .c) { color: red }', 'not.selector_list'],
    ['compound :not()', '.a:not(.b.c) { color: red }', 'not.selector_list'],
    ['nested :not()', '.a:not(:not(.b)) { color: red }', 'not.selector_list'],
    [':nth-child() of a selector', '.a:nth-child(2 of .b) { color: red }', 'nth-child.of_syntax'],
    ['the case-sensitive attribute flag', '[type="a" s] { color: red }', 'case_sensitive_modifier'],
    ['justify-content: start in any container', '.a { justify-content: start }', 'justify-content.start'],
    ['align-items: start, which may be in a flex container', '.a { align-items: start }', 'start_in_flex'],
    ['align-self: start, whose container is unknown', '.a { display: grid; align-self: start }', 'align-self.start'],
    ['overflow: clip', '.a { overflow: clip }', 'overflow.clip'],
    ['alternative text of generated content', '.a:before { content: "x" / "" }', 'content.alt_text'],
    [
      'a fallback for another selector',
      '.a:before { content: "x" / "" } @supports not (content: ""/"") { .b:before { content: "x" } }',
      'content.alt_text',
    ],
    ['a thickness in text-decoration', '.a { text-decoration: underline 2px }', 'includes_thickness'],
    ['a color in text-decoration', '.a { text-decoration: underline calc(1px) red }', 'includes_color-and-style'],
    ['aspect-ratio', '.a { aspect-ratio: 1 }', 'css.properties.aspect-ratio'],
    ['inset', '.a { inset: 0 }', 'css.properties.inset'],
    ['margin-inline', '.a { margin-inline: 0 }', 'css.properties.margin-inline'],
    ['padding-block', '.a { padding-block: 0 }', 'css.properties.padding-block'],
    ['translate', '.a { translate: 1px }', 'css.properties.translate'],
    ['a feature that only a negated @supports tests', '@supports not (inset: 0) { .a { inset: 0 } }', 'inset'],
    ['a feature that its @supports does not test', '@supports (display: grid) { .a { inset: 0 } }', 'inset'],
    ['media ranges', '@media (width >= 1px) { .a { color: red } }', 'range_syntax'],
    ['media queries joined by or', '@media (min-width: 1px) or (hover) { .a { color: red } }', 'or_syntax'],
    ['an @import into a layer', '@import "a.css" layer(base);', 'css.at-rules.import.layer'],
    ['an @import with supports()', '@import url(a.css) supports(display: grid);', 'css.at-rules.import.supports'],
    ['an @font-face descriptor a floor browser lacks', '@font-face { ascent-override: 90% }', 'ascent-override'],
    ['an unknown @font-face descriptor', '@font-face { font-colour: red }', 'css.at-rules.font-face.font-colour'],
    ['a selector list that some browser drops', '.a, .b:fullscreen { color: red }', 'split the rule'],
    [':focus-visible beside other selectors', '.a, .b:focus-visible { color: red }', 'split the rule'],
    ['an enhancement beside other selectors', '.a, .b::selection { color: red }', 'split the rule'],
    ['an unprefixed property without its prefix', '.a { user-select: none }', 'css.properties.user-select'],
    ['an unknown property', '.a { colour: red }', 'css.properties.colour'],
    ['a keyword in camel case in the data', '.a { text-decoration: underline currentcolor }', 'currentColor'],
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
        .a.focus-visible, .b { outline: 1px solid; accent-color: red } .a:focus-visible { outline: 1px solid; accent-color: red }
        .c.focus-visible, .d.focus-visible { color: red } .c:focus-visible { color: red } .d:focus-visible { color: red }
        .a:focus:not(:focus-visible) { outline: 0 } [title=":focus-visible"] { color: red }
        .a { display: flex; gap: 1px; row-gap: 1px; column-gap: 1px; align-items: flex-start }
        .fa:before { content: var(--fa) / "" } @supports not (content: ""/"") { .fa:before { content: var(--fa) } }
        @supports not (content: ""/"") { .b:before { content: "x" } } .b:before { content: "x" / "" }
        .a { text-decoration: underline var(--a); text-decoration: var(--a, none) }
        .grid { display: grid; gap: 1px; grid-template-columns: repeat(2, minmax(0, 1fr)); align-items: start }
        .grid { display: grid; justify-content: start; align-content: end; place-items: start; place-content: end }
        ::-webkit-scrollbar { width: 1px } .a { -webkit-line-break: after-white-space; -webkit-unknown: 1 }
        @supports (-webkit-unknown: 1) { .a { color: red } } @import url("a.css") screen;
        @font-face { font-family: a; src: url(a.woff2) format("woff2"); font-display: block; unicode-range: U+0-FF }
        .a { COLOR: red } @media (MIN-WIDTH: 1px) { .a { color: red } } @font-face { font-family: a; SRC: url(a.woff2) }
        @supports (color: lab(from red l 1 1% / calc(alpha + 0.1))) { :root { --a: lab(from red l a b) } }
        @keyframes spin { to { transform: rotate(1turn) } } @-webkit-keyframes spin { to { opacity: 1 } }
        [type="a" i] { outline: 0 } .a::selection { color: red } .a:-moz-focusring { outline: 0 } ::-webkit-details-marker { display: none }
        :root { --a: rgba(0, 0, 0, 0.5); color: var(--a, hsla(0, 0%, 0%, 1)); width: calc((1px + 2px) * 2) }
        .a { background: -webkit-linear-gradient(red, blue); background: linear-gradient(red, blue) }
        @supports ((display: grid)) or selector(:hover) { .a { color: red } } @media (-webkit-min-device-pixel-ratio: 2) { .a { color: red } }
      `),
    ).toEqual([]);
  });

  it('judges value keywords and units only where browser-compat-data records them', () => {
    expect(checkCss('.a { display: flox; width: 1zz }')).toEqual([]);
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
