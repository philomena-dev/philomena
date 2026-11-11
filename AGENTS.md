# AGENTS.md

This file provides guidance to coding assistants when working with code in this repository.

## Development Environment

Everything runs inside Docker Compose (services: `app`, `postgres`, `opensearch`, `valkey`, `files` (S3 proxy), `mediaproc`, `web`). The recommended setup is the devcontainer, which attaches to the `app` service. `scripts/philomena.sh` is the dev CLI (add `scripts/path` to PATH to get it as `philomena`):

```bash
philomena up            # build + start the dev stack (add --drop-db to reset databases)
philomena down          # stop the stack
philomena test          # run the full Elixir test/lint suite in the app container
```

The app serves at http://localhost:8080 (login: `admin@example.com` / `philomena123`). Vite dev server runs on port 5173.

Elixir commands (`mix ...`) must run inside the `app` container (or the devcontainer terminal): config points at compose hostnames like `postgres` and `opensearch`, so they fail on the host.

## Commands

### Elixir (run inside the app container)

- `mix test`: run tests (requires postgres + opensearch up; `mix ecto.create && mix ecto.load` first on a fresh DB)
- `mix test test/philomena/users_test.exs` or `...exs:42`: single file / single test
- `mix format`: format; `mix format --check-formatted` is enforced by CI
- `mix credo`: lint
- `mix sobelow --config` and `mix deps.audit`: security checks (CI runs both)
- `mix dialyzer`: static analysis (CI runs it; slow on first run while PLT builds)
- `philomena test` (from host) replicates the full CI sequence: format check → `mix test` → sobelow → deps.audit → dialyzer. It recompiles everything and runs dialyzer, so use it as a final pass, not for iteration; iterate with targeted `mix test` runs instead.

**Running tests from the host:** the `app` container pins `MIX_ENV=dev`, so a plain `docker compose exec app mix test` hits the dev database and fails with a sandbox error. Override the env:

```bash
docker compose exec -T -e MIX_ENV=test app mix test [test/path/to/file_test.exs]
```

(and once on a fresh stack, `mix ecto.create && mix ecto.load` with the same `-e MIX_ENV=test`).

Test conventions (file layout, auth-level setup helpers, fixtures, OpenSearch index handling, external-call stubbing) are documented in `test/CONVENTIONS.md`; read it before writing controller or context tests.

### Context development

Before creating or refactoring a `Philomena` domain context, its schemas, or a
controller-facing context API, read `CONTEXT_STYLE.md`. It defines the expected
code shape, changeset and query boundaries, transaction composition, result
types, and testing style.

### Database

- Schema is managed via SQL structure dump, not migration replay: fresh setup uses `mix ecto.load` (loads `priv/repo/structure.sql`), and the `ecto.migrate`/`ecto.rollback` aliases automatically re-dump the structure file; commit it together with new migrations.
- `mix ecto.setup_dev`: create, load, and seed with development data
- `mix reindex_all`: rebuild all OpenSearch indexes

### Frontend (in `assets/`)

- `npm ci` (repo root): installs the npm workspaces `assets` and `assets/vendor/philomena-css` from the single root `package-lock.json`
- `npm run lint`: `tsc` over everything (tests, build scripts and `vite.config.ts` included), oxlint, stylelint
- `npm run test` / `npm run test:watch`: vitest with coverage; `js/utils/`, `js/query/` and `build/` are held to 100%
- `npm run build`: `tsc` over the app code (`tsconfig.build.json`), then `vite build`, which runs the CSS gate below

#### Stylesheets

The CSS framework is PhilomenaCSS (see Architecture). `css/application.css` is the site stylesheet: the framework's `css/config.css`, Philomena's `config.css` and the default hue (`themes/hues/blue.css`), then the framework's design layer, utilities and the components Philomena uses, then Philomena's `tokens.css`, `design/` (mixins, base element styles), `utils.css`, `components/` and `views/`.

- Framework first: use its components with their markup, its utilities and its tokens (spacing, radii, type, colors). Philomena's stylesheets hold only what it lacks, written in its tokens: `components/` for Philomena's own components and its additions to the framework's, `views/` for the rules of a single page, `utils.css` for utilities (Tailwind names, `!important` like the framework's), `design/base.css` for elements outside components. Change a framework default through its token in `tokens.css` or its `$variable` in `config.css`, never by copying a component's rules.
- `config.css` holds only `$variables`, among them the breakpoints. `$breakpoint-md` is the phone boundary: the desktop layout starts there, and phone rules go under `@media not all and (min-width: $breakpoint-md)`. On phones controls are touch-sized: `tokens.css` defines `--touch-target-size` and `--touch-padding-vertical` and sizes the framework's controls with them; a link that stands alone takes the `touch-link` mixin or the `.touch-link` utility.
- Themes: a signed-in user's theme loads one of the nine hue stylesheets, `css/themes/<hue>.css`, after `application.css`. Each holds both modes, and `<html data-theme="dark|light">` (`LayoutView.theme_mode/1`) picks one. Anonymous visitors get no attribute and `application.css` alone: the blue hue, in the mode `prefers-color-scheme` asks for. A hue's inputs (the framework's palette, lightness overrides for contrast, the header bar colors) are `$variables` in `css/themes/hues/<hue>.css`, with shared defaults in `config.css`; a new hue also needs its name in `@theme_colors` of `Philomena.Users.Settings`. `build/postcss-theme-colors.ts` keeps only the `--*-color` declarations of theme stylesheets, so a theme color is a `--<name>-color` token set in both mode blocks of `tokens.css`. `build/__tests__/theme-contrast.spec.ts` runs the framework's contrast check over `application.css` and every hue in both modes; only the header bars may stay under its ratios.
- Header bars: `tokens.css` derives their colors (`--header-*`, `--bar-hover-shade-color`, `--burger-*`, `--notice-*`) from the hue, and `components/navbar.css` hands them, per bar, to the tokens the framework's header, navbar, menus, counters and burger read. Change a bar's colors through the hue's inputs.
- A new stylesheet is imported at its place in `application.css`, in alphabetical order within its group; a framework component that Philomena starts to use joins the framework imports there. Besides `application.css`, only `css/themes/*.css` and `css/options/*.css` are stylesheets of their own, which `vite.config.ts` picks up by file name.
- The CSP allows only the site's stylesheets (`style-src 'self'`, relaxed only while the Vite dev server runs): markup never has a `style` attribute or a `<style>` element. Scripts set styles through `element.style`.
- Classes that only scripts select start with `js-`.

#### Browser floor and CSS compatibility

- `assets/.browserslistrc` is the only place that names the supported browsers: Chrome and the browsers built on Chromium, Firefox, Safari and iOS Safari, with the oldest version of each. `build/floor.ts` derives Vite's `build.target` (which `build.cssTarget` follows) and the versions the CSS gate judges from it.
- `build/css-compat.ts` is the PostCSS stage that lowers the CSS to the floor, after the authoring plugins: logical properties to left-to-right physical ones, a few values to equivalents, `:is()`/`:where()` expanded and `:not()` split into single simple selectors (an argument with no such form stops the build), selectors with a pseudo-class a floor browser lacks (`:has()`, `:user-invalid`) dropped and `@supports selector()` tests for them settled, the-new-css-reset's first rule rewritten, then autoprefixer. Every `:focus-visible` rule is written twice: with the `.focus-visible` class of the focus-visible polyfill, which `js/focus-visible.ts` loads where `:focus-visible` is missing, and natively. A rule that only negates `:focus-visible` stays native, which floor browsers drop.
- Lowering raises specificity: alternatives of `:where()` keep their own, those of `:is()` are padded to its, `:not(a, b)` counts every argument, and the rewritten reset is (0,0,5), so every selector of only type selectors and `*` is raised by as much. A rule meant to lose to others sets a custom property that a rule of the intended rank reads, as the vendored rules listed in `vendor/philomena-css/UPSTREAM.md` do.
- `build/css-gate.ts` is a Vite plugin that fails `vite build` when an emitted stylesheet uses a selector, at-rule, property, value, function or unit that a floor browser lacks, judged from `@mdn/browser-compat-data` (its doc comment lists what it does not judge). A feature passes inside a positive `@supports` that tests for it, and a declaration passes when an `@supports not (…)` block beside its rule declares the property again for the same selector. Features that may stay although a floor browser lacks them go in `build/enhancements.ts`, one entry per browser-compat-data path with the reason its absence keeps the look or what stands in for it; never add one whose absence changes the layout or leaves a component unstyled. `build/__tests__/framework.spec.ts` builds the whole vendored framework, beyond the components `application.css` imports, and runs it through the gate.

### Rust (in `native/philomena/`)

- `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`: all enforced by CI

### Repo-wide formatting

- `npm run fmt` (repo root): prettier over everything non-Elixir; CI checks `npx prettier --check .`, plus `typos` and shellcheck for scripts. A pre-commit hook (`.githooks/pre-commit`) runs prettier.

## Architecture

Phoenix 1.8 server-rendered MVC with **no LiveView** pages: views use `phoenix_view` with HEEx templates (`lib/philomena_web/templates/**/*.html.heex`), and `phoenix_live_view` is only there for the HEEx engine and formatter. `phoenix_html` stays on 3.x because templates use its `form_for`/`link` helpers. Templates take `form_for/4` from `PhilomenaWeb.FormHelpers`, which passes the form through `PhilomenaWeb.FormData` so that a submitted value no input can render (a map where a string belongs) cannot crash a re-render; the module also builds the framework's select and checkbox controls. `mix format` runs `Phoenix.LiveView.HTMLFormatter`, which adds line breaks inside `<%= if %>`/`for` blocks and around block-level tags; elements whose rendered whitespace matters carry `phx-no-format`.

Four Elixir app namespaces under `lib/`:

- **`Philomena`**: domain contexts (images, tags, forums, comments, users, filters, galleries, notifications, ...). Each context is a `<name>.ex` module plus a `<name>/` directory of Ecto schemas and helpers. Background jobs live in `lib/philomena/workers/` and run via Exq (Redis/Valkey-backed); contexts enqueue e.g. `IndexWorker`, `ThumbnailWorker`.
- **`PhilomenaWeb`**: controllers, plugs, views, templates. Routing is aggressively RESTful: instead of custom actions there are many small nested singleton controllers (e.g. `Image.VoteController`, `Topic.SubscriptionController`) with only `create`/`delete`. The public JSON API is `lib/philomena_web/controllers/api/json/` and is documented by `openapi.yaml` at the repo root; keep the two in sync. Authorization uses Canada/Canary (`can?` protocols + plugs).
- **`PhilomenaQuery`**: the search layer. `parse/` is a nimble_parsec-based parser for the user-facing search query language; `search.ex` + `search/` is the OpenSearch client. Each searchable domain implements the `PhilomenaQuery.Search.Index` behaviour (e.g. `Philomena.Images.SearchIndex`) defining the index mapping and document serialization. Data flow: writes go to Postgres, then documents are (re)indexed into OpenSearch via `PhilomenaQuery.Search.reindex`/`IndexWorker`.
- **`PhilomenaMedia`**: media intake pipeline: `analyzers/` (mime/dimension/duration detection), `processors/` (per-format thumbnailing/optimization), intensities for duplicate detection, and `objects.ex` for S3 storage (ex_aws; s3proxy in dev).
- **`PhilomenaProxy`**: outbound HTTP: camo URL signing and `scrapers/` that fetch image metadata from external sites for upload-by-URL.

**Native code:** `native/philomena/` is a Rustler NIF crate (exposed as `Philomena.Native`) handling Markdown rendering via a forked comrak, plus other hot paths. The same Cargo workspace contains `mediaproc`/`mediaproc_client`/`mediaproc_server`, an RPC service (separate `mediaproc` compose container) that performs actual media processing so the BEAM isn't blocked by ffmpeg/imagemagick work.

**Frontend:** TypeScript (no framework) in `assets/js`, built with Vite, tested with vitest; CSS uses PostCSS with mixins and variables over the PhilomenaCSS framework. `assets/vendor/philomena-css/` is a vendored copy of the framework (the npm workspace `@philomena/philomena-css`), excluded from Philomena's formatters and linters. Its `UPSTREAM.md` records the upstream commit, the open upstream pull requests merged over it, the local modifications for the floor browsers and the update steps; change the copy only as it describes. A reusable component the framework lacks goes upstream as a pull request and is vendored as pending upstream; anything specific to Philomena stays in `assets/css`.
