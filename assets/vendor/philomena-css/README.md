# @philomena/philomena-css

The design of [Philomena](https://philomena.dev) as an extensible, **HTML/CSS-only** framework.
No JavaScript components are included, the stateful components only ship the styling hooks
(`.visible`, `[open]`, `.is-open`, ...) that your own markup or script toggles.

## Usage

Use the compiled stylesheet:

```html
<link rel="stylesheet" href="node_modules/@philomena/philomena-css/dist/philomena.css" />
```

`dist/philomena.css` (and `.min.css`) works in browsers from March 2022 onwards (Safari 15.4, Chrome and Edge 100,
Firefox 98). Every color is computed at build time, so relative color syntax is not needed in the browser. A few
enhancements use `:has()` and are simply absent where it is missing (Firefox before 121): the one-row pagination on
narrow screens, the fading of a disabled checkbox or radio without a `.disabled` wrapper, the frame color of a
colored table and the scroll lock behind an open popup. Everything is still controlled with custom properties, so single tokens can be overridden in plain CSS:

```css
:root {
  --border-radius-inner: 0.5rem; /* any value token */
  --surface-color: #1a1a1a; /* any color token, for the dark theme (the default) */
}

/* The light theme's colors are set where the stylesheet sets them: for the system preference and for data-theme */
:root[data-theme='light'] {
  --surface-color: #fff;
}

@media (prefers-color-scheme: light) {
  :root:not([data-theme='dark']) {
    --surface-color: #fff;
  }
}
```

Token reference:

| Property                                 | Meaning                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--*-color`                              | Colors, set per theme: the dark theme's on `:root` (the default), the light theme's for the system preference and for `data-theme="light"`                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `--{type}-*-color`                       | The roles of a semantic color, from the `type-color` mixin: `-color`, `-text-color`, `-border-color` (a strong fill: counters, switches, the current page), `-button-color`, `-button-text-color` (a button: the strong fill on the dark theme, a pale tint with dark text on the light one), `-tint-color`, `-tint-text-color` (alerts, badges, table rows), `-bar-color`, `-bar-text-color` (title bars), `-wash-color` (a card body), `-affix-color` (a badge's prefix, a pagination link's hover). The types are `neutral`, `primary`, `success`, `warning`, `danger` and `special` |
| `--tag-{category}-*-color`               | A tag category's `-color`, `-text-color` and `-affix-color`, from the `tag-color` mixin                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `--*-font`                               | Font families: `--base-font`, `--mono-font`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `--spacing-*`                            | The spacing scale: `tiny` .1rem, `small` .25rem, `medium` .4rem, `large` .8rem, `huge` 1.2rem, aliased as `xs`, `sm`, `md`, `lg`, `xl`. Every padding, margin and gap is a step of it, as are the `.m-{key}` / `.p-{key}` utilities                                                                                                                                                                                                                                                                                                                                                     |
| `--block-spacing`, `--heading-spacing`   | The rhythm: significant blocks that follow each other (cards, tables, alerts, code blocks ...) and headings keep a large distance, controls (buttons, badges, form controls) and a run of alerts (`--alert-gap`) a medium one. The rules have no specificity, your own margins win                                                                                                                                                                                                                                                                                                      |
| `--border-radius-*`                      | The radii: `inner` .2rem for controls inside a block, `outer` .3rem for cards and other blocks, `large` .5rem for badges; `--tag-border-radius` (inner by default) for tags                                                                                                                                                                                                                                                                                                                                                                                                             |
| `--border-width`, `--border-thick-width` | The border widths: 1px for borders and dividers, 2px for emphasis                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `--base-font-size`, `--*-size`           | Philomena's font sizes: 14px text (every rem is a multiple of it), `--header-font-size` 16px for the header and navbar, `--heading-1-size` 1.75rem down to `--heading-6-size` 1rem. Headings are not bold                                                                                                                                                                                                                                                                                                                                                                               |
| `--*-line-height`                        | Philomena's line heights: `base` 1.15 for the page, `heading` 1.15, `text` 1.35 for paragraphs, alert text, accordion bodies and code                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `--z-*`                                  | Layering, from the page up: `focus`, `header`, `menu` (dropdowns, navbar menus), `suggestions`, `popup`, then the burger's `sidebar-overlay` and `sidebar`                                                                                                                                                                                                                                                                                                                                                                                                                              |
| everything else                          | Sizes, typography and other values (`--button-padding-horizontal`). Responsive ones have breakpoint overrides inside the stylesheet                                                                                                                                                                                                                                                                                                                                                                                                                                                     |

Names are at most four words.

Themes are switched with `data-theme="dark|light"` on `:root` (defaults to `prefers-color-scheme`, dark when the
browser states no preference). The framework is written for left-to-right pages; right-to-left layouts are not
supported. To change a responsive value at one breakpoint, override the property inside your own `@media` rule.

### Building from the sources (PostCSS)

The sources in `css/` are plain CSS files built with PostCSS and three plugins, the same ones and in the same order
as Philomena: [postcss-mixins](https://github.com/postcss/postcss-mixins),
[postcss-simple-vars](https://github.com/postcss/postcss-simple-vars) and
[@csstools/postcss-relative-color-syntax](https://github.com/csstools/postcss-plugins/tree/main/plugins/postcss-relative-color-syntax).
`@import`s are inlined by your bundler (Vite does it out of the box). You can reuse the package's configuration:

```js
// postcss.config.js
export { default } from '@philomena/philomena-css/postcss.config.js';
```

Configuration is done with `$variables`. Because they are substituted where they are defined, set them in a file of
your own that is imported **between** the configuration and the framework (all `@import`s have to come first, so
they cannot go in the same file):

```css
/* philomena-overrides.css */
$base-color-dark: #99501e;
$base-color-light: #e8590c;
$primary-color: #7a3e9d;
$breakpoint-md: 800px;
```

```css
/* your stylesheet */
@import '@philomena/philomena-css/css/config.css';
@import './philomena-overrides.css';
@import '@philomena/philomena-css/css/framework.css';
```

See [`css/config.css`](css/config.css) for every setting. The palette has a base color, a page color, a surface
color, a text color and a link color per theme (`-light` / `-dark`), and the primary, success, danger, warning and
special hues shared by both (special is Philomena's purple assistant color), plus the tag category hues. The defaults are Philomena's light-blue and dark-blue themes. The colors derived from them use relative color syntax on
`$variables` (`hsl(from $base-color-light h calc(s - 28) 35%)`), which the plugin computes into a static color. Use
`$variables` and not `var(--variables)` as the origin of a relative color: a `var()` can't be computed at build time
and would be left for the browser, which older browsers don't understand.

### Contrast

The palette is laid out for contrast, measured with the WCAG 2 formula. Text and labels, the borders of controls, focus
rings, and button text are at least **4.5:1** from what they sit on:

- text, including placeholders, muted text, links and syntax colors, against its background (body text is over 9:1)
- the borders of controls (inputs, the tag box) and focus rings against the surfaces they separate
- button text against the button, also hovered and pressed (the fill against the card is not enforced: a button is
  a pale tint with a border on the light theme and sits close to the card on the dark one, on purpose)

Everything else keeps Philomena's tones: the page under the cards, inputs, badges, alerts and code are tints rather
than contrasting blocks. Containers (cards, blocks, tables, code blocks, media boxes) have subtle borders in
the tint of their title bar and a very subtle bevel, one pixel inside the border: raised pieces (containers,
buttons, badges, tags, paginations) are lit from the top left (`--emphasis-shadow`), wells (inputs, pressed buttons)
are the reverse (`--well-shadow`). On the dark theme a raised piece also has a line of shadow outside its bottom
and right edges (`--raised-shadow`).

The lightness of every derived color is fixed, so the ratios hold for other base colors too, give or take a little.
`pnpm run check:contrast` measures every pair in the built stylesheet (`pnpm run build` first) and fails when one is
below 4.5:1; CI runs it on every pull request.

Single components can be used on their own, after the design layer:

```css
@import '@philomena/philomena-css/css/config.css';
@import '@philomena/philomena-css/css/design/index.css';
@import '@philomena/philomena-css/css/components/button.css';
```

The design layer also defines the mixins the framework is built with (`css/design/mixins.css`), for example
`@mixin button-color-variation accent;` adds `.button.button-accent` from `--accent-color`, `--accent-text-color` and `--accent-border-color` tokens (`badge-color-variation`, `alert-color-variation`, `pagination-color-variation` and the other `*-color-variation` mixins do the same for the other components), and
`@mixin margin-utilities xxl;` adds the margin utilities for a `--spacing-xxl` token.

## Markup notes

The framework is plain CSS, so some structure is on you:

- **What CSS cannot do.** The script-free pieces cover opening and closing only. Hover menus (navbar, dropdown) do
  not close on Escape and cannot keep `aria-expanded` up to date; the burger menu does not trap the focus or stop the
  page scrolling behind it; tabs need a script for the selection, arrow keys and `aria-controls`; a clamp's hidden
  checkbox stays a tab stop when nothing is cut, so leave it out (or disable it) for text you know is short. Add a
  script where these matter.
- **Badge-sized buttons.** `.button-size-badge` on a `.button`, or on a `.button-group` to size every button in
  it, gives buttons the size and shape of a badge (`--badge-*` sizes, `--border-radius-large`) for toolbars and
  list rows.
- **Media box actions.** `.media-box-header.actions` is the header of a Philomena image thumbnail: a row of
  `.media-box-action` links with a kind (`.fave`, `.upvote`, `.downvote`, `.comments`, `.hide`) and a
  `.media-box-score`. An action has the color of its kind, taken from the tag palette, and is filled with it when hovered or `.active`.
- **Navbar.** `<nav class="navbar">` holds `.navbar-item` links (with an optional `.navbar-icon`). Wrap an item
  and a `.navbar-menu` in a `.navbar-dropdown` for a menu of `.navbar-menu-item`s (a `.navbar-menu-icon` and a
  `.navbar-menu-text` each, `<hr class="navbar-menu-divider">` between groups). Menus open on hover and on focus
  without a script; toggle `.open` on the dropdown for touch screens. A `.navbar-spacer` pushes the items after it
  to the end. The bar is one row and never wraps: below the `md` breakpoint only the `.navbar-burger` item (the
  label that opens a burger menu) and `.navbar-pinned` items stay. If your bar is too long for tablets, hide the text
  of secondary items there with `.hidden-below-lg` or `.hidden-below-xl`. A `.header` runs from edge to edge of the screen,
  so it keeps only the bottom line of the inset shadow; `.navbar.flush` does the same for a bar outside a header. `.header.borderless` has no line along its bottom, for a header with a
  navbar (or another bar) stacked right under it.
- **Color variants** are always `{component}-{type}`: `.button-primary`, `.alert-danger`, `.progress-success`,
  `.table-warning` (on a table, a row or a cell), `.media-danger` (on a media box or an overlay),
  `.dropdown-danger` on a dropdown item, and so on.
- **Invalid inputs.** An `.input-field` turns red once the user has edited it into an invalid state, not while a
  required field is still empty. Add `.invalid` to mark one from your script or server. A `readonly` text field or
  textarea is flat with a dashed border; other controls have no read-only state, disable them instead.
- **Scrollbars** are thin and tinted for the theme everywhere, through `--scrollbar-thumb-color` and
  `--scrollbar-track-color`.
- **Accordion, nav, progress.** `.accordion` frames `.accordion-item`s with an `.accordion-item-header` and an
  `.accordion-item-body` (use `<details>` and `<summary>` for script-free items). `.nav` is a column of
  `.nav-link`s, a row with `.horizontal`. `.progress` holds a `.progress-bar` whose width you set.
- **Alerts.** `.alert` is a flat tinted bar of text and links, as Philomena's flash notices: it has no title or
  action slots. An optional `.alert-icon` goes first, with the text in an `.alert-text` beside it. It is neutral; `.alert-{type}` tints it, like the variants of every other component. Paragraphs and lists in an alert (or its `.alert-text`) are spaced as running text.
- **Editor.** `.editor` frames a `<textarea class="editor-input">` with an `.editor-toolbar` of flat
  `.editor-button`s (in `.editor-toolbar-group`s, `.active` for a format that is on, an `.editor-toolbar-spacer`
  to push buttons to the end) and an optional `.editor-footer`. The textarea is resized by its lower edge;
  `.mono` sets it in the monospace font. The buttons do nothing by themselves, wire them up in your script.
- **Dropdowns.** A `.dropdown` wraps any trigger and a `.dropdown-menu` of `.dropdown-item`s. It opens on hover and
  on focus without a script, `.open` holds it open and `.manual` turns the hover off.
- **Menus with controls.** An item of a dropdown or navbar menu can be a `<label>` holding a control: a checkbox or
  radio drawn in CSS (`.menu-check-input` followed by `.menu-check-box`) or a switch (`.form-switch-input`, which
  works on its own anywhere). `.menu-end` puts the control at the end of the row. A `<details class="dropdown">`
  with a `<summary>` trigger opens on click and stays open, and `.dropdown-actions` is a row of buttons in a menu.
- **Burger menu.** A `.burger` panel slides in from the start side over a `.burger-overlay`. Toggle `.open` on
  both, or put a `.burger-toggle` checkbox before them and use labels as the buttons for a script-free menu.
- **Tabs.** `.tabs` holds `.tab` links, followed by one `.tab-panel` each. Your script moves `.selected` between
  them. Wrap the bar and the panels in a `.side-tabs` to get the tabs as a column next to the panel
  (`--side-tabs-width` wide, with `.tabs-title` headings between groups); the tabs can also be plain links to other
  pages, each of which marks its own tab `.selected`. Below `md` the column is a list over the panel; with a `.side-tabs-toggle` checkbox before the bar and a
  `.side-tabs-expand` label inside it, that list is a selector that only shows the selected tab until it is clicked.
- **Spoiler text.** `<span class="spoiler">` is blacked out until hovered or focused, `.revealed` shows it for good.
- **Separators.** `<hr>` and `.separator` draw a rule in the border tint, with `.thin` and `.vertical` variants.
- **Sliders.** `<input class="slider" type="range">`. Set `--slider-fill` to the value as a percentage for a
  filled track outside Firefox.
- **Selection.** `.user-select-none` stops text from being selected, `.user-select-all` selects it as a whole.
- **Utilities, named as in Tailwind.** They use the framework's own scales and are `!important`, so they win over
  a component's styles.
  - Spacing: `.p-{key}`, `.px-`, `.py-`, `.pt-`, `.pb-`, `.pl-`, `.pr-`, `.ps-`, `.pe-` and the same with `m`, for
    the keys `0`, `xs`, `sm`, `md`, `lg`, `xl` of the spacing scale; `.m-auto`, `.mx-auto`, `.ms-auto` and the
    other sides take the free space.
  - Gap: `.gap-{key}`, `.gap-x-{key}`, `.gap-y-{key}`.
  - Flex: `.flex`, `.inline-flex`, `.flex-row`, `.flex-col` (and `-reverse`), `.flex-wrap`, `.flex-nowrap`,
    `.items-{start|center|end|stretch|baseline}`, `.justify-{start|center|end|between|around|evenly}`,
    `.self-{start|center|end|stretch}`, `.flex-1`, `.flex-auto`, `.flex-none`, `.grow`, `.grow-0`, `.shrink`,
    `.shrink-0`.
  - Grid: `.grid`, `.inline-grid`, `.grid-cols-{1-6|12}`, `.grid-cols-auto` (as many columns of at least
    `--grid-auto-column-width` as fit), `.col-span-{1-6|12}`, `.col-span-full`, `.place-items-center`.
  - Text size: `.text-xs`, `.text-sm`, `.text-base`, `.text-lg`, `.text-xl`, `.text-2xl`, `.text-3xl`, from the
    `--text-size-{key}` tokens (in rem).
  - Text alignment: `.text-left`, `.text-center`, `.text-right`, also on the cells of a table.

  There are no responsive (`md:`) or state (`hover:`) variants; use the `.hidden-*` utilities and your own CSS
  for those.

- **Layout and visibility.** `.layout-columns` with `.layout-side` and `.layout-main`, `.layout-narrow`,
  `.layout-center`, the `.flex` helpers and `.gap-{key}`, and `.hidden`, `.hidden-below-{breakpoint}`,
  `.hidden-from-{breakpoint}` and `.hidden-print`.
- **Avatars.** `.avatar` on an `<img>`, or on an element holding an image, an inline `<svg>` or initials, with a
  size: `.avatar-xs` 28px, `.avatar-sm` 50px, `.avatar-md` 100px, `.avatar-lg` 125px. `.square` and `.avatar-group`
  are variants.
- **Clamped text.** Put `<input class="clamp-toggle" type="checkbox">` right before a `.clamp` element, and
  `.clamp-more` / `.clamp-less` labels for it inside, to cut text off after `--clamp-max-height` (six lines by
  default, any length works) behind a click, without a script. The label and a fade towards the cut only appear when
  at least a line is cut. Set `--clamp-bg-color` when the text is not on the surface color.
- **Communications.** `.communication` is a comment or post: a `.communication-body` with an avatar and a
  `.communication-content` (a `.communication-author` with the name and role badges, then the text), over
  `.communication-options` with two groups of links. Make the text a clamp (`.communication-text.clamp` after a
  `.clamp-toggle`) to cut long comments; `--communication-max-height` sets their limit. On narrow screens the
  avatar and author become a header row. A `.communication-notice` before the body is the site's own line about it
  (a deletion reason, in the danger color on `.communication.deleted`), outside the text so users can't imitate it.
- **Comboboxes.** `.form-control-combobox` on a `.form-control-select` with a text input and a
  `.combobox-suggestions` list is styled only; your script filters, handles the keyboard and sets the state classes
  (`.suggestions-open`, `.has-suggestions`, `.allow-typing`, `.selected` / `.highlighted` on items). Upstream's
  `.has-combobox` class is not needed: nothing here gives every element a z-index.
- **Switches.** `<input class="form-switch-input" type="checkbox">` with a `.form-switch-label` in a
  `.form-control-switch` is a checkbox drawn as a sliding toggle, an alternative to the regular checkbox. It needs
  no wrapper or icon.
- **Counters.** `<span class="counter">3</span>` is a small pill with a number, filled like a button of its color
  (`.counter-{type}`). `.subtle` is a shaded chip for bars and buttons. In a `.counter-anchor`, a `.counter.corner`
  is pinned to the corner of an icon as an unread badge.
- **Pagination.** `<nav class="pagination">` holds `.pagination-link`s (`<a>`, or `<span>` when unavailable),
  one of them `.current`, and `.pagination-gap` for skipped pages (`…`); `.pagination-icon` is a slot for a glyph or icon next to a link's text. `.pagination-{type}`
  colors it, `.pagination-bar` lays it out next to a `.pagination-info` text. On narrow screens only the links with a
  `.pagination-icon` (first, previous, next, last) and the current page show, in one row.
- **Icons are slots, none are shipped.** `.form-checkbox-check-icon`, `.form-select-icon`, `.button-icon` and
  `.loading-icon` are positioned for a fixed-width icon (about `1.25em` wide, `1em` tall, e.g. an inline SVG
  or Font Awesome's `fa-fw`). A text glyph will not line up.
- **Loading buttons need a `.loading-icon` element** placed before `.button-content` inside the button. The icon is
  drawn over the content, which fades to 20%; `.loading` alone only changes the cursor.
- **Radio controls:** before v0.1.2, whitespace between `.form-radio-input-wrap` and `.form-radio-label` pushed
  the label out of line with checkbox labels. From v0.1.2 the control is a flex row and formatting is free.
- **Blockquotes stack bars.** `<blockquote>` (or `.blockquote`) draws a bar on the start side; a quote inside a quote
  adds another bar, and from the seventh level on the gap to the text is small (`--blockquote-deep-gap`).
- **Blocks are the sibling of cards with a bar instead of a heading band.** `.block` has a `.block-header` bar at text size (a `.block-header-title`,
  bold links, a `.block-header-actions` slot) over `.block-content`; `.block-header.sub` is a lighter bar for a section
  inside. `.block-{color}` works like `.card-{color}`. A block clips what is inside it to its rounded corners; add
  `.allow-overflow` (also on a `.communication`) when a dropdown in it has to open beyond its edges.
- **Table frames clip.** A `.table-wrap` clips the table to its rounded frame; `.allow-overflow` lets a dropdown in a
  cell open beyond it. On a `.responsive` wrap that is from the `md` breakpoint up, below it the wrap scrolls.
- **Media overlays are styling only.** `.media-box-overlay` strips (or several in `.media-box-overlays`) and the
  `.media-box-veil` with the `.spoilered` blur are static; revealing a spoiler means removing them from your script.
- **Media boxes are square.** `.media-box-content` is a square `aspect-ratio` area and the image is fitted inside
  it like a thumbnail (`object-fit: contain`); add `.cover` to the box to crop it to fill the area instead.
  `.scale-down` fits a larger picture but leaves a smaller one at its size, centered, instead of enlarging it.
  `.media-list` fills the row with boxes at
  least the thumbnail width (`--media-box-width`, 250px, 150px below the `md` breakpoint); `.fixed` keeps them at
  that width, for a short row that should not stretch.
- **Tag boxes are styling only.** `.tag-box` holds `.tag` elements (with an optional `.tag-remove` control) and an
  `.input-field` that sizes to its placeholder and grows as you type (`field-sizing: content`; give it a `size`
  attribute as the fallback for browsers without it). Adding and removing tags is your script's job.
- **Tags are borderless.** Set `--tag-border` to a width (for example `1px`) on `:root`, a `.tag-list` or a
  single `.tag` to draw the border in the count color; the padding shrinks so the height stays the same.
  `--tag-border-radius` sets their corners (the inner radius by default, `0` for square tags).
- **`<summary>` has no marker.** The CSS reset removes the disclosure marker, so give `<details>` toggles their own
  affordance (chevron, border, pointer cursor).

See the [documentation site](https://meow.github.io/PhilomenaCSS/) for rendered examples.

## Status

Based on [HammerTimeCSS](https://github.com/WentTheFox/HammerTimeCSS) and adapted for use in the [Philomena](https://github.com/philomena-dev/philomena) project, work in progress. Documentation and live demo: <https://meow.github.io/PhilomenaCSS/> (source in [`docs/`](docs), an Astro site that is not part of the npm package).

## Development

`pnpm run build` builds `dist/`, `pnpm run check:contrast` measures the contrast pairs, `pnpm run lint` runs
[oxlint](https://oxc.rs/docs/guide/usage/linter) over the scripts and [stylelint](https://stylelint.io) over the
stylesheets, and `pnpm run fmt` formats everything with [Prettier](https://prettier.io) (`fmt:check` only checks).
The configurations are Philomena's, adapted where this repository differs (`.oxlintrc.json`, `.stylelintrc.yml`,
`.prettierrc.yml`, `.editorconfig`). CI runs the lint, the format check, the build and the contrast check on every
pull request.

## Releases

Releases are published by hand. Commits follow [Conventional Commits](https://www.conventionalcommits.org/), which
CI checks, and the version follows semver; before 1.0.0 a breaking change bumps the minor version.

```sh
npm version 0.3.0 --no-git-tag-version   # set the version in package.json, commit it
pnpm run build && pnpm run check:contrast
npm publish --access public
git tag -a v0.3.0 -m v0.3.0 && git push origin main v0.3.0
```

## License

MIT
