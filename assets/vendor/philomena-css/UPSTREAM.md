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
