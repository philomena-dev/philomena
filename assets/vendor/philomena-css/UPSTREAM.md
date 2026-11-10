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
rest; these are the parts no transform can produce:

- `design/mixins.css`, `design/layout.css` and the link rules of `components/card.css`, `block.css`,
  `collapsible.css`, `editor.css`, `media.css` and `communication.css`: a container sets its link style as
  `--link-style-*` custom properties (the new `content-links` and `bar-links` mixins) that one `a` rule applies, and
  buttons, nav links, tags and badges reset them, in place of `a:where(:not($(content-controls)))`, whose
  `.tag a`-style arguments floor browsers can't parse and whose expansion would outrank the component link rules.
  The media box color variants no longer give the bar's background to its links as well.
- `design/layout.css`: headings inside a card header, a table cell, a badge, a tag or a button get
  `--heading-rhythm: 0` instead of being left out by `:not(.card-header *, …)`.
- `components/media.css`: the square image area is `height: 0; padding-bottom: 100%` with the image or video
  positioned over it, as floor browsers lack `aspect-ratio`.
- `components/button.css`: `.justify-start` and `.justify-end` align the button content with `flex-start` and
  `flex-end`, which are the same in its left-to-right row, as floor browsers lack `start` and `end` in flex layout.

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
