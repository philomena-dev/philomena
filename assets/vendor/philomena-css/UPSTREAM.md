# PhilomenaCSS vendored copy

- Source: https://github.com/Meow/PhilomenaCSS
- Commit: `a30090d96e96c089bd871fa3cbe4353ed60e1615`
- Version: 0.4.0

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
rewritten to state, hover or position through custom properties instead, read by a rule of the old rank:

- `design/mixins.css`, `design/layout.css` and the link rules of `components/card.css`, `block.css`,
  `collapsible.css`, `editor.css`, `media.css` and `communication.css`: a container sets its link style as
  `--link-style-*` custom properties (the new `content-links` and `bar-links` mixins) that one `a` rule applies, and
  buttons, nav links, tags and badges reset them, in place of `a:where(:not($(content-controls)))`, whose
  `.tag a`-style arguments floor browsers can't parse. Each bar underlines its hovered links in a `{bar} a:hover`
  rule (the new `links-hover` mixin), of the specificity upstream's had. Where link containers nest, the
  innermost one decides, where upstream the most specific rule did (a block in a colored card, say). A link inside a
  `.button` or `.nav-link` (nested interactive content, invalid HTML) is reset as well. The options bar of
  `communication.css` lays out every link but buttons as `a:where(:not(.button))`, links in a tag or badge there
  included. The media box color variants no longer give the bar's background to its links, which sit on that same
  background.
- `design/layout.css`, headings: those inside a card header, a table cell, a badge, a tag or a button get
  `--heading-rhythm: 0` instead of being left out by `:not(.card-header *, …)`, and the first and last child of an
  element set `--heading-first` and `--heading-last` to zero the margin at that edge, in place of
  `:where(:first-child)` and `:where(:last-child)`.
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
  border or shade read, and disabled, read-only or pressed controls reset it, in place of `:where(:not(:disabled, …))`
  and `:not(:disabled, .pressed)` on the hover rule.
- `components/media.css`: the square image area is `height: 0; padding-bottom: 100%` with the image or video
  positioned over it, as floor browsers lack `aspect-ratio`.
- `components/button.css`: `.justify-start` and `.justify-end` align the button content with `flex-start` and
  `flex-end`, which are the same in its left-to-right row, as floor browsers lack `start` and `end` in flex layout.

The other `:where()`, `:is()` and `:not()` lists keep the higher specificity of their expansion. That changes the
winner only for rare combinations: a read-only field that is also `.invalid` (the read-only background wins), an
`<hr>` inside a blockquote (it takes the blockquote's spacing), a heading that is also a flow block (it keeps its
heading margin), and elements matched by the reset's `[hidden]` rule and a type selector, or by its
`[contenteditable]` rule and a single class.

Every other file is byte-identical to upstream. `npm run build` and `npm run check:contrast` work through the
workspace (`npm run build -w @philomena/philomena-css`).

## Updating

1. Clone upstream and check out the new commit.
2. From the clone, copy `css/`, `scripts/contrast.mjs`, `postcss.config.js`, `vite.config.js`, `LICENSE`,
   `README.md` and `package.json` over this directory, deleting files that upstream removed.
3. Reapply the local modifications listed above.
4. Update the commit and version above.
5. Run `npm install` at the repository root, inside the app container, to refresh `package-lock.json`.
6. Check with `diff -r <clone> assets/vendor/philomena-css` that only the omissions, the local modifications and
   this file differ.
