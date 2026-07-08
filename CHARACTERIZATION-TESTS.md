# Characterization Tests: High-Level Plan

## Goal

Pin the _current_ observable behavior of every controller action in
`lib/philomena_web/controllers/*` (~200 controller modules, 454 routed actions)
so that future refactors can be validated against it. These are characterization
tests, not correctness tests: if an action returns a weird status or an
inconsistent redirect today, the test asserts that weirdness. No behavior
changes are made while writing them; anything surprising gets a `# NOTE:`
comment, not a fix.

## What "pinned" means per action

For each routed action, assert the externally observable contract:

- **Status code** (200, 302, 404, 403, ...), including how failures surface
  (Philomena often 404s where you might expect 403).
- **Redirect target and flash message** for write actions.
- **Response body markers**: for JSON endpoints, the full decoded structure
  (shape and values from known fixtures); for HTML, selected stable markers
  (page title, key element presence) — _not_ full HTML golden files, which
  would be too brittle against template/asset churn.
- **Side effects** where they are the point of the action: row
  created/updated/deleted, notification created, subscription toggled, etc.
- **Auth matrix**: each action exercised as anonymous, regular user, and
  (where relevant) moderator/admin and banned user.

## Controller taxonomy

Don't treat 200 controllers as 200 bespoke problems. They cluster into a
small number of shapes; each shape gets one pattern (and often one shared
test helper/macro) applied mechanically:

1. **JSON API** (`controllers/api/json/*`, ~20 modules): pure JSON in/out,
   stable public contract (now also documented in the OpenAPI spec). Easiest
   to characterize exhaustively; assert full response bodies. Highest value —
   external clients depend on these.
2. **Public read-only HTML** (image/tag/forum/topic/post/gallery/profile
   index+show, search, activity, pages, rules, staff, dnp, commissions,
   channels): assert 200 + content markers, pagination params, 404 behavior,
   and filter interaction (hidden/spoilered images) where applicable.
3. **Auth & account lifecycle** (session, registration, password,
   confirmation, unlock, reactivation, deactivation, TOTP, avatar, settings):
   already partially covered by the 13 existing tests — extend rather than
   rewrite.
4. **Singleton toggle controllers** (the long tail: `Image.VoteController`,
   `Image.FaveController`, `*.SubscriptionController`, `*.HideController`,
   `*.ReadController`, `*.LockController`, watch/spoiler/claim/approve, etc. —
   roughly a third of all modules): nearly identical `create`/`delete` pairs.
   Build one parameterized test helper (setup + request + status/side-effect
   assertion) and instantiate it per route. This is where most of the module
   count disappears cheaply.
5. **User-generated content writes** (comments, posts, topics, messages/
   conversations, galleries, filters, reports, dnp requests, commissions,
   artist links, image upload/tag/source/description updates): assert
   success path, validation-failure path, and anonymous/banned rejection.
   Image upload itself needs file fixtures and is the most infra-heavy.
6. **Moderation & admin** (`controllers/admin/*`, plus in-place mod tools:
   delete/approve/feature/lock/tamper, tag changes, duplicate reports, bans,
   badges, mod notes, moderation logs): assert both the privileged success
   path and the 403/404 for unprivileged users — the access-control pinning
   is the most valuable part here.
7. **Odd ducks** (scrape, reverse search, autocomplete binaries, oembed, RSS
   watched feed, themes, `get /:id` vanity routes, stats): handle
   individually at the end; some (scrape) need external HTTP stubbed.

## Prerequisite infrastructure (Phase 0) — complete

Everything that blocked bulk test writing has landed. What exists, and
where (mechanics and gotchas are in the field notes below;
`test/CONVENTIONS.md` is the operational reference):

- **Fixtures** — `test/support/fixtures/` has one module per core context:
  users, forums, topics, posts, comments, images, tags, filters, galleries,
  conversations, reports, rules, channels, badges, plus the shared
  `attribution_fixtures.ex`. Smoke-tested by
  `test/philomena/fixtures_test.exs`, which doubles as usage examples. The
  one deliberate gap: image _upload-path_ fixtures (a real file through the
  media pipeline) are deferred to the upload tests themselves.
- **Role helpers** — `ConnCase` provides
  `register_and_log_in_user`/`_moderator`/`_admin`/`_banned_user`/`_totp_user`,
  `log_in_totp_user/2`, and `create_api_user` for `/api/v1`; smoke-tested by
  `test/philomena_web/conn_case_helpers_test.exs`.
- **OpenSearch strategy** — decided: three composed mechanisms. A `test_`
  index-name prefix (`:opensearch_index_prefix`) keeps test runs off the dev
  indexes on the shared cluster; `PhilomenaQuery.SearchHelpers`
  (`test/support/search_helpers.ex`) recreates indexes per test and makes
  reindexing explicit; search-backed modules are `@moduletag :search` +
  `async: false`. Smoke-tested by
  `test/philomena_query/search_helpers_test.exs`.
- **External call stubbing** — mailer on `Swoosh.Adapters.Test`, S3 stubbed
  at the ex_aws HTTP-client seam (`Philomena.ExAwsHttpClientStub`),
  scrapers/camo at the Req seam via `Req.Test` (unstubbed outbound HTTP
  raises), captcha/pwned-passwords disabled by config. Smoke-tested by
  `test/philomena/external_call_stubs_test.exs`.
- **Route inventory as a checklist** — `test/route_coverage.txt`, generated
  by `PhilomenaWeb.RouteCoverage` (`test/support/route_coverage.ex`) and
  enforced by `route_coverage_test.exs`; `[x]` marks are manual, sync with
  the router is mechanical.
- **Conventions doc** — `test/CONVENTIONS.md`: file layout, auth-level
  setup, assertion idioms, external-call and search rules. This document
  keeps the plan and accumulated field notes.

## Phasing

| Phase | Status  | Scope                                          | Rationale                                                                           |
| ----- | ------- | ---------------------------------------------- | ----------------------------------------------------------------------------------- |
| 0     | done    | Infrastructure above                           | Blocks everything                                                                   |
| 1     | done    | JSON API (taxonomy #1)                         | Stable contract, external consumers, validates the OpenAPI spec work on this branch |
| 2     | started | Public read-only HTML (#2)                     | High traffic, no auth matrix needed, exercises fixtures                             |
| 3     | —       | Singleton toggles (#4) via shared helper       | Biggest module-count win for least effort                                           |
| 4     | —       | UGC writes (#5) + remaining auth/account (#3)  | Core user flows                                                                     |
| 5     | —       | Admin & moderation (#6)                        | Needs role helpers matured                                                          |
| 6     | —       | Odd ducks (#7), coverage meta-test enforcement | Cleanup                                                                             |

Phase 1 is complete: every `/api/v1` route (JSON, RSS, and the upload/
reverse-search POST endpoints) is pinned, and all `/api/v1` lines in
`test/route_coverage.txt` are marked. Phase 2 is underway (forum controller
so far).

## Working style

- Work controller-by-controller within a phase; small PRs (one taxonomy
  slice or one resource family per PR) rather than a mega-branch.
- When a test reveals a probable bug, pin the current behavior and log it in
  `KNOWN-ODDITIES.md` (at the repo root; already started) — do not fix in the
  same change.
- Definition of done per controller: every routed action has at least one
  test per auth level that can reach it, plus one failure-path test for
  write actions.

## Field notes from the first two tests

`test/philomena_web/controllers/api/json/forum_controller_test.exs` and
`test/philomena_web/controllers/forum_controller_test.exs` are the reference
implementations for taxonomies #1 and #2. Practical knowledge gained writing
them:

- **How to run a single test file from the host**: the `app` container pins
  `MIX_ENV=dev`, so a plain `docker compose exec app mix test` hits the dev
  database and dies with a "cannot invoke sandbox operation" error. Use:

  ```bash
  docker compose exec -T -e MIX_ENV=test app mix test test/path/to/file_test.exs
  ```

  On a fresh stack, first run (once, same `-e MIX_ENV=test`):
  `mix ecto.create && mix ecto.load`. Reserve `philomena test` for a final
  full-CI pass — it recompiles everything and runs dialyzer, far too slow for
  iteration.

- **Write the naive assertion, run, pin what actually happens.** Both
  failure-path guesses for the HTML controller were wrong (expected a
  not-found flash, got the authorization flash; expected an empty index, got
  a crash). This is the normal characterization workflow, not a mistake:
  the first run is the oracle. Annotate surprises with `# NOTE:` and log
  probable bugs in `KNOWN-ODDITIES.md`.

- **Failure surfaces by pipeline** (pin these shapes, don't assume REST
  conventions):
  - JSON API: missing resource → status 404 with an **empty `text/plain`
    body**, not JSON. Assert with `response(conn, 404) == ""`.
  - HTML browser: both not-found and unauthorized → **302 to `/`** with a
    flash (`NotFoundPlug` / `NotAuthorizedPlug`). Assert with
    `redirected_to/1` + `Phoenix.Flash.get(conn.assigns.flash, :error)`.
  - Canary sends a resource that fails to load down the **unauthorized**
    path (no ability rule matches `nil`), so unknown and restricted
    resources both flash "You can't access that page."
  - A mid-pipeline crash surfaces in `ConnTest` as a raised exception; pin
    it with `assert_raise` (see the `BadMapError` test in the forum
    controller test).

- **Canary/pipeline assign collisions**: `:browser`-pipeline plugs pre-assign
  things like `:forums` (`ForumListPlug`); Canary's `:index` reuses an
  existing assign whose name matches the pluralized resource and crashes on
  an empty list. When characterizing a controller with
  `load_and_authorize_resource`, check whether any pipeline plug assigns the
  same key, and make sure at least one test covers the empty case.

- **ConnCase already provides**: SQL sandbox (`async: true` is fine for
  Postgres-only controllers — the OpenSearch caveat above applies only to
  search-backed actions), a default system filter row, a `_ses` fingerprint
  cookie on `conn`, and `log_in_user/2`.

- **Fixtures**: go through context `create_*` functions where they exist
  (`Forums.create_forum/1`), mirroring `users_fixtures.ex` style. Mind schema
  validations when generating unique values — e.g. forum short names must be
  lowercase letters only, so `forums_fixtures.ex` spells the unique integer
  in base-26 letters.

- **Stable HTML markers**: the layout renders the page title as
  `{title} - Derpibooru` — assert `response =~ "Name - Derpibooru"` rather
  than exact `<title>` tags (Slime emits surrounding whitespace). Headings,
  entity names, and `~p` paths make good markers; `~p` interpolates structs
  via their `Phoenix.Param` key (forums derive `short_name`).

- **Formatting is CI-enforced on tests too**: run
  `mix format --check-formatted <files>` in the container; Markdown docs are
  covered by `npx prettier --check .` at the repo root.

## Field notes from the filter API tests

Additional knowledge from `api/json/filter_controller_test.exs` and
`api/json/filter/*_controller_test.exs`:

- **API authentication is `?key=` only.** Every user gets an
  `authentication_token` at registration (`put_api_key` in the registration
  changeset), so `confirmed_user_fixture().authentication_token` is all you
  need — no ConnCase helper required. The `:api` pipeline never fetches the
  session, so `log_in_user/2` has no effect on `/api/v1` requests; pin that
  (session-authenticated request behaves as anonymous) once per controller.
- **Use `confirmed_user_fixture()` for API-key users.** Unconfirmed and
  deactivated accounts crash mid-pipeline on `/api/v1` (`EnsureUserEnabledPlug`
  calls `put_flash` without a fetched session — see KNOWN-ODDITIES.md), so an
  unconfirmed `user_fixture()` never reaches the controller you're testing.
- **Context `create_*` functions that enqueue Exq jobs are safe in tests.**
  `runtime.exs` sets `config :exq, queues: []` when `START_WORKER` is unset,
  so `Exq.enqueue` pushes to Valkey but nothing consumes the job — fixtures
  can go through e.g. `Filters.create_filter/2` without OpenSearch side
  effects. Valkey must be up (it is, in the compose stack).
- **ConnCase seeds a "Default" system filter before every test**, so any
  endpoint that lists or resolves system filters never sees an empty table;
  fetch the row via `Filters.default_filter()` for id assertions.
- **Pin crash _messages_, not just exception modules.** `assert_raise` with a
  regex (e.g. `assert_raise ArgumentError, ~r/flash/`) keeps the test from
  silently passing on an unrelated error of the same type; ConnTest re-raises
  the original exception so the message survives.
- **By-id JSON show endpoints may 500 on non-integer ids** (raw path segment
  interpolated into `where(id: ^id)` → `Ecto.Query.CastError`). Give every
  by-id endpoint a non-integer-id test and expect to pin a raise, not a 404.

## Field notes from the oembed tests

From `api/json/oembed_controller_test.exs` and `images_fixtures.ex`:

- **Images fixture bypasses the media pipeline.** `Images.create_image/2`
  requires a real uploaded file and drives analysis, S3 persistence, and
  reindexing — none of which read-path controller tests need. So
  `images_fixtures.ex` deviates from the "go through context `create_*`
  functions" rule: it inserts the `Image` row directly (`Ecto.Changeset.change`
  - `Repo.insert!`) with fields set the way the pipeline would leave them for
    a small processed PNG, and attaches tags (via `Tags.get_or_create_tags/1`,
    which is DB-only) and sources with `put_assoc`. Tests that exercise the
    upload path itself will still need the real pipeline.
- **`~p` query interpolation must cover the whole param value.**
  `~p"...?url=#{url}"` compiles, but `~p"...?url=https://x/#{id}/y.png"` is a
  compile-time error — build the string first, then interpolate the variable.
- **Unordered association preloads leak into JSON bodies.** `derpibooru_tags`
  comes straight from the `tags` preload with no `order_by`, so full-body
  equality would be flaky; pull such lists out and compare sorted, and assert
  the rest with `Map.delete/2`.

## Field notes from the remaining API endpoints (phase 1 completion)

From the image (show/create/featured), search, reverse-search, and RSS
watched tests:

- **Media analysis works in tests, but only with absolute paths.** MIME
  detection and intensities go through the `mediaproc` RPC container
  (`PhilomenaMedia.Remote`), which translates file accesses back to the
  caller — relative paths fail with a confusing "cannot open (No such file
  or directory)" wrapped as `:unsupported_mime`. The shared 1x1 PNG fixture
  lives at `test/support/fixtures/files/upload-test.png`
  (intensities 54.213 in all quadrants); reference it via `Path.absname/1`.
- **`Images.create_image/2` works end-to-end in tests** (analysis via
  mediaproc, S3 via the ex_aws stub, reindexing via dead Exq jobs) with two
  caveats. First, it hands the upload off with `Plug.Upload.give_away/3`,
  which requires a path registered to the test process — create the
  tempfile with `Plug.Upload.random_file/1` and copy the fixture in, don't
  point a `%Plug.Upload{}` at a repo file. Second, its spawned async-upload
  process logs one `DBConnection.OwnershipError` ("Upload failed ... [try
  #0]") after the sandbox closes; harmless noise.
- **`/api` write requests need a User-Agent header.**
  `UserAttributionPlug` fingerprints API requests with
  `:erlang.crc32(user_agent)`, so ConnTest requests (which send no UA)
  crash with `ArgumentError` — `put_req_header(conn, "user-agent", ...)`
  in every API write test. Pinned once as a 500 in KNOWN-ODDITIES.md.
- **Reverse search is Postgres-only** — intensity matching joins
  `image_intensities` rows, no OpenSearch — so those tests stay
  `async: true`; insert an `ImageIntensity` row with the fixture's known
  values to arrange a match. All changeset failures (bad limit, missing
  upload) render 200 with empty results, not 400.
- **Search tests follow the phase-0 recipe mechanically**: recreate the
  domain index in setup, `reindex_all!` after fixtures, `async: false` +
  `@moduletag :search`. An empty/missing `q` compiles to `match_none` (200,
  empty), a syntax error is a 400 `{"error" => msg}`. Filter-name sorting is
  case-insensitive; assert list order accordingly.
- **RSS watched** is the one `/api/v1` route on the browser-auth plug:
  anonymous requests get the HTML login redirect, not a 401. The feed
  renders via `index.html` with a manual `application/rss+xml` content
  type; assert markers, not full XML.

## Field notes from the role helpers

Phase 0 role helpers landed in `ConnCase` (`register_and_log_in_moderator`/
`_admin`/`_banned_user`/`_totp_user`, `log_in_totp_user/2`, `create_api_user`)
plus `banned_user_fixture` and `totp_user_fixture` in `users_fixtures.ex`;
`test/philomena_web/conn_case_helpers_test.exs` smoke-tests them against real
routes. Mechanics worth knowing:

- **Roles are just a string column** — the moderator/admin fixtures already
  existed (`Ecto.Changeset.change(role: ...)` on a confirmed user); the
  ConnCase helpers only wrap them in the `setup`-function shape.
- **A ban is a row, not a user state.** `Bans.create_user/2` needs a creator
  (any user id works for `banning_user_id`), a reason, and a `valid_until`
  (`RelativeDate` — a plain `%DateTime{}` casts fine). In tests it's safe:
  the automatic subnet ban is skipped (no `user_ips` rows) and reindexing is
  a dead Exq enqueue. Bans don't block reads — they surface as
  `conn.assigns.current_ban`, which write actions check.
- **TOTP is two parts**: `otp_required_for_login` + encrypted secret on the
  user (fixture sets both via `User.create_totp_secret_changeset/1`), and a
  `:totp_token` in the session (helper generates via
  `Users.generate_user_totp_token/1`). A TOTP-enabled user logged in with
  plain `log_in_user/2` redirects to `/sessions/totp/new` on every
  `:ensure_totp` route — pinned in the smoke test.

## Field notes from the phase-0 fixtures, stubbing, and search strategy

From the domain fixtures (`test/support/fixtures/*_fixtures.ex`), the
external-call stubs, and the OpenSearch strategy; smoke tests live in
`test/philomena/fixtures_test.exs`, `test/philomena/external_call_stubs_test.exs`,
and `test/philomena_query/search_helpers_test.exs`.

### Fixtures

- **Attribution is a shared shape.** `Topics.create_topic`,
  `Posts.create_post`, `Comments.create_comment`, and `Reports.create_report`
  all take the keyword list built by `PhilomenaWeb.UserAttributionPlug`
  (`ip:`, `fingerprint:`, `user:`); `Philomena.AttributionFixtures.attribution/1`
  centralizes it (same IP/fingerprint values `images_fixtures.ex` hardcodes).
  `user: nil` gives anonymous attribution and works throughout — notification
  broadcasts tolerate a nil author.
- **Params mirror the controllers: string keys, nested assoc maps.** Topic
  and conversation changesets `cast_assoc` their first post/message from
  `"posts" => %{"0" => %{"body" => ...}}` / `"messages" => %{...}`, and
  `Conversations.create_conversation` reads `attrs["recipient"]` (a user
  _name_) itself. Don't mix atom- and string-keyed attrs in one map — `cast`
  raises.
- **Multi-based `create_*` functions return `{:ok, %{...}}` maps**, not bare
  structs — pattern-match the entity out (`%{topic: topic}`,
  `%{comment: comment}`, `%{post: post}`).
- **Two more sanctioned direct-insert exceptions** (besides images): badges
  (`Badges.create_badge/1` runs the SVG upload pipeline and its
  `persist_upload` crashes without a real `Plug.Upload`) and system filters
  (no context function creates them). Both insert via changeset +
  `Repo.insert!` with fields set the way the real path would leave them.
- **Reports need a non-internal rule row** (`validate_rule` rejects a missing
  or internal rule), so `report_fixture` creates one via
  `Rules.create_rule_with_version(attrs, nil)` (nil user = system version).
  Rules derive `Phoenix.Param` from `:position`, so fixture positions must be
  unique.
- **Plain fixture bodies are auto-approved** even for brand-new users —
  `Approval.maybe_put_approval` only withholds approval when the body matches
  the external-link/image-embed regexes. Fixtures with default bodies never
  create system reports as a side effect.

### External call stubbing

- **Mailer**: `config/runtime.exs` forced `Swoosh.Adapters.Local` for every
  non-prod env, silently overriding anything in `config/test.exs` (runtime
  config runs last). Now dev-only; test sets `Swoosh.Adapters.Test`. Assert
  with `import Swoosh.TestAssertions` + `assert_email_sent/1`.
  `extract_user_token/1` is unaffected (it reads the returned email struct).
- **S3/object storage**: stubbed at the ex_aws seam —
  `config :ex_aws, http_client: Philomena.ExAwsHttpClientStub`
  (`test/support/ex_aws_http_client_stub.ex`) answers every request with an
  empty 200, so avatar/badge/image persistence succeeds without the `files`
  container and never writes dev data. The `ExAws.Request.Req` default in
  runtime.exs is likewise skipped for test. Reads return empty bodies; tests
  that need real object contents must arrange their own stubbing.
- **Scrapers/camo**: `PhilomenaProxy.Http` now merges
  `config :philomena, :req_options` into its `Req.new` options; test sets
  `plug: {Req.Test, PhilomenaProxy.Http}`. Any test that triggers outbound
  HTTP must provide `Req.Test.stub(PhilomenaProxy.Http, fn conn -> ... end)`
  — an unstubbed request raises instead of touching the network. The stub
  composes fine with the module's streaming `into:` callback.
- **OpenSearch deliberately not stubbed** — it's real, just namespaced (see
  below). Captcha and pwned-passwords were already disabled in
  `config/test.exs`.

### OpenSearch strategy

- **The trap**: dev and test share one OpenSearch cluster and, previously,
  the same index names — a test run that recreated `images` would have
  destroyed the dev index. All index names now flow through a single helper
  in `PhilomenaQuery.Search`, prefixed by
  `config :philomena, :opensearch_index_prefix` (`"test_"` in test, unset
  elsewhere). `Search.index_name(Image)` returns the effective name.
- **Per-test lifecycle** lives in `PhilomenaQuery.SearchHelpers`
  (`test/support/search_helpers.ex`): `recreate_index!/1` in setup,
  then `reindex_all!/1` (or `index_documents!/2`) after inserting fixtures —
  inserts only enqueue dead Exq jobs, so indexing is always explicit. Both
  reindex helpers force a `_refresh`; without it, searches race OpenSearch's
  ~1s refresh interval.
- **Convention**: search-backed test modules are `async: false` and tagged
  `@moduletag :search`. The tag is currently informational (nothing is
  excluded by default since OpenSearch is always up in the compose stack);
  it exists so the suite can later exclude or serialize them wholesale.
- `SearchIndexer.reindex_schema(schema, maintenance: false)` is the
  test-friendly call — the default maintenance path assumes a non-empty
  table and prints progress. It spawns `Task.async_stream` workers that
  query the repo, which is exactly why search tests must stay non-async
  (shared sandbox mode).

## Explicit non-goals

- No refactoring of controllers while characterizing.
- No full-HTML snapshot/golden-master testing.
- No view/template unit tests, plug unit tests, or LiveView-style browser
  tests — `Phoenix.ConnTest` only.
- No coverage of dead code: if a controller action is not reachable from the
  router, note it as a removal candidate instead of testing it.
