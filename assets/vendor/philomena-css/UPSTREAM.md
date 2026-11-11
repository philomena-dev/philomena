# PhilomenaCSS vendored copy

- Source: https://github.com/Meow/PhilomenaCSS
- Commit: `a30090d96e96c089bd871fa3cbe4353ed60e1615`
- Version: 0.4.0

## Pending upstream

Pull requests against upstream `main` that are merged over the commit above. They merge cleanly in any order. A pull
request leaves this list once the commit above includes it. Each entry lists the files it changes outside the left-out
`docs/`.

- https://github.com/Meow/PhilomenaCSS/pull/1, branch `fix/component-polish`, commits `c64307e`, `63bd3d9`,
  `262a99e`, `2f75426`, `fa3d203` and `6884f0f`: `README.md`, `css/components/input-field.css`,
  `css/components/table.css`, `css/design/layout.css`, `css/design/mixins.css`, `css/utils/alignment.css`.
- https://github.com/Meow/PhilomenaCSS/pull/2, branch `feat/opt-in-modifiers`, commits `1853313`, `d406fd2`,
  `71d71c0`, `edadeba`, `11db244` and `b76fd96`: `README.md`, `css/components/avatar.css`, `css/components/block.css`,
  `css/components/communication.css`, `css/components/media.css`, `css/components/table.css`,
  `css/components/tag.css`, `css/design/mixins.css`, `css/design/tokens.css`.
- https://github.com/Meow/PhilomenaCSS/pull/3, branch `feat/forms-horizontal-toggles`, commits `2a19b8e` and
  `f0b4b33`: `README.md`, `css/components/button.css`, `css/components/forms.css`, `css/design/tokens.css`.
- https://github.com/Meow/PhilomenaCSS/pull/4, branch `feat/disclosure`, commit `ea218b2`: `README.md`,
  `css/components/disclosure.css`, `css/components/index.css`, `css/design/layout.css`.
- https://github.com/Meow/PhilomenaCSS/pull/5, branch `feat/header-field`, commit `943b81b`: `README.md`,
  `css/components/header.css`, `css/design/tokens.css`, `scripts/contrast.mjs`.

## Left out

Repository plumbing and the documentation site: `.github/`, `.husky/`, `docs/`, `commitlint.config.js`,
`pnpm-lock.yaml`, `pnpm-workspace.yaml`, `.editorconfig`, `.gitignore`, `.oxlintrc.json`, `.prettierignore`,
`.prettierrc.yml`, `.stylelintrc.yml`.

## Local modifications

`package.json`, for the left-out tooling:

- removed the `lint`, `fmt`, `fmt:check`, `commitlint` and `prepare` scripts
- removed the `@commitlint/cli`, `@commitlint/config-conventional`, `husky`, `oxlint`, `prettier`,
  `prettier-plugin-astro`, `stylelint` and `stylelint-config-recommended` devDependencies
- removed `packageManager`

The CSS, so that Philomena's build can bring it down to the browsers of `assets/.browserslistrc`, whose oldest
Chrome has neither `:where()` nor complex `:not()` arguments. Philomena's PostCSS stage (`assets/build/`) does the
rest. It expands `:where()` and `:is()` into alternatives of their own specificity and splits `:not(a, b)` into one
`:not()` per argument, so a rule written at low specificity to let others win would outrank them; these rules are
rewritten to state, hover or position through custom properties instead, read by a rule of upstream's rank:

- `design/mixins.css`, `design/layout.css` and the link rules of `components/card.css`, `block.css`, `collapsible.css`,
  `editor.css`, `media.css` and `communication.css`: a container sets its link style as `--link-style-*` custom
  properties (the `content-links` and `bar-links` mixins) that one `a` rule applies, and the controls of
  `$content-controls` and `$bar-controls` but alerts, whose `.alert a` rule outranks that `a` rule, reset them (buttons,
  nav links, tags, badges, dropdown items, pagination links and tabs), in place of `a:where(:not($(content-controls)))`,
  whose `.tag a`-style arguments floor browsers can't parse. The reset is one list for both kinds of container, so a nav
  link or a tab in a bar keeps its own style too. Each bar underlines its hovered links in a `{bar} a:hover` rule (the
  `links-hover` mixin), of the specificity upstream's had. Where link containers nest, the innermost one decides, where
  upstream the most specific rule did (a block in a colored card, say). A link inside a `.button` or `.nav-link` (nested
  interactive content, invalid HTML) is reset as well. The options bar of `communication.css` lays out every link but
  buttons, dropdown items and pagination links as `a:where(:not(.button, .dropdown-item, .pagination-link))`, links in a
  tag or badge there included. The media box color variants give their bar's background to the bar alone, not to its
  links as well, which sit on it.
- `design/layout.css`, headings: those inside a card header, a table cell, a badge, a tag or a button get
  `--heading-rhythm: 0` instead of being left out by `:not(.card-header *, …)`, a heading that is the first or last
  child sets `--heading-first` or `--heading-last` to zero its margin at that edge, in place of `:where(:first-child)`
  and `:where(:last-child)`, and the rhythm's `--flow-margin` comes before its own top margin, in place of the rhythm
  rules that followed the heading rule.
- `design/layout.css`, focus ring: the containers that clip their links set `--focus-ring-link-offset`, which the
  ring of links and buttons takes as its offset, in place of a rule for their links that outranked the rings of the
  components.
- `design/layout.css`, rhythm: the children of a flow container get `--flow: 1`, each kind of neighbor sets its
  distance in a property of its own (`--flow-block-gap` and so on), and one universal rule applies the last kind that
  matched as `margin-top: var(--flow-margin)`, which is invalid, so 0, where `--flow` or every distance is unset. This
  replaces one rule per container and pair of neighbors at the specificity of both. `<pre>`, which the reset gives
  its browser margin back, takes `var(--flow-margin, 1em)`.
- `components/input-field.css`, `components/forms.css` (radio buttons) and `components/button.css`: the hover state
  sets `--_hover-border-color`, `--_radio-hover-border-color` or `--_pointer-shade`, which the rules that color the
  border or shade read, and disabled or read-only controls reset it, in place of `:where(:not(:disabled, …))` and
  `:not(:disabled, .pressed)` on the hover rule. A button held down sets `--_pointer-shade`, `--_pointer-bevel` and
  `--_pointer-drop` the same way. Disabled buttons and the buttons of disabled toggle inputs reset all three, in place
  of `:where(:not(.button-check-input:disabled + *))` on the hover and `:active` rules, a complex selector inside
  `:not()` that no floor browser parses. A pressed button and the button of a checked toggle input set their look
  themselves.
- `components/media.css`: the square image area is `height: 0; padding-bottom: 100%` with the image or video
  positioned over it, as floor browsers lack `aspect-ratio`.
- `components/button.css`: `.justify-start` and `.justify-end` align the button content with `flex-start` and
  `flex-end`, which are the same in its left-to-right row, as floor browsers lack `start` and `end` in flex layout.
- `components/input-field.css`: the fallback for browsers without `:user-invalid` marks only fields with a
  `[placeholder]`, as a select or a field without one never shows a placeholder and would turn red when the page loads.
  Floor browsers lack `:user-invalid`, so the build drops its rules and keeps this fallback for every browser.

The other `:where()`, `:is()` and `:not()` lists keep the higher specificity of their expansion. That changes the
winner only for rare combinations: a read-only field that is also `.invalid` (the read-only background wins), an
`<hr>` inside a `.blockquote` element (it takes the blockquote's spacing), and elements matched by the reset's
`[hidden]` rule and a type selector, or by its `[contenteditable]` rule and a single class.

Every other file is byte-identical to upstream with the pending pull requests merged. `npm run build` and
`npm run check:contrast` work through the workspace (`npm run build -w @philomena/philomena-css`).

## Updating

1. Clone upstream, check out the new commit and merge into it the branches of "Pending upstream" that it does not
   include yet. A pull request that the new commit includes is merged upstream: drop its entry.
2. From the clone, copy `css/`, `scripts/contrast.mjs`, `postcss.config.js`, `vite.config.js`, `LICENSE`,
   `README.md` and `package.json` over this directory, deleting files that upstream removed.
3. Reapply the local modifications listed above.
4. Update the commit and version above.
5. Run `npm install` at the repository root, inside the app container, to refresh `package-lock.json`.
6. Check with `diff -r <clone> assets/vendor/philomena-css` that only the omissions, the local modifications and
   this file differ.

A pull request that is still open is brought in the same way, by merging its branch over the commit above, and gets
an entry under "Pending upstream".
