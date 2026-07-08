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

| Phase | Status | Scope                                          | Rationale                                                                           |
| ----- | ------ | ---------------------------------------------- | ----------------------------------------------------------------------------------- |
| 0     | done   | Infrastructure above                           | Blocks everything                                                                   |
| 1     | done   | JSON API (taxonomy #1)                         | Stable contract, external consumers, validates the OpenAPI spec work on this branch |
| 2     | done   | Public read-only HTML (#2)                     | High traffic, no auth matrix needed, exercises fixtures                             |
| 3     | done   | Singleton toggles (#4) via shared helper       | Biggest module-count win for least effort                                           |
| 4     | done   | UGC writes (#5) + remaining auth/account (#3)  | Core user flows                                                                     |
| 5     | done   | Admin & moderation (#6)                        | Needs role helpers matured                                                          |
| 6     | done   | Odd ducks (#7), coverage meta-test enforcement | Cleanup                                                                             |

Phase 1 is complete: every `/api/v1` route (JSON, RSS, and the upload/
reverse-search POST endpoints) is pinned, and all `/api/v1` lines in
`test/route_coverage.txt` are marked. Phase 2 is complete: forum, staff,
rule, page, channel, dnp, commission, tag, post, comment, and profile
read actions are pinned (write actions on those controllers are deferred
to their own phases), as are activity (homepage), image (index/show/new
plus the `/:id` shorthand), the image read-only nested controllers
(random, related, comments, source changes, navigate, favorites), topic
show (plus the `/:forum_id/:id[/...]` shorthands), gallery index/show,
search, the edit-history pages (comment/post/page history), tag details,
tag changes, adverts, themes, profile commission show, and profile
source changes. A few public GETs are deliberately deferred to travel
with their controller families: filter reads and image reporting (#5),
duplicate report reads (#6), reverse search and autocomplete/fetch (#7).

Phase 3 is complete. The shared generator module landed as
`test/support/singleton_toggle_tests.ex` (`PhilomenaWeb.SingletonToggleTests`);
the first batch of ten controllers pinned with it covers the image
interaction trio (vote/fave/hide), the image/topic/forum/gallery
subscription controllers, and the image/topic/gallery read controllers.
The second batch finishes the non-moderation tail: channel
read/subscription (generator-based), conversation read/hide and tag watch
(hand-written — different response shapes), and the filter toggles
(hide/spoiler/spoiler_type). The moderation-flavored toggles
(lock/stick/feature/delete/approve/etc.) travel with phase 5, and the
cookie-based `Channel.NsfwController` goes with the odd ducks in phase 6.

Phase 4 has begun with `ConversationController` (index/new/show/create — its
read/hide singletons were pinned in phase 3). The second batch covered 13
more controllers (23 route lines): the notification family
(NotificationController index + dead delete route, unread, categories),
conversation message create and conversation reports, the image UGC writes
(comment create/edit/update, comment reports, image reports, tags, sources,
description), the reports index, and post preview. The third batch covered
10 more controllers (31 route lines): the forum UGC writes (topic
new/create/update, topic post create/edit/update, topic post reports, poll
vote create), the gallery family (gallery new/create/edit/update/delete,
gallery images/order/reports), dnp new/create/edit/update, and settings.
The fourth batch covered 10 more controllers (39 route lines): the filter
family (filter CRUD including the `fq` search branch, current-filter
switching, clear-recent, make-public) and the profile family (commission
writes, commission items, commission reports, profile description, artist
links, profile reports).
The fifth and final batch closed out the remaining ~41 route lines: the
auth/account family (35 lines — the pre-existing generated tests for
session/registration/password/confirmation/unlock/reactivation/deactivation
and the registration password/email singletons were extended, and new files
pinned the session TOTP, registration TOTP, and registration name
controllers), avatar (4), image upload (`POST /images`), and the image
reporting partial. Phase 4 is complete.
Moderation-flavored routes sharing these controllers (message/comment/post
approve, image mod tools, topic move/stick/lock/hide, poll edit + poll
vote index/delete, awards, scratchpads) travel with phase 5; scrape,
autocomplete/fetch, reverse search, and `Channel.NsfwController` with
phase 6.

Phase 5 has begun with the `/admin` CRUD families. Batch one: the ban trio
(`Admin.UserBanController`, `Admin.SubnetBanController`,
`Admin.FingerprintBanController`), `Admin.SiteNoticeController`, and
`Admin.ModNoteController`. Batch two: `Admin.ForumController`,
`Admin.BadgeController` (+ `Badge.UserController`, `Badge.ImageController`),
and `Admin.AdvertController` (+ `Advert.ImageController`). Batch three (the
moderation queue and misc-admin families): `Admin.ReportController`
(+ `Report.ClaimController`, `Report.CloseController`),
`Admin.ApprovalController`, `Admin.ArtistLinkController`
(+ `ArtistLink.VerificationController`, `ArtistLink.ContactController`,
`ArtistLink.RejectController`), `Admin.DnpEntryController`
(+ `DnpEntry.TransitionController`), `Admin.UserController` (index/edit/update),
`Admin.Batch.TagController`, `Admin.DonationController`, and
`Admin.Donation.UserController` — 26 route lines, 119 tests. Batch four (the
`Admin.User.*` singleton children): `Admin.User.AvatarController`,
`ActivationController`, `VerificationController`, `UnlockController`,
`EraseController`, `ApiKeyController`, `DownvoteController`, `VoteController`,
`WipeController`, and `ForceFilterController` — 15 route lines, 82 tests, all
Postgres-only (`async: true`). Batch five (first half of the image moderation
tools plus the conversation-message approve): `Conversation.Message.ApproveController`,
`Image.ApproveController`, `Image.Comment.{Hide,Delete,Approve}Controller`,
`Image.DeleteController` (mod hide/restore/reason), `Image.TamperController`,
`Image.HashController`, `Image.SourceHistoryController`, `Image.RepairController`,
`Image.FeatureController`, and `Image.DestroyController` — 16 route lines, 92
tests, all Postgres-only (`async: true`). Batch six (the second half of the
image moderation tools): `Image.FileController`, `Image.ScratchpadController`,
`Image.UploaderController`, `Image.AnonymousController`, and the three lock
controllers `Image.{CommentLock,DescriptionLock,TagLock}Controller` — 18 route
lines, 90 tests, all Postgres-only (`async: true`). Batch seven (the topic/forum
moderation tools): `Topic.MoveController`, `Topic.StickController`,
`Topic.LockController`, `Topic.HideController`, `Topic.Post.HideController`,
`Topic.Post.DeleteController`, `Topic.Post.ApproveController`,
`Topic.PollController` (edit/update), and `Topic.Poll.VoteController`
(index/delete, completing the earlier create-only file) — 19 route lines, 81
tests, all Postgres-only (`async: true`). Batch eight (the profile/IP
moderation pages): `Profile.ScratchpadController` (edit/update),
`Profile.AwardController` (new/create/edit/update/delete),
`Profile.IpHistoryController`, `Profile.FpHistoryController`,
`Profile.AliasController`, `IpProfileController`,
`IpProfile.SourceChangeController`, `FingerprintProfileController`,
`FingerprintProfile.SourceChangeController`, and `ModerationLogController`
(all `:index`/`:show`) — 17 route lines, 64 tests, all Postgres-only
(`async: true`). Batch nine (the duplicate-report / tag-change / tag-CRUD
families): `DuplicateReportController` (index/show/create) plus its
`Accept`/`AcceptReverse`/`Reject`/`Claim` children, `TagChangeController`
(delete), `TagChange.RevertController`, `TagChange.FullRevertController`,
and the tag staff CRUD `TagController` (edit/update/delete) with its
`Image`/`Alias`/`Reindex` children — 24 route lines, 109 tests, all
Postgres-only (`async: true`). Batch ten (the final phase-5 batch — the
staff-facing CRUD writes on the three public read controllers whose read
sides were pinned in phase 2): `PageController` (new/create/edit/update),
`ChannelController` (new/create/edit/update/delete), and `RuleController`
(new/create/edit/update) — 16 route lines, 82 tests, all Postgres-only
(`async: true`). With batch ten, **phase 5 is complete**: every phase-5
route line in `test/route_coverage.txt` is now `[x]`, and the only
remaining `[ ]` lines are the phase-6 odd ducks (`Channel.NsfwController`
create/delete, `Image.ScrapeController`, `Autocomplete.Tag`/`Compiled`,
`Fetch.TagController`, and `Search.ReverseController` index/create).

Phase 6 is complete: the eight odd-duck route lines are pinned (40 tests
across six new files), every line in `test/route_coverage.txt` is `[x]`,
and `route_coverage_test.exs` now enforces full coverage — a second
meta-test fails on any unchecked line, so a new route cannot land without
either characterization tests or a deliberate edit to the meta-test.
**The characterization-test project is done**: all 454 routed actions are
pinned.

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
- **Index lifecycle** lives in `PhilomenaQuery.SearchHelpers`
  (`test/support/search_helpers.ex`). `create_all_indexes!/0` runs once from
  `test_helper.exs`, building every index with its current mapping; each test
  then empties the indexes it reads with `clear_index!/1` in setup, and calls
  `reindex_all!/1` (or `index_documents!/2`) after inserting fixtures — inserts
  only enqueue dead Exq jobs, so indexing is always explicit. Both reindex
  helpers force a `_refresh`; without it, searches race OpenSearch's ~1s
  refresh interval. Dropping and recreating an index per test (the original
  design) is a cluster-metadata operation costing ~95 ms, and at 276 calls a
  run it was the entire serial phase of the suite; `clear_index!/1` deletes
  documents instead, in ~0.8 ms. Nothing in the suite needs a fresh mapping
  mid-run.
- **Convention**: search-backed test modules are `async: false` and tagged
  `@moduletag :search`. The tag is currently informational (nothing is
  excluded by default since OpenSearch is always up in the compose stack);
  it exists so the suite can later exclude or serialize them wholesale.
- `SearchIndexer.reindex_schema(schema, maintenance: false)` is the
  test-friendly call — the default maintenance path assumes a non-empty
  table and prints progress. It spawns `Task.async_stream` workers that
  query the repo, which is exactly why search tests must stay non-async
  (shared sandbox mode).

## Field notes from the phase-2 read-only batch

From the staff/rule/page/channel/dnp/commission tests (Postgres-only) and
the tag/post/comment/profile tests (search-backed):

- **Mixed controllers are split across phases by marking `route_coverage.txt`
  per line.** Rules, pages, channels, tags, dnp all mix public reads with
  staff/UGC writes; only the read lines are flipped now, the writes stay
  unmarked for phases 4–6.
- **Three more contexts got fixture modules** (static pages, dnp entries,
  commissions). One more sanctioned direct-insert: `UserIp` rows (the
  changeset casts nothing — only `UserAttributionPlug` internals write
  them), which the commission directory requires for its two-week-activity
  filter.
- **Know which context function the production writer uses.**
  `Channels.update_channel` casts only `type`/`short_name`; the fetcher
  fields tests need (`title`, `nsfw`, `last_fetched_at` — the index filters
  on it) go through `Channels.update_channel_state`.
- **Routing pipeline beats Canary in failure ordering**: `/pages` :index
  sits in the `require_authenticated_user` scope, so anonymous → 302
  `/sessions/new` ("You must log in to access this page.") while logged-in
  non-staff → 302 `/` (Canary). Check the router scope before assuming the
  Canary flash.
- **`Enum.max`/`hd` on empty lists is a recurring 500 shape** (rules index
  on an empty table, commissions index on invalid search params via the
  pagination partial — both in KNOWN-ODDITIES.md). When a controller
  reduces over a list it just loaded, always write the empty-case test.
- **Search-backed HTML controllers follow the phase-0 recipe unchanged**;
  profile :show is the heavy one (msearch over Image + Comment + Post, so
  recreate all three indexes). Post/comment index error branches render 200
  with an error message, unlike commissions.
- **Anonymous profile viewing had been lost in the `Canada.Can` impl split**
  (commit `24db299d` narrowed `can?(_user, :show, %User{})` to the
  logged-in impl only). Caught by characterization and — as a deliberate
  exception to the no-fixes rule — restored in the `Atom` impl in the same
  branch; the profile test asserts the restored behavior.

## Field notes from the phase-2 activity/image/topic/gallery/search batch

From the activity, image (+ random/related/navigate/comments/source_changes),
topic, gallery, and search tests:

- **The three-minute upload delay applies to logged-in users too.**
  `ImageLoader.default_query` (homepage and `/images`) hides images with
  `created_at > now-3m` whenever `delay_home_images?/1` is true — and
  `User.delay_home_images` **defaults to true**, so a fresh fixture image is
  invisible on index pages even after login unless the test either backdates
  `created_at` (the fixture passes it through `change`) or flips the user
  setting. Search, navigate, and related are unaffected (they don't use
  `default_query`).
- **Assert links, not bodies, for the homepage strips.** The recent-comments
  strip renders only `/#{image_id}#comment_#{comment_id}` anchors with
  attribution — no comment body. Same idea as the "stable markers" rule:
  check the template before asserting content.
- **Scope-preserving redirects carry query params.** `Image.RandomController`
  and `Image.NavigateController` redirect through `ImageScope.scope/1`, so
  the location is e.g. `/images/42?q=safe` when `q` was given, and a bare
  `/images/42?` (trailing `?`) when not. Build expectations with
  `~p"...?#{[q: ...]}"` interpolation rather than hand-written strings.
- **Non-integer HTML by-id routes crash like the JSON ones.**
  `GET /images/not-a-number` raises `Ecto.Query.CastError` (message
  "cannot be cast to type :id" — the `where(id: ^id)` shape, distinct from
  the API's "cannot be dumped" wording). Logged in KNOWN-ODDITIES.md.
- **`SearchController` with no `q` interpolates `nil` into the title**
  ("Searching for - Derpibooru", double space) and compiles to
  `match_none`; a syntax error renders 200 with "there was an error parsing
  your query". Neither is a 400.
- **Postgres-only nested image controllers stay `async: true`**: comment
  index/show (`CommentLoader` reads the repo, not the comment index),
  source changes, and topic show. `Images.update_sources/3` works in tests
  for arranging source-change rows (attribution fixture + controller-shaped
  `"old_sources"`/`"sources"` maps).
- **Gallery show needs only the Image index** (images are found by a
  `gallery_id:` search); the gallery must be in the Gallery index for
  `/galleries` but not for its own show page. `Galleries.add_image_to_gallery/2`
  works in tests (dead Exq jobs); reindex Image _after_ adding so the
  document carries the gallery interaction.

## Field notes from the phase-2 leftovers batch

From the image favorites, comment/post/page history, tag detail, tag
change, advert, theme, profile commission show, and profile source change
tests (only tag changes is search-backed; everything else stays
`async: true`):

- **Canary's not-found handling is asymmetric by action.** Plain
  `load_resource` runs the configured `not_found_handler` for `:show`
  actions (unknown `/adverts/:id` and `/profiles/:slug/commission` redirect
  with the not-found flash — the first routes pinned with that flash rather
  than the Canary-unauthorized one), but **not** for `:index` actions,
  where a `nil` assign reaches the controller and crashes (`BadMapError` on
  `/pages/:slug/history` and `/tags/:slug/details`; KNOWN-ODDITIES.md).
  `load_and_authorize_resource` behaves differently again: nil goes down
  the unauthorized path regardless of action.
- **Version diffs are rendered character-level**, so an edited body never
  appears contiguously in the history page. Give fixture edits a shared
  prefix (`"Original body"` → `"Original body plus an edit"`) and assert
  the prefix plus `<ins class="differ">`.
- **`Images.update_tags` validates ≥3 tags** on the resulting image, so a
  tag-change fixture must go from the image fixture's `"safe"` to e.g.
  `"safe, added test tag, other added tag"`. It writes the TagChange rows
  synchronously; `/tag_changes` reads them through the TagChange OpenSearch
  index (phase-0 recipe applies).
- **Adverts are another sanctioned direct-insert fixture** (same reason as
  badges: `create_advert/1` runs the image upload pipeline). `RelativeDate`
  fields cast plain `%DateTime{}` values fine. The click side effect of
  `GET /adverts/:id` is batched by the `Adverts.Server` GenServer, so there
  is nothing synchronous to assert. That GenServer would flush from a
  process owning no sandbox connection (a `DBConnection.OwnershipError` ~10s
  into a run), so `test_helper.exs` terminates it for the whole test run;
  its `record_impression`/`record_click` casts are then dropped silently.
- **Fave/vote/hide rows are arranged through the interaction Multis**
  (`Repo.transaction(ImageFaves.create_fave_transaction(image, user))`,
  same for `ImageVotes`) — no controller round-trip needed. The favorites
  partial renders with `layout: false`; pin that with
  `refute response =~ "Derpibooru"`. Vote/hide lists only render for users
  who can `:tamper` (moderators).
- **`/tags/:tag_id/details` is the one staff-gated page in this batch**
  (`can? :edit, %Tag{}` — moderators only), and it sits in the
  `require_authenticated_user` scope, so anonymous gets the login redirect
  while regular users get the Canary flash. Filter spoiler/hide usage is
  arranged via `filter_fixture(user, %{spoilered_tag_list: tag.name})`;
  watchers via a direct `watched_tag_ids` update.

## Field notes from the phase-3 toggle batch (first 10 controllers)

From the shared generator module (`test/support/singleton_toggle_tests.ex`)
and the image vote/fave/hide/subscription/read, topic subscription/read,
forum subscription, and gallery subscription/read tests (all Postgres-only,
`async: true` — interaction reindexing is a dead Exq enqueue):

- **The parameterized-helper plan works as `use` + target callbacks.**
  `PhilomenaWeb.SingletonToggleTests` exposes three generators —
  `subscription_toggle_tests()`, `read_singleton_tests()`, and
  `image_interaction_guard_tests(verbs)` — each expanding to the shared
  tests for its sub-shape. The instantiating module defines one private
  function (`subscription_target/1`, `read_target/1`, `interaction_path/1`)
  that builds fixtures and returns path plus side-effect closures
  (`subscribe!`, `subscribed?`, `arrange!`, `notification?`). Unqualified
  calls inside the quoted tests (`post`, `test`, `register_and_log_in_user`,
  the target function) resolve in the instantiating module, so the
  generators need no imports of their own; a typical controller file is
  ~15 lines of target function plus one generator call, with only
  controller-specific oddities hand-written.
- **The whole family sits in `require_authenticated_user`**, so the
  anonymous case is uniformly a 302 to `/sessions/new` — and because that
  (and `FilterBannedUsersPlug`) halt before the resource loads, the id in
  the path never has to exist. Every generator exploits that and builds no
  fixtures for its anonymous tests: `image_interaction_guard_tests/1` takes
  a dummy id (`interaction_path(1)`), while `subscription_toggle_tests/0`
  and `read_singleton_tests/0` call the instantiating module's
  `anonymous_path/0`. Consequently `subscription_target/1` and
  `read_target/1` always receive a real user, never `nil`.
  Ban filtering splits the family: vote/fave/hide reject banned users
  ("You are currently banned." flash, redirect to referrer `/`), while the
  subscription/read controllers have no ban plug — a banned user can still
  subscribe (pinned in the image subscription test).
- **`Plug.Test` preserves param types.** `post(conn, path, %{"up" => true})`
  delivers a real boolean to the controller, mirroring the JSON fetch
  client; sending a raw `"up=true"` body with an explicit urlencoded
  content-type exercises the form-encoding path. That distinction is
  load-bearing for `Image.VoteController`, which compares
  `params["up"] == true` — a form-encoded upvote is silently recorded as a
  **downvote** (KNOWN-ODDITIES.md).
- **Subscription error branches are unreachable.** `create_subscription`
  inserts with `on_conflict: :nothing` (resubscribing is idempotent), and
  `delete_subscription` deletes an id-built struct without an existence
  check, so unsubscribing while not subscribed raises
  `Ecto.StaleEntryError` (500, KNOWN-ODDITIES.md) before the controllers'
  `_error.html` branch can ever render. Forum/topic don't even have the
  `_error.html.slime` template.
- **Watching state is asserted from the partial's link classes**: both
  Subscribe/Unsubscribe anchors always render; the Subscribe link
  (`data-method="post"`) carries `hidden` iff watching. The helper's
  `subscription_partial_watching?/1` regexes that anchor rather than
  golden-filing the partial.
- **`load_resource` nil pass-through extends to `:create`**: unknown image/
  gallery ids on the read controllers reach the notification-clearing
  context functions and 500 with `FunctionClauseError` (same asymmetry as
  the `:index` `BadMapError` note above; folded into that KNOWN-ODDITIES
  entry). Unknown topics are different — `LoadTopicPlug` runs its own
  `NotFoundPlug` — and `LoadTopicPlug`'s `show_hidden: true when action in
[:delete]` means a hidden topic can be unsubscribed from but not
  subscribed to.
- **Fave/unfave asymmetry**: faving also upvotes (replacing any existing
  downvote), but unfaving removes only the fave — the implicit upvote stays.
  Interaction responses are the full re-fetched counter map
  (`score`/`faves`/`upvotes`/`downvotes`), so the JSON bodies assert
  exactly.
- **Arranging notifications is two explicit steps**: subscribe via the
  context (`create_subscription`), then call the matching
  `Notifications.create_*_notification` (`{:ok, 1}` = one recipient;
  authors are excluded from their own broadcasts, so use a separate author
  fixture). `Topics.hide_topic/3` works in tests for the hidden-topic pins.
- **The test repo pool needed resizing for the growing async suite.** With
  Ecto's default `pool_size: 10` and ExUnit's default
  `max_cases: System.schedulers_online() * 2` (36 in the app container),
  the full run started failing randomly-distributed tests with
  `DBConnection.ConnectionError` at sandbox checkout once this batch
  landed. `config/test.exs` now sizes the pool to match `max_cases` and
  raises `queue_target`/`queue_interval` for the then-bcrypt-heavy user
  fixtures. If random `ConnectionError` flakes reappear as later phases
  add tests, revisit these numbers before suspecting the tests.
- **bcrypt runs at 4 rounds in test** (`config/runtime.exs`, guarded by
  `config_env()`; override with `BCRYPT_ROUNDS`). At the production cost of
  12 rounds a hash takes ~166 ms, and since every user fixture pays for one
  — a TOTP fixture for eleven, the password plus ten backup codes — it
  dominated the run. 4 rounds costs ~0.8 ms. Nothing depends on the cost
  factor: bcrypt reads it back out of the stored hash when verifying. Note
  `config/runtime.exs` is evaluated _after_ `config/test.exs`, so this
  cannot be overridden from the latter.

## Field notes from the phase-3 toggle batch (second 8 controllers)

From the channel read/subscription, conversation read/hide, tag watch,
and filter hide/spoiler/spoiler_type tests (all Postgres-only,
`async: true`):

- **Channel read/subscription slot straight into the generators** —
  `channel_fixture()` plus `Channels.create_subscription/2` and
  `Notifications.create_channel_live_notification/1` (which takes only the
  channel: live notifications have no author, so unlike forum/image
  notifications no separate author fixture is needed).
- **Conversation read/hide are singleton toggles by route only.** They
  respond flash + redirect (not the empty-200/partial shapes the
  generators expect) and toggle per-participant _columns_ on the
  conversation row (`to_read`/`from_read`, `to_hidden`/`from_hidden`)
  rather than a separate interaction row — hand-written tests, asserting
  the acting side's flag flips while the other side's is untouched.
  Authorization is participant-or-moderator (`:show`), but
  `mark_conversation_read/hidden` only writes the from/to sides, so a
  non-participant moderator gets the success flash with neither flag
  changed (pinned). Read create redirects to the conversation and delete
  to the index; hide is the mirror image (create → index, delete →
  conversation).
- **The filter hide/spoiler toggles act on the _current_ filter**, with
  the tag as a `?tag=<slug>` query param, not a path segment. They
  `can? :edit` the current filter _before_ loading the tag — and a fresh
  user's current filter is the seeded system default, which they can't
  edit, so the request 403s with an empty text body until the test
  arranges an owned filter (`filter_fixture(user)` +
  `Users.update_filter(user, filter)`). Responses are bare `text("")` —
  200/403/500 with empty bodies throughout.
- **The nil pass-through oddity extends to tag-slug toggles**: an unknown
  tag slug on `/tags/:tag_id/watch`, `/filters/hide`, and
  `/filters/spoiler` reaches `watch_tag`/`hide_tag`/`spoiler_tag` as `nil`
  and raises `BadMapError` on `tag.id` (folded into the existing
  KNOWN-ODDITIES entry). Note compiled `nil.field` access raises
  `BadMapError`, not `ArgumentError` — worth remembering when guessing
  crash pins.
- **Ban filtering again splits the family**: filter hide/spoiler have
  `FilterBannedUsersPlug` (redirect to referrer `/` with the ban flash,
  before the tag loads — dummy slugs suffice); tag watch and conversation
  read/hide have no ban plug, so banned users can still watch tags
  (pinned) and manage conversation flags.
- **`Filter.SpoilerTypeController` redirects to the referrer**
  (`redirect(external: conn.assigns.referrer)` — `/` without a `Referer`
  header, the header value with one; both pinned). Its happy path
  pattern-matches `{:ok, user}`, so an invalid `spoiler_type` value is a
  `MatchError` 500 and a missing `"user"` param a
  `Phoenix.ActionClauseError` (KNOWN-ODDITIES.md). The PUT route line is
  pinned with its own test alongside PATCH.

## Field notes from the phase-4 opener (ConversationController)

From `conversation_controller_test.exs` (Postgres-only, `async: true`):

- **All eleven pins passed on the first run** — the accumulated field notes
  (login-redirect scope, Canary nil-resource unauthorized path, ban-plug
  referrer redirect, string-keyed nested `"messages"` params) now predict
  behavior reliably for conventional UGC controllers. Expect the oracle-run
  workflow to matter mainly on controllers with unusual plugs.
- **`LimitPlug` (one create per minute) does not interfere with tests**: its
  Valkey key includes the user id, every test registers a fresh user, and
  user ids come from a Postgres sequence that survives sandbox rollback, so
  keys never repeat across runs. Only the happy path increments the counter
  (`register_before_send` skips status 200), so validation-failure tests
  are exempt anyway. This applies to every rate-limited phase-4 controller.
- **Conversation show marks the viewer's side read as a side effect** —
  assert it alongside the 200, mirroring the Conversation.ReadController
  pins. A non-participant moderator passes `:show` authorization here too.
- **Create failure re-renders `new.html` without the `title` assign** and
  renders fine (the layout tolerates a missing title); the page still
  carries the "New Conversation" heading marker.

## Field notes from the phase-4 second batch (notifications, reports, image UGC writes)

From the notification family, conversation message/report, image
comment/report/tags/sources/description, reports index, and post preview
tests (all Postgres-only, `async: true` — metadata reindexing is a dead Exq
enqueue):

- **Anonymous UGC writes need unique per-test IPs.** `LimitPlug` keys
  anonymous requests by `conn.remote_ip` in Valkey, which is shared across
  the whole (concurrent) test run and not sandboxed — concurrent anonymous
  comment-create or metadata-update tests would trip each other's rate
  limit. Give each anonymous write test its own address by rebinding
  `%{conn | remote_ip: ...}` from `System.unique_integer` (see
  `put_unique_ip/1` in the image comment/tag/source tests). Logged-in
  writes are safe as-is: the key includes the user id and every test
  registers a fresh user.
- **Report submissions carry `user_agent` as a form field.** The shared
  report form embeds the request's User-Agent header as a hidden input and
  `Report.creation_changeset` `validate_required`s it, so report-create
  params must include `"user_agent"` alongside `"reason"` and `"rule_id"`.
  Without it (or with any other changeset failure) the shared
  `ReportController.create/5` 500s trying to render `"new.html"` in the
  calling controller's nonexistent default view (KNOWN-ODDITIES.md) — the
  validation-failure pin is an `assert_raise ArgumentError`, not a 200.
  Expect the same shape for the profile/gallery/post report wrappers.
- **`too_many_reports?` short-circuits before validation**: the 6th open
  report redirects to `/` with the limit flash even when other params are
  invalid, and staff roles bypass the cap entirely. Arrange the cap with
  five `report_fixture` rows; the fixture's distinct attribution IP doesn't
  matter because the user-id branch trips first.
- **Notification fixtures follow the phase-3 recipe** (subscribe via
  context + `create_*_notification`), but note `topic_fixture` returns the
  bare topic struct, unlike the Multi-based `%{topic: topic}` shape of
  `Topics.create_topic`. Category names come from
  `NotificationView.name_of_category/1` (`:image_comment` is "New replies
  on images"); an unknown `/notifications/categories/:id` falls back to
  `:forum_post` rather than 404ing. `DELETE /notifications/:id` is a dead
  route — no `delete/2` in the controller (KNOWN-ODDITIES.md).
- **Comment edit failure re-renders without the `:title` assign** (same
  shape as conversation create failure): pin the form's "Oops, something
  went wrong!" error box, not a page title. The comment-edit routes live in
  the `require_authenticated_user` scope while comment create is public —
  check the router scope per action, not per controller.
- **The metadata-write partials render with `layout: false`** (`_tags.html`,
  `_source.html`, `_description.html`): assert content markers plus
  `refute response =~ "Derpibooru"`. Changeset failures re-render the same
  partial as a 200 with the image unchanged — assert the side effect's
  absence (no `TagChange`/`SourceChange` row), not response content.
- **Moderators pass every image ability** (`can?(%User{role: "moderator"},
_action, %Image{})`), so description update — otherwise uploader-only —
  works for any moderator. Conversely `Conversation.MessageController` maps
  `create: :show`, so a non-participant moderator can post into any
  conversation (pinned).

## Field notes from the phase-4 third batch (forum UGC, galleries, dnp, settings)

From the topic/topic post/post report/poll vote, gallery
(+ images/order/reports), dnp write, and settings tests (all Postgres-only
and `async: true` except the gallery controller file, which stays
search-backed for its phase-2 read tests):

- **Failure re-renders without the `:title` assign are the norm, not the
  exception.** Topic create, gallery create/update, dnp create/update, and
  settings update all re-render their form template with no title — pin the
  page heading (`"Create a Topic"`, `"Content Settings"`, `"New DNP
Request"`) or the form's "Oops, something went wrong!" box, never the
  `- Derpibooru` title suffix, for validation-failure tests.
- **Topic `:edit` has no owner rule** — only moderators (and Topic
  assistants) pass `verify_authorized`, so the topic author's own PATCH is
  a 302 with the authorization flash. `update_topic_title` also does not
  re-slug: the redirect target keeps the old slug after a rename.
- **Arranging polls goes through `topic_fixture`**: pass a `"poll"` map
  (`"title"`, `"active_until"`, `"vote_method"`, string-keyed `"options"`)
  and the `cast_assoc` builds it; `RelativeDate` casts a plain `%DateTime{}`
  fine. The poll-vote controller pins two oddities: option ids are never
  checked against the poll being voted on, and non-integer ids 500
  (KNOWN-ODDITIES.md).
- **The report-wrapper shapes replicate exactly** (topic post + gallery):
  success redirects to `/reports` (logged-in) or `/` (anonymous), any
  changeset failure is the `ArgumentError` 500 from the missing calling-
  controller view. One difference: `Topic.Post.ReportController` sets no
  `:title` assign, so pin the `"Submit a report"` heading there.
- **The gallery image/order singletons read `image_id`/`image_ids` from the
  request body**, not the path — Canary happily loads the Image resource
  from a body param. Add/remove respond bare JSON `{}` (200, or 400 via the
  interaction unique constraint on double-add); removing an absent image is
  still a 200. Reorder only enqueues a dead Exq job, so its 200 is the
  entire observable contract; a missing `image_ids` is a
  `Phoenix.ActionClauseError` 500.
- **DNP is gated by `:set_tags` before Canary ever runs**: users without a
  verified artist link 302 off `/dnp/new`, and a moderator opening
  `/dnp/:id/edit` _without_ a `?tag_id=` param is also rejected (their own
  linked tags are the fallback, usually empty). The requesting artist
  cannot edit their own entry — edit/update are moderator-only.
  `ArtistLinks.create_artist_link` + `verify_artist_link` work in tests
  (the badge awarder tolerates the missing "Artist" badge); the tag must be
  a creator-category tag, which `artist:`-prefixed fixture names get
  automatically.
- **Settings is public**: anonymous updates succeed (cookies only, via
  `resp_cookies`), logged-in updates also hit `Users.update_settings`.
  `theme` is recomposed from `theme_name`/`theme_color` and falls back to
  `dark-blue` unless both are present; a missing `"user"` param is a
  `Phoenix.ActionClauseError` 500.

## Field notes from the phase-4 fourth batch (filters, profile family)

From the filter (CRUD + current/clear_recent/public) and profile
(commission + items + reports, description, artist links, user reports)
tests. Only the filter CRUD file is search-backed (the index `fq` branch
reads the Filter index); everything else stays `async: true`. 112 of 113
first-run pins passed — the field notes now predict even plug-heavy
controllers; the one miss refined the Canary asymmetry note below.

- **Canary's `load_resource` not-found asymmetry, completed**: the
  `not_found_handler` runs for `:show` **and `:update`** actions (unknown
  filter id on `PATCH /filters/current` → not-found flash, no default-filter
  fallback), while `:index` and `:create` pass `nil` through to the
  controller and crash. Check the action kind before guessing which shape
  applies.
- **Plug order can neuter `RequireUserPlug`.** `FilterController` runs
  `load_and_authorize_resource` first, and the anonymous impl has no
  `:new`/`:create` Filter rules, so anonymous users get the authorization
  flash, never the sign-in one (KNOWN-ODDITIES.md). Don't assume the
  sign-in flash just because the plug is present.
- **Echoed query params poison content assertions.** The filter index
  search box echoes `fq` back, so a `fq: "name:#{filter.name}"` test can
  never `refute response =~ filter.name` — assert result link hrefs
  (`href="/filters/#{id}"`) instead. Same trap for any searchable index
  whose form redisplays the query.
- **"In use" filter deletion is just an FK constraint**: make the filter
  the user's current filter (`Users.update_filter/2`) and `DELETE` takes
  the error branch ("Filter is still in use, not deleted."). The
  current-filter switch itself writes a cookie (`filter_id`) for anonymous
  users and the `current_filter_id`/`recent_filter_ids` columns for
  logged-in ones; a missing `id` param raises `ArgumentError` from
  `Repo.get(Filter, nil)`.
- **The commission plug stack checks one user and acts on another**:
  `ensure_no_commission`/`ensure_links_verified` inspect the _profile_
  user, `create/2` inserts for `current_user` — so moderators create
  commissions for themselves via other profiles (KNOWN-ODDITIES.md). The
  nested Item controller's `ensure_correct_user` has **no** moderator
  bypass, unlike its parent; expect per-controller variation in
  hand-rolled auth plugs. Items fetched with `Repo.get_by!` 404 via
  `assert_error_sent`, not a flash.
- **Artist links are moderator-shaped despite the profile-nested routes**:
  no rule grants owners `:edit` on their own `ArtistLink` (edit/update are
  moderator-only), the index lists `current_user`'s links regardless of the
  profile in the URL, and DELETE is a dead route only admins can crash
  (all three in KNOWN-ODDITIES.md). `ArtistLinks.create_artist_link/2`
  takes string-keyed attrs with `"tag_name"`; `artist:`-prefixed
  `tag_fixture` names get a creator category automatically (same recipe as
  the dnp tests).
- **The commission report wrapper is the one report wrapper behind
  `require_authenticated_user`** — anonymous gets the login redirect, not
  the report form; profile reports are public like gallery/image ones.
  Both replicate the wrapper shapes exactly (redirect to `/reports` or
  `/`, `ArgumentError` 500 on changeset failure).

## Field notes from the phase-4 fifth batch (auth/account, avatar, image upload)

From the session/registration/password/confirmation/unlock/reactivation/
deactivation extensions, the new session TOTP / registration TOTP / name
tests, avatar, `POST /images`, and the image reporting partial (everything
`async: true` except the image controller file, which was already
search-backed and `async: false` for the upload's background process):

- **Extending the 44 generated auth tests worked as planned** — they cover
  the happy paths well; what was missing was the auth matrix
  (already-logged-in redirects, anonymous login redirects), the failure
  paths, and the dead routes. 109 of 115 first-run pins passed; all six
  misses were unpinned crashes, i.e. new KNOWN-ODDITIES entries, not test
  bugs.
- **`EnsureUserEnabledPlug` sits in the `:browser` pipeline itself**, ahead
  of every scope pipeline — a logged-in _unconfirmed_ user is logged out
  ("Your account is not currently active.") before
  `redirect_if_user_is_authenticated` or any controller runs. This is why
  a logged-in unconfirmed user can't use their own confirmation link
  (KNOWN-ODDITIES.md), and why "already logged in" pins for the
  confirmation controller must use a confirmed fixture.
- **Valid TOTP codes are easy to mint**: `:pot.totp(User.totp_secret(user))`
  against the fixture's secret. For backup-code paths, build the user by
  hand (`User.random_backup_codes()` + `Password.hash_pwd_salt/1`) since
  `totp_user_fixture` discards the plaintext codes. The TOTP family hides
  three crash shapes — the enable/disable success branch returns a
  `%User{}` instead of the conn (RuntimeError after the redirect is sent),
  a wrong code while enabling hits `Enum.any?(nil)`, and a numeric code
  from a non-TOTP user crashes the encryptor — all in KNOWN-ODDITIES.md.
- **The avatar metadata fields are virtual.** Only the `avatar` path column
  persists; `avatar_width`/`height`/`size`/`mime_type` exist for
  validation only, so pin `user.avatar =~ ~r/\.png$/`, not the metadata.
  The upload itself follows the API image-create recipe
  (`Plug.Upload.random_file/1` + copy the shared PNG fixture) and is
  synchronous — no `await_async_upload` needed, unlike `POST /images`.
- **`POST /images` (browser) mirrors the API create** — same
  `Images.create_image/2` Multi, same spawned async-upload process (reuse
  `await_async_upload`), but no User-Agent header requirement (the browser
  fingerprint comes from the `_ses` cookie, not the UA) and failures
  re-render `new.html` (200, no `:title` assign) instead of returning 400
  JSON. Anonymous uploads work (captcha is disabled in test config) and
  need the `put_unique_ip` trick for `LimitPlug`.
- **`cast/3` + `update_change(&String.trim/1)` is a crash shape on empty
  strings**: `""` casts to a `nil` change and `String.trim/1` raises. Found
  on the rename form (KNOWN-ODDITIES.md); when pinning a "blank field"
  validation failure, prefer an over-long value — the blank case may be a
  500, not a changeset error.
- **Locked accounts are indistinguishable from wrong passwords at login**
  (`get_user_by_email_and_password` returns nil for locked users before
  checking the password), while unconfirmed accounts get their own message
  — pin both. A TOTP user's password login succeeds and only the
  `:ensure_totp` scope gates them afterwards.

## Field notes from the phase-5 opener (admin CRUD families)

From the admin ban/site-notice/mod-note batch and the admin
forum/badge/advert batch (all Postgres-only, `async: true`):

- **The `/admin` scope pipes through
  `[:browser, :ensure_totp, :require_authenticated_user]`**, so anonymous is
  uniformly a 302 to `/sessions/new` before any controller plug; the
  `verify_authorized`/Canary flash ("You can't access that page.") only
  appears for authenticated-but-unprivileged users.
- **Privileged-moderator `role_map` recipe**: `role_map` is virtual,
  rebuilt at login from the `roles` association — insert a
  `%Role{name: "admin", resource_type: "SiteNotice"}` row plus a
  `users_roles` join row, then log in (`roles` has no timestamps;
  `users_roles` is a bare join table). `ConnCase` now wraps this as
  `register_and_log_in_role_moderator(context, resource_type)` (setup
  shape) and `log_in_role_moderator(conn, resource_type)` (plain), both
  smoke-tested in `conn_case_helpers_test.exs`. This generalizes to any
  `role_map`-gated admin controller (Badge and Advert confirmed) — but
  not all of them gate the same way:
  the ban controllers admit **any** moderator (with an admin-only
  `check_can_delete` on delete), SiteNotice requires admin or the role_map
  grant (a plain moderator is rejected everywhere), ModNote scopes
  edit/update/delete to the note's own `moderator_id`, and Admin.Forum
  gates on `can? :edit, Forum`, which has **no** role_map rule — only
  `role: "admin"` passes. Discover per controller; the access-control map
  is the point of this phase.
- **Ban-family fixtures go straight through the context**:
  `Bans.create_user/2` (`"user_id"`, `"reason"`, `"valid_until"`),
  `Bans.create_subnet/2` (`"specification"` as CIDR/IP),
  `Bans.create_fingerprint/2` (`"fingerprint"`). `RelativeDate` fields
  accept a plain `%DateTime{}` or a string like `"5 years from now"` — use
  the string in create tests to exercise the parse path. The auto-assigned
  `generated_ban_id` makes a clean search marker for `bq` index queries.
  Fixture modules: `Philomena.BansFixtures`
  (`user_ban_fixture(target \\ nil, attrs \\ %{})`, `subnet_ban_fixture/1`,
  `fingerprint_ban_fixture/1`), `Philomena.SiteNoticesFixtures`, and
  `Philomena.ModNotesFixtures` (`mod_note_fixture(author, attrs \\ %{})`).
  The upload helpers live with their contexts:
  `Philomena.BadgesFixtures.svg_upload/0`,
  `Philomena.AdvertsFixtures.png_upload/0` and `undersized_png_upload/0`.
- **Badge (SVG) and advert (PNG) uploads run the real media pipeline in
  tests** end-to-end with a manually-built `%Plug.Upload{}` pointing at a
  repo fixture — no `Plug.Upload.random_file/1` dance needed (only
  `Images.create_image/2` uses `give_away`). The advert `image_changeset`
  enforces 699..729 × 79..91 dimensions, so `advert-test.png` (700×85)
  lives beside the shared fixtures; the 1×1 `upload-test.png` doubles as a
  convenient dimension-failure fixture. `badge-test.svg` covers the SVG
  analyzer path.
- **Canary's not-found asymmetry, admin flavor**: the not_found handler
  runs for `:edit`/`:update`/`:delete` across these controllers (unknown
  integer id → not-found redirect; non-integer id → `Ecto.Query.CastError`
  500), and Admin.Forum — loaded by `id_field: "short_name"`, a string
  column — has no CastError shape at all (any string is just a lookup
  miss). `:index` keeps the nil pass-through crash shape
  (`/admin/badges/:badge_id/users`, KNOWN-ODDITIES.md).
- **`moderation_log/2`** (the `ModerationLogPlug` helper used by
  badge/advert create/update/delete) is a synchronous `Repo.insert` — no
  Exq dependency, safe in tests.
- **Watch the controller error branches, not just the happy path**: this
  batch found two dead error branches (user-ban create renders a template
  needing an assign only `new` sets; badge create/update match a
  Multi-shaped error tuple the context never returns) — both 500 on any
  invalid submission (KNOWN-ODDITIES.md).

## Field notes from the phase-5 moderation-queue batch

From `Admin.ReportController` (+ claim/close), `Admin.ApprovalController`,
`Admin.ArtistLinkController` (+ verification/contact/reject),
`Admin.DnpEntryController` (+ transition), `Admin.UserController`,
`Admin.Batch.TagController`, and the donation pair. Two files are
search-backed (`async: false`, `@moduletag :search`) — Report **index**
reads the Report OpenSearch index and User **index** reads the User index;
everything else is Postgres-only (`async: true`). Report/donation
`:show`/`:edit` and all the write actions stay off search, but keeping the
whole file `async: false` when any action is search-backed is simplest.

- **Access-control map for this batch.** Reports (`can? :index/:show/:edit,
Report`), the approval queue (`:approve, %Image{}`), artist links (`:index`
  / `:edit, %ArtistLink{}`), and DNP entries (`:index, DnpEntry`) all admit
  **any moderator** (and admin). By contrast, **donations have no moderator
  rule at all** — only the catch-all `role: "admin"` grant reaches
  `Admin.DonationController`/`Donation.UserController`; a plain moderator is
  rejected. `Admin.Batch.TagController` gates on `:batch_update, Tag`, which a
  plain moderator also lacks (admin-only, or a `Tag`-admin/`batch_update`
  role_map grant). `Admin.UserController` is the split case: its **index** is
  open to moderators (`:index, User`) but **edit/update** have no
  plain-moderator rule (admin-only, or a `User`-moderator role_map grant), so
  a moderator who can list users cannot edit one. Pin the moderator rejection
  on the gated actions, not just the admin success.
- **Claim/close/verify/contact/reject/transition are the write actions; their
  failure surfaces vary by loader.** The report claim/close and all three
  artist-link controllers use `load_and_authorize_resource` with
  `persisted: true` on a `:create`/`:delete` action, so an **unknown id** is
  authorized against a `nil` resource, fails, and takes the
  **not-authorized redirect** ("You can't access that page."), while a
  **non-integer id** is interpolated into the load query and raises
  `Ecto.Query.CastError` (500). `Admin.DnpEntry.TransitionController` instead
  uses plain `load_resource` (no not-found handler on `:create`), so an
  unknown id passes `nil` through and crashes with `FunctionClauseError` in
  `DnpEntries.transition_dnp_entry/3` (KNOWN-ODDITIES nil-pass-through family);
  a non-integer id is still the `CastError`. `Donation.UserController` `:show`
  and `Admin.ReportController` `:show`/`Admin.UserController` `:edit` load by
  the not-found-handled path, so an unknown id/slug **redirects** with the
  not-found flash instead of crashing.
- **DNP transition has a real error branch.** `transition_dnp_entry/3`
  `validate_inclusion`s the target state, so an invalid `state` param returns
  `{:error, _}` and the controller flashes "Failed to update DNP entry!" and
  redirects (no crash) — a genuine failure-path pin, unlike the report
  close/claim controllers whose `{:ok, _} = ...` matches would raise. A
  missing `state` param is a `Phoenix.ActionClauseError` 500.
- **`Admin.UserController` update re-renders cleanly on failure**, unlike the
  user-ban create branch: `edit.html`/`_form.html` read only `@user`
  (set by the `:update` `load_and_authorize` plug) and `@roles` (the
  `load_roles` plug runs on `:update` too), so an invalid `role` re-renders
  the form at 200. `update_user/2` requires `name`/`email`/`role` and
  `validate_inclusion`s the role; it also `put_assoc`s `roles` from
  `attrs["roles"]` (absent → replaced with `[]`).
- **`Admin.Batch.TagController` reports optimistic success.** On the `{:ok,_}`
  branch it returns `%{succeeded: image_ids, failed: []}` echoing **every**
  passed id, even ids that matched no image (hidden or nonexistent) — the
  transaction succeeds over the empty set (KNOWN-ODDITIES.md). `image_ids` are
  `String.to_integer`'d, so a non-integer id is an `ArgumentError` 500 and a
  missing `tags`/`image_ids` param is a `Phoenix.ActionClauseError` 500. It
  authenticates the browser fingerprint from the `_ses` cookie
  (`UserAttributionPlug`), not a User-Agent, so no UA header dance is needed;
  `Endpoint.broadcast!` to "firehose" is a no-op with no subscribers and
  `Images.batch_update` only enqueues (dead) reindex jobs, so the file stays
  `async: true`.
- **Donations insert freely.** Every `Donation.changeset` field is optional
  (`validate_required([])`), so `POST /admin/donations` with an empty
  `donation` map still inserts a row and flashes success; the only failure
  path is the `user_id` FK constraint (a bad user id → `{:error, _}` →
  "Error creating donation!" flash, not a crash), and a missing `donation`
  param is `Phoenix.ActionClauseError`.
- **List-index filter branches.** The artist-link and DNP indexes each have
  three `index/2` clauses (default state filter, a search/`lq`/`eq` branch,
  and `?all`/`states[]` overrides); the default view hides verified
  links / non-active DNP states, so pin both the default omission and the
  override that reveals the row. The report index default view splits results
  into search-loaded "All Reports" plus `Repo`-loaded "Your Reports"/"System
  Reports"; a freshly reindexed unclaimed report lands in "All Reports".
- **New fixture modules:** `Philomena.ArtistLinksFixtures`
  (`artist_link_fixture(user, tag, attrs)` → unverified;
  `verified_artist_link_fixture/3` runs the admin-style verify, badge awarder
  tolerating the missing "Artist" badge) and `Philomena.DonationsFixtures`
  (`donation_fixture(user \\ nil, attrs)`). Artist-link and DNP fixtures both
  need a **creator-category tag** — `tag_fixture(name: "artist:foo")` gets the
  `origin` category automatically. `report_fixture({"Image", image.id})` from
  `Philomena.ReportsFixtures` arranges an open report against a polymorphic
  reportable.

## Field notes from the phase-5 Admin.User.* singleton children batch

From the ten `Admin.User.*` child controllers hanging off
`/admin/users/:user_id` (avatar, activation, verification, unlock, erase,
api_key, downvotes, votes, wipe, force_filter). All Postgres-only
(`async: true`): the Users context functions only enqueue (dead) reindex/wipe
workers and `moderation_log/2` is a synchronous `Repo.insert`.

- **Access-control map: any moderator, not just admin.** Every one of these
  controllers hand-rolls the same `verify_authorized` plug gating on
  `can?(:index, User)`, which is granted to **any** `role: "moderator"` (ability
  line 43), so a plain moderator can deactivate, verify/unverify, unlock, reset
  API keys, force filters, wipe PII, and erase users. This is the mirror image
  of the split noted for the **parent** `Admin.UserController`, whose
  `:edit`/`:update` are admin-only — a moderator who can list and destructively
  act on users through the children still cannot open the parent edit form. Pin
  the plain-moderator success on each child, and pin the anonymous
  (`/sessions/new` "must log in", from the `/admin` pipeline) and regular-user
  ("You can't access that page.") rejections. The `User`-moderator `role_map`
  grant (`register_and_log_in_role_moderator(_, "User")`) is redundant here — a
  plain moderator already passes — so it adds no coverage and is omitted.
- **Same controller, opposite unknown-id shapes by verb.** These use plain
  `load_resource` (`id_field: "slug"`, `persisted: true`), and the global Canary
  `not_found_handler` (config.exs) runs only for `:show`/`:edit`/`:update`/
  `:delete` — **not** `:new`/`:create`. So an unknown slug splits by action even
  within one controller: `:delete` (deactivate, unverify, api_key, downvotes,
  votes, unforce_filter) **redirects** to `/` with "Couldn't find what you were
  looking for!", while `:create`/`:new` pass the `nil` through and crash in the
  context (`FunctionClauseError` from `reactivate_user`/`verify_user`/
  `unlock_user`/`force_filter`/`change_user` requiring a `%User{}`;
  `WipeController` instead `BadMapError`s dereferencing `nil.id` before the
  enqueue). `ActivationController` and `VerificationController` show both shapes
  side by side. Same nil-pass-through family as KNOWN-ODDITIES.
- **`EraseController` is the exception — it guards `nil` itself.** Three plug
  guards run after `load_resource`: `prevent_deleting_nonexistent_users`
  (redirects an unknown slug to `/admin/users` with "Couldn't find that
  username. Was it already erased?", so `:new`/`:create` here redirect instead
  of crashing), `prevent_deleting_privileged_users` (`role != "user"` → redirect
  to profile "Cannot erase a privileged user"), and
  `prevent_deleting_verified_users` (`verified` → "Cannot erase a verified
  user"). A successful `create` runs `Users.erase_user/2` synchronously:
  deactivates (`deleted_at`/`deleted_by_user_id` set) and renames to
  `deactivated_<32 hex>`, both observable; the deeper deletion is enqueued
  (`UserEraseWorker`, dead) and the rename enqueues (dead) `UserRenameWorker`.
- **`force_filter` create is the one genuine `{:error}` failure path.**
  `force_filter_changeset` casts `forced_filter_id` with a
  `foreign_key_constraint`, so a nonexistent id fails the FK on update and the
  controller's `{:ok, user} = ...` match raises **`MatchError`** (no re-render
  branch) — distinct from the not-found shapes. The happy path needs a real
  filter row (`filter_fixture(user)`), and the param shape is
  `%{"user" => %{"forced_filter_id" => id}}`. `unforce_filter`,
  `remove_avatar`, and `unlock` all set their column unconditionally, so they
  succeed even when there is nothing to undo (no forced filter / no avatar /
  already unlocked).
- **Deactivation writes `deleted_at`, not a `deactivated_at`**; the acting user
  is recorded in `deleted_by_user_id` (asserted against the logged-in
  admin/mod). `api_key` delete rotates `authentication_token` to a fresh binary.
  `downvotes`/`votes`/`wipe` have nothing synchronously observable beyond the
  flash/redirect (the `UserUnvoteWorker`/`UserWipeWorker` enqueues are dead), so
  those pins stop at flash + redirect.
- **New fixtures in `Philomena.UsersFixtures`:** `verified_user_fixture/1`
  (confirmed + `verify_changeset`) and `user_with_avatar_fixture/1` (confirmed
  with a bare `avatar` filename; no object is uploaded — the `remove_avatar` S3
  delete goes through the stubbed ex_aws client). Reused existing
  `locked_user_fixture/1`, `deactivated_user_fixture/1`, and
  `moderator_user_fixture/1` (the privileged-user target for the erase guard).

## Field notes from the phase-5 image-moderation-tools batch (first half)

From the twelve moderation write controllers hanging off `/images/:image_id`
(plus the conversation-message approve): `Conversation.Message.ApproveController`,
`Image.ApproveController`, `Image.Comment.{Hide,Delete,Approve}Controller`,
`Image.DeleteController` (the mod hide/restore tool), `Image.TamperController`,
`Image.HashController`, `Image.SourceHistoryController`, `Image.RepairController`,
`Image.FeatureController`, and `Image.DestroyController` — 16 route lines, 92
tests, all Postgres-only (`async: true`). None of these actions read through
OpenSearch; every context reindex (`reindex_image`/`reindex_comment`/
`reindex_reports`) and `repair_image`'s thumbnail job is a dead Exq enqueue,
`moderation_log/2` is a synchronous `Repo.insert`, and the S3 purges/thumbnail
ops go through the stubbed ex_aws client (some via a fire-and-forget `spawn`).

- **Pipeline and access-control map.** All these routes sit in
  `[:browser, :ensure_totp, :require_authenticated_user]`, so anonymous is a
  302 to `/sessions/new` ("You must log in…") before any controller plug, and a
  logged-in-but-unprivileged user gets the Canary "You can't access that page."
  redirect to `/`. **Any moderator** (and admin) can approve
  messages/comments/images, hide/restore/destroy-content comments, hide/restore
  images and edit their deletion reason, tamper votes, clear hashes, delete
  source history, repair, and feature — these all resolve through the blanket
  `can?(%User{role: "moderator"}, _action, %Image{}/%Comment{})` /
  `:approve, %Message{}` rules. **`Image.DestroyController` is the exception:**
  it gates on `:destroy, %Image{}`, which a plain moderator is explicitly
  **denied** (ability line 53 returns `false`); only an admin or an
  `Image`-admin `role_map` moderator (`log_in_role_moderator(conn, "Image")`)
  passes. Pin the plain-moderator rejection there, not just the admin success.
- **Unknown-id failure surfaces follow the phase-5 loader split.** These
  controllers load the image/comment/message with `load_and_authorize_resource`
  (`persisted: true`) on `:create`/`:update`/`:delete`, so an **unknown id** is
  authorized against a `nil` resource — no rule matches for moderator/role-mod,
  so it takes the **not-authorized redirect** ("You can't access that page."),
  and a **non-integer id** is interpolated into the load query and raises
  `Ecto.Query.CastError` (500). (Admin is the sharp edge: `can?(admin, _, nil)`
  is `true`, so an admin with an unknown id sails past authorization and crashes
  in the controller/verify plug — pin the unknown-id case with a moderator or
  role-mod, not an admin.) `Image.TamperController` is the one that behaves
  differently: its second, `load_resource`-loaded `user_id` target **does** run
  the not-found handler on `:create`, so an unknown `user_id` **redirects** to
  `/` with "Couldn't find what you were looking for!" rather than crashing.
- **Arranging unapproved content.** The approve controllers need an unapproved
  row. Images: `image_fixture(approved: false)` (direct insert). Comments: a
  body with an external link authored by a fresh (untrusted) user —
  `comment_fixture(image, confirmed_user_fixture(), %{"body" => "… https://spam.example/"})`.
  Messages use the `:image_embeds` check (`![`), not `:external_links` — and
  posting an unapproved PM files a **system report against the "Approval" rule**,
  so `rule_fixture(name: "Approval")` must exist first or `create_message`
  raises `Ecto.NoResultsError`. `Image.ApproveController` also has a
  `verify_not_approved` plug (already-approved → "Someone else already approved
  this image." redirect); the comment/message approves have no such guard and
  are idempotent.
- **Guarded/failure branches worth pinning.** `Image.DeleteController` `:update`
  (edit deletion reason) and `Image.DestroyController` `:create` both run a
  `verify_deleted` plug requiring `hidden_from_users` — on a live image they
  halt with "Cannot change deletion reason on a non-deleted image!" /
  "Cannot destroy a non-deleted image!". `Image.FeatureController` inverts it
  (`verify_not_deleted`: featuring a hidden image → "Cannot feature a deleted
  image."). Genuine `{:error}` branches exist for the hide/reason writes
  (blank `deletion_reason` → `validate_required` fails → "Failed to delete
  image." / "Couldn't update deletion reason." / comment "Unable to delete
  comment!"). `unhide_image/1` and `unhide_comment/1` have no-op fall-throughs,
  so restoring an already-visible image/comment still reports success.
- **Observable persisted effects.** approve → `approved: true`; comment hide →
  `hidden_from_users` + `deletion_reason`; comment delete → `destroyed_content`
  - blank `body`; image hide → `hidden_from_users` + `deletion_reason`; tamper →
    the `image_votes` row for the named user is gone (set one up via
    `ImageVotes.create_vote_transaction/3`); hash → `image_orig_sha512_hash`
    nulled; source_history → `source_url` nulled; repair → `processed`/
    `thumbnails_generated` flipped to `false`; feature → an `image_features` row;
    destroy → the `image` column nulled. **`removed_image` is a virtual field**,
    so `destroy_image` leaves it nil after reload — only the `image` null-out is
    observable.

## Field notes from the phase-5 image-moderation-tools batch (second half)

From the seven remaining moderation write controllers hanging off
`/images/:image_id`: `Image.FileController` (`:update`),
`Image.ScratchpadController` (`:edit`/`:update`), `Image.UploaderController`
(`:update`), `Image.AnonymousController` (`:create`/`:delete`), and the three
lock controllers `Image.{CommentLock,DescriptionLock,TagLock}Controller` — 18
route lines, 90 tests, all Postgres-only (`async: true`). No OpenSearch reads;
every context reindex is a dead Exq enqueue and the file-replace S3 ops go
through the stubbed ex_aws client.

- **Two authorization shapes, same three controllers-of-two split as the
  first half.** `File`, `Scratchpad`, and `TagLock` use `CanaryMapPlug` to map
  their actions to `:hide` and load with `load_and_authorize_resource`, so
  they resolve through the blanket `can?(%User{role: "moderator"}, _action,
%Image{})` rule — **any moderator** (and admin) passes. `Uploader` and
  `Anonymous` instead hand-roll a `verify_authorized` plug gating on
  `can?(current_user, :show, :ip_address)` (moderator/admin only) and load
  with plain `load_resource`. None of these seven gate on `:destroy`, so no
  role-mod fixture is needed (unlike `Image.DestroyController`).
- **`load_resource` loader split, live again.** `Anonymous` and `Uploader`
  load with plain `load_resource`, whose not-found handler runs only on
  `:show`/`:edit`/`:update`/`:delete`. So `DELETE /anonymous` (`:delete`) and
  `PATCH/PUT /uploader` (`:update`) with an unknown id **redirect** with
  "Couldn't find what you were looking for!", but `POST /anonymous`
  (`:create`) with an unknown id passes `verify_authorized` and then crashes —
  `FunctionClauseError` in `Images.update_anonymous/2`, whose head requires a
  `%Image{}`. The `load_and_authorize_resource` controllers (File, Scratchpad,
  TagLock) instead take the not-authorized redirect on an unknown id
  (authorizing a `nil` resource, no rule matches for a moderator). Every one of
  the seven is the `Ecto.Query.CastError` 500 on a non-integer id.
- **Lock columns are stored inverted, with no matching `*_locked` field.**
  "Lock comments" writes `commenting_allowed: false`, "lock description"
  writes `description_editing_allowed: false`, "lock tags" writes
  `tag_editing_allowed: false` — the create/delete verbs flip the boolean, and
  the changesets never fail (`change(image, ...)`), so the only failure paths
  are the unknown/non-integer id cases.
- **`TagLock` is the richest of the batch.** Its `:show` renders a real page
  ("Locking image tags" title, "Editing locked tags on image #N" heading), and
  its `:update` rewrites the `locked_tags` association from the `tag_input`
  param via `Tags.get_or_create_tags/1`; an empty `tag_input` clears the list
  (a success, not an error). `Scratchpad.:edit` likewise renders a page
  ("Editing Moderation Notes" title); its `:update` casts `scratchpad` with no
  validation, so a blank value is a success that stores `nil` (cast/3 treats
  `""` as empty).
- **`Uploader.:update` renders the `_uploader.html` partial (200), not a
  redirect.** It reassigns `user_id` by looking the submitted `username` up
  with `Repo.get_by!(User, name: ...)`; a blank username anonymizes the image
  (`user_id: nil`, the form's documented "Empty for anonymous"), and an
  **unknown** username raises `Ecto.NoResultsError` (a 500) instead of a
  validation error (KNOWN-ODDITIES.md).
- **`FileController` drives the media pipeline synchronously** — `analyze_upload`
  reads the `Plug.Upload` locally, `persist_upload` writes to the stubbed S3,
  `repair_image`/`reindex_image`/`purge_files` are dead Exq enqueues — with no
  spawned upload process (unlike `POST /images`), so it stays `async: true`.
  Reuse the shared `png_upload/0` (now in `Philomena.ImagesFixtures`). Its
  `verify_not_deleted` plug halts a replace on a hidden image ("Cannot replace
  a deleted image."). The action calls `Images.remove_hash/1` **before**
  `update_file`, so a **failed** replacement (a request with no file →
  `validate_required(:image)` → "Failed to update file!") still nulls
  `image_orig_sha512_hash` as a side effect; a **successful** replace re-sets
  it from the new file's analysis, so the null is only observable on failure
  (KNOWN-ODDITIES.md). Observable success effect: `processed`/
  `thumbnails_generated` flipped to `false` by `repair_image`.

## Field notes from the phase-5 topic/forum moderation-tools batch

From the nine topic/forum moderation controllers hanging off
`/forums/:forum_id/topics/:topic_id`: `Topic.MoveController`,
`Topic.{Stick,Lock,Hide}Controller`, `Topic.Post.{Hide,Delete,Approve}Controller`,
`Topic.PollController` (edit/update), and `Topic.Poll.VoteController`
(index/delete) — 19 route lines, 81 tests, all Postgres-only (`async: true`).
No OpenSearch reads; every context `reindex_post`/`reindex_reports` is a dead
Exq enqueue and `moderation_log/2` is a synchronous `Repo.insert`.

- **Pipeline and access-control map.** All these routes sit in
  `[:browser, :ensure_totp, :require_authenticated_user]`, so anonymous is a 302
  to `/sessions/new` ("You must log in…") before any controller plug. The topic
  toggles (move/stick/lock/hide) and the post tools (hide/delete/approve) all
  resolve through the blanket moderator rules (`can?(%User{role: "moderator"}`,
  `:hide, %Topic{}` / `:hide|:delete|:approve, %Post{}`), so **any moderator**
  (and admin) passes and a regular user gets the "You can't access that page."
  redirect to `/`. Plain moderator already suffices for topics/posts — the
  `role_map`-keyed `assistant` rules are the only thing `register_and_log_in_role_moderator`
  could add, and they require `role: "assistant"`, so no role-mod fixture is
  needed here.
- **The topic toggles load the Forum with `CanaryMapPlug` → `:show`, then
  `LoadTopicPlug`, then authorize `:hide` on the topic.** So an unknown topic
  **slug** is `LoadTopicPlug`'s `NotFoundPlug` redirect ("Couldn't find what you
  were looking for!"); there is no non-integer-id crash because the topic is
  keyed by slug, not id. Hidden-topic loads (needed to arrange
  hide/unhide/unstick-of-hidden) go through `LoadTopicPlug`'s `can?(:show)`
  gate, which a moderator passes and a regular user does not — so a regular user
  hitting `DELETE …/hide` on a hidden topic is rejected by the **load plug**,
  not the later `:hide` check (same redirect either way).
- **`Topic.PollController` is admin-only, an outlier.** It loads the Forum with
  a bare `load_and_authorize_resource` and **no `CanaryMapPlug`**, so the forum
  is authorized against the raw `:edit`/`:update` action — moderators (only
  `:show` on forums) are rejected, only admin passes, despite the controller's
  own `verify_authorized` plug gating on the moderator-capable `:hide` of the
  topic (KNOWN-ODDITIES.md). `Topic.Poll.VoteController` does **not** share this:
  its `CanaryMapPlug` maps `index`/`delete` to `:show` for the forum and its
  `verify_authorized` gates on `:hide`, so **index/delete are moderator-reachable**
  (create stays public/any-logged-in, as pinned earlier). Poll `:update`
  re-renders `edit.html` (200) on a blank title (`Poll.changeset`
  `validate_required`s title/active_until/vote_method) — a genuine error branch,
  unlike the hide controllers below.
- **The post tools ignore the forum/topic path segments.** `Topic.Post.*` load
  only the `Post` by `post_id` with `load_and_authorize_resource`
  (`preload: [:topic, topic: :forum]`), so an unknown `post_id` is authorized
  against `nil` — no moderator rule matches → **not-authorized redirect** — and a
  non-integer `post_id` is the `Ecto.Query.CastError` 500 (same shape as the
  image comment mod tools). Success redirects to the post anchor
  `…/topics/#{topic}?post_id=#{id}#post_#{id}`.
- **Blank-reason hides 500 instead of taking the error branch.** `Topics.hide_topic/3`
  and `Posts.hide_post/3` run a `Multi` and return its raw failure tuple, but the
  `Hide` controllers only match `{:error, _changeset}` (2-tuple) — a `Multi`
  4-tuple hits neither clause → `CaseClauseError` (KNOWN-ODDITIES.md). `Topic.MoveController`
  is the same family: a non-integer `target_forum_id` is a `String.to_integer/1`
  `ArgumentError`, a nonexistent target is an `Ecto.ConstraintError` (no
  `foreign_key_constraint`), a missing param is a `Phoenix.ActionClauseError`,
  and its `Multi` `{:error}` branch is likewise dead. `Topic.LockController` is
  the exception (`lock_topic/3` is a plain `Repo.update`, so a blank
  `lock_reason` correctly redirects with "Unable to lock the topic!").
- **Idempotent/no-op successes.** unstick of a non-sticky topic, unhide of a
  visible topic/post, and approve of an already-approved post all report success
  (the changesets set the column unconditionally; there is no `verify_not_approved`
  guard on posts). **Deleting a poll vote leaves the cached tallies stale** —
  `delete_poll_vote/1` is a bare `Repo.delete`, so `vote_count`/`total_votes`
  keep their pre-deletion values while create increments them (KNOWN-ODDITIES.md).
- **Arranging fixtures.** Polls go through `topic_fixture` with a string-keyed
  `"poll"` map (`"title"`, `"active_until"`, `"vote_method"`, `"options"`), the
  same recipe the poll-vote create tests already use; votes are arranged with
  `PollVotes.create_poll_votes/3`. An **unapproved post** for the approve tool is
  `post_fixture(topic, confirmed_user_fixture(), %{"body" => "… https://spam.example/"})`
  — a fresh (untrusted) user plus an external link, mirroring the comment recipe
  — and `create_post/3` (unlike the controller) files no system report, so no
  `"Approval"` rule fixture is needed. Poll-vote `:index` filters options to
  `vote_count > 0`, so it gets the empty-case test (renders "No votes to
  display").

## Field notes from the phase-5 profile/IP moderation-pages batch

From the ten profile/IP moderation controllers: `Profile.ScratchpadController`
(edit/update), `Profile.AwardController` (new/create/edit/update/delete),
`Profile.{IpHistory,FpHistory,Alias}Controller` (index),
`IpProfileController` / `FingerprintProfileController` (show), their two
`SourceChangeController` indexes, and `ModerationLogController` (index) — 17
route lines, 64 tests, all Postgres-only (`async: true`). No OpenSearch reads;
`update_scratchpad` and the award writes only enqueue (dead) reindex jobs, and
`moderation_log/2` is a synchronous `Repo.insert`.

- **Pipeline and access-control map.** All these routes sit in
  `[:browser, :ensure_totp, :require_authenticated_user]`, so anonymous is a
  302 to `/sessions/new` ("You must log in to access this page.") before any
  controller plug, and a logged-in regular user gets the Canary "You can't
  access that page." redirect to `/`. **Any moderator** (and admin) reaches
  every one: scratchpad gates on `:index, ModNote` (moderator **and**
  assistant), awards on `:create, Award` (moderator-only, no assistant),
  ip/fp/alias/history on `:show_details, %User{}`, the IP/FP profile + source
  changes on `:show, :ip_address`, and moderation logs on `_action,
ModerationLog` — all blanket moderator rules, so plain
  `register_and_log_in_moderator` suffices and no role-mod fixture adds
  coverage.
- **Two unknown-target shapes, split by loader.** The scratchpad
  (`load_resource`, `id_field: "slug"`, `:edit`/`:update`) and the awards'
  by-`id` `load_resource` (`:edit`/`:update`/`:delete`) run Canary's global
  `not_found_handler`, so an unknown slug/id **redirects** with "Couldn't find
  what you were looking for!" and a non-integer award id is the
  `Ecto.Query.CastError` 500. But the three history/alias indexes use
  `load_and_authorize_resource` on `:index`, so an unknown slug is authorized
  against a `nil` resource (`:show_details` needs a `%User{}`, no rule
  matches) and takes the **not-authorized redirect** ("You can't access that
  page.") instead — the profile is keyed by slug, so there is no
  non-integer-id crash on those.
- **The IP profile pages 500 on an unparsable IP, the fingerprint ones don't.**
  `IpProfileController` and `IpProfile.SourceChangeController` pattern-match
  `{:ok, ip} = EctoNetwork.INET.cast(id)`, so a non-IP path segment is a
  `MatchError` 500 (same shape as the admin subnet-ban forms). The fingerprint
  equivalents use the raw string in the query, so any value renders a 200 (an
  empty listing when nothing matches) — this is the fingerprint flavor of the
  non-integer-id slot. The `SourceChange` indexes `Repo.paginate`, so they
  handle the empty page without an `hd`/`Enum.max` crash; the history/alias
  indexes reduce over plain lists and also render empty cleanly.
- **Award create/update error branches are dead.** `Award.changeset` has no
  validations and never declares the `badge_id` FK, so the only failing input
  (a nonexistent `badge_id`) raises `Ecto.ConstraintError` at insert/update
  time rather than returning `{:error, changeset}` — the re-render branches
  never run (KNOWN-ODDITIES.md). Create persists nothing on that path; update
  leaves the old badge. `delete` is a bare `{:ok, award} = ...` match; its
  only non-happy input is an unknown id, which the loader redirects before the
  match. `update_scratchpad` likewise has no reachable error branch
  (`scratchpad_changeset` only casts `:scratchpad`); a blank value is a
  success that stores `nil` (`cast/3` treats `""` as empty).
- **New fixture modules:** `Philomena.UserIpsFixtures`
  (`user_ip_fixture(user, ip \\ "203.0.113.1")` + an `inet/1` string caster),
  `Philomena.UserFingerprintsFixtures`
  (`user_fingerprint_fixture(user, fingerprint \\ unique)`), and
  `Philomena.SourceChangesFixtures` (`source_change_fixture(image, attrs)` —
  `ip`/`fingerprint`/`value` are all `NOT NULL`, so both attribution fields
  always get a value). All three are sanctioned **direct inserts** (the
  schemas' changesets cast nothing), mirroring the commission tests' inline
  `UserIp` recipe. Moderation-log rows go through
  `ModerationLogs.create_moderation_log/4`; the list filters to the last two
  weeks, so a fresh insert is included. Awards reuse
  `Philomena.BadgesFixtures.{badge_fixture,badge_award_fixture}`.

## Field notes from the phase-5 duplicate-report / tag-change / tag-CRUD batch

The duplicate-report family (`DuplicateReportController` index/show/create and
its `Accept`/`AcceptReverse`/`Reject`/`Claim` children), the tag-change
moderation actions (`TagChangeController` delete, `TagChange.Revert` and
`TagChange.FullRevert`), and the tag staff CRUD (`TagController`
edit/update/delete plus its `Image`/`Alias`/`Reindex` children) — 24 route
lines, 109 tests, all Postgres-only (`async: true`). The tag/image update is
an S3 upload (stubbed by `ExAwsHttpClientStub`, so no `files` container is
touched); every reindex/delete/revert is a dead Exq enqueue, so nothing hits
OpenSearch.

- **Three different pipelines, three access shapes.** The public
  `DuplicateReportController` index/show/create sit in the Tor-authorized scope
  with **no Canary gate**, so any visitor — anonymous included — reaches them
  (a logged-in user is only recorded as the reporter). The accept/reject/claim
  children and `TagChangeController` delete + revert/full_revert are
  moderator-gated (`can?(:edit, DuplicateReport)` / the tag-change rules — a
  blanket moderator rule, so `register_and_log_in_moderator` suffices). The tag
  staff CRUD splits **within a single controller**: a plain moderator has
  `:edit` on tags and so can `edit`/`update` a tag and manage its `image`
  (spoiler), but **not** `delete`, `alias`, or `reindex` — those gate on
  `:alias`/admin, reachable only by an admin or a `role_map` `"Tag"` moderator
  (`log_in_role_moderator(conn, "Tag")`).
- **Unknown slug/id redirects, split by role — neither crashes.** The tag CRUD
  children load with `load_and_authorize_resource(id_field: "slug",
persisted: true)`. On an unknown slug the flash depends on the role, and the
  naive "an admin sails past authorization and crashes" guess (carried in the
  first draft's NOTEs) is **wrong**: `persisted: true` makes Canary run its
  `not_found_handler` before the controller action, so an admin — for whom
  `can?(admin, _, nil)` is true — gets a clean "Couldn't find what you were
  looking for!" 302, while a plain/`role_map` moderator fails authorization on
  the `nil` and gets "You can't access that page." Both redirect to `/`; the
  nil never reaches the context functions (KNOWN-ODDITIES.md). The
  moderator-gated dup-report/tag-change children use the same loader, so an
  unknown id there is the moderator's not-authorized redirect (there is no
  admin-only test to expose the other flash). Tags are slug-keyed, so no
  non-integer-id crash on the tag routes; the by-`id` dup-report and
  tag-change-delete routes keep the `Ecto.Query.CastError` 500 on a
  non-integer id.
- **Crafted-input 500s to pin (all KNOWN-ODDITIES.md).**
  `POST /duplicate_reports` loads both images with `Repo.get!/2` before
  authorizing, so an unknown `image_id` is an `Ecto.NoResultsError` 500 (a
  self-duplicate, by contrast, is a proper validation redirect).
  `TagChange.RevertController.create/2` only matches a **list** `ids`, so a
  scalar is a `Phoenix.ActionClauseError` 500 — but an empty list is a clean
  success reporting "0 tag changes" (the empty-case reduce).
  `TagChange.FullRevertController.create/2` dispatches on
  `user_id`/`ip`/`fingerprint` with no fallback, so a request missing all
  three is a `CaseClauseError` 500. And `Tag.ImageController.update/2` is
  another dead-error-branch: `update_tag_image/2` returns a 2-tuple
  `{:error, changeset}` (e.g. a no-file upload) but the controller only matches
  the 4-tuple `{:error, :tag, cs, changes}`, so a failed upload is a
  `CaseClauseError` 500 rather than a re-render (same family as the badge and
  topic/post-hide dead branches).
- **`GET /tag_changes` resource params are display-only** (already logged): the
  `resource_type`/`resource_id` params only change the heading; `TagChanges.load/3`
  filters on `tcq` alone, so the listing is unaffected.
- **Both PATCH and PUT are exercised** on every `:update` route (tag, tag/image,
  tag/alias) — the `resources ... only: [:update]` routes map both verbs to one
  action, and each is pinned to behave identically.
- **Fixtures:** new `Philomena.DuplicateReportsFixtures`
  (`duplicate_report_fixture(source, target, user \\ nil, attrs)` — goes through
  `DuplicateReports.create_duplicate_report/4` with the controller-style
  attribution map). Tag changes are arranged in-file via `Images.update_tags/3`
  (a `TagChange` row per edit) — controller-specific, so it stays a private
  helper rather than a fixture module. Tags reuse the existing
  `Philomena.TagsFixtures.tag_fixture/1`.

## Field notes from the phase-5 page/channel/rule CRUD batch (phase 5 close)

The staff-facing write actions on the three public read controllers pinned in
phase 2 — `PageController` (new/create/edit/update),
`ChannelController` (new/create/edit/update/delete), and `RuleController`
(new/create/edit/update) — 16 route lines, 82 tests, all Postgres-only
(`async: true`). This closes phase 5. Extended the existing phase-2 test files
rather than creating new ones. No new fixture modules were needed; all three
contexts already had fixtures (`static_page_fixture/2`, `channel_fixture/1`,
`rule_fixture/1`), and the page/rule version rows are asserted directly via
`Repo`.

- **Three access shapes, all gated on the model class.** All the write routes
  sit in the same `require_authenticated_user` scope (`[:browser, :ensure_totp,
:require_authenticated_user]`), so anonymous users are bounced to
  `/sessions/new` with "You must log in to access this page." before Canary
  runs — pinned once per action. Above that: **pages** authorize against
  `StaticPage`, which only an admin or a `role_map` `"StaticPage"` moderator
  (`log_in_role_moderator(conn, "StaticPage")`) can write —
  a plain moderator gets "You can't access that page." **Channels** authorize
  against `Channel`, on which the blanket `can?(%User{role: "moderator"}, _,
Channel/%Channel{})` rule means **any** plain moderator (and admin) can write
  — no `role_map` grant needed (contrast the admin CRUD families). **Rules**
  are admin-only: moderators (plain or `role_map`) have only `:index`/`:show`
  on `Rule`, so even a plain moderator is turned away from the rule forms; the
  `RuleController.index/2` "Create New Rule" affordance and the hidden/internal
  rules are likewise admin-gated (`can?(current_user, :edit, Rule)`).
- **A clean batch — no new crash-bugs.** Unlike most phase-5 loaders, none of
  these three produced an unknown-id 500. All three write controllers load
  `:edit`/`:update`/`:delete` targets with `load_and_authorize_resource`
  (member actions), so Canary's `not_found_handler` runs before the controller
  even though `persisted: true` is **not** set — an admin (for whom
  `can?(admin, _, nil)` is true) sails past authorization and gets a clean
  "Couldn't find what you were looking for!" 302, not a crash. This corrects
  the naive "admin passes every check → 500" guess (and the phase-2 draft's
  speculative NOTE about `change_static_page(nil)`): the `nil` never reaches
  the context functions on a member action. The by-`id` channel and by-
  `position` rule edit routes keep the usual `Ecto.Query.CastError` 500 on a
  non-integer id (pages are slug-keyed, so no cast crash there). Every
  changeset error branch also works correctly: `create_static_page`/
  `update_static_page` return the `Multi` 4-tuple the controller matches
  (`{:error, :static_page, cs, _}`), and `create_channel`/`update_channel`/
  `create_rule_with_version`/`update_rule_with_version` return the 2-tuple
  `{:error, cs}` their controllers match — so an invalid submission re-renders
  the form (200), no dead-error-branch `CaseClauseError` (contrast badge/tag/
  topic-hide).
- **Versioning is pinned.** Pages and rules version their edits: creating a
  page/rule inserts an initial version attributed to the acting user, and each
  update inserts another (asserted by counting `static_page_versions` /
  `rule_versions` rows — two after one edit of a fixture-created record). The
  rule fixture attributes its initial version to `nil` (a system edit), so the
  version row exists with a null `user_id`.
- **`update_channel` silently ignores fetcher-managed fields** (KNOWN-
  ODDITIES.md): it casts only `:type`/`:short_name` via `Channel.changeset`,
  so a crafted `PATCH /channels/:id` carrying e.g. `title` succeeds and
  redirects but leaves the title unchanged — the live-state fields
  (title/nsfw/is_live/viewers/thumbnail_url/last_fetched_at) only move through
  `update_channel_state`. The bundled edit form only exposes
  short_name/type/artist_tag, so this is a crafted-request-only surprise. An
  unsupported `type` (e.g. `TwitchChannel`) is a proper `validate_inclusion`
  failure that re-renders the form. The `fetched_channel_fixture` helper (a
  channel stamped `last_fetched_at` via `update_channel_state`, needed for the
  index to list it) stays a private helper in the channel test — it is
  specific to that controller's index/update interplay.
- **Both PATCH and PUT are exercised** on every `:update` route (pages,
  channels, rules) — `resources ... only: [:update]` maps both verbs to one
  action, each pinned to behave identically.

## Field notes from the phase-6 odd-ducks batch (project close)

The eight remaining routes: `Channel.NsfwController` (create/delete),
`Image.ScrapeController` (create), `Autocomplete.TagController` and
`Autocomplete.CompiledController` (show), `Fetch.TagController` (index), and
`Search.ReverseController` (index/create) — 8 route lines, 40 tests across
six new files. Only the tag-autocomplete file is search-backed
(`async: false`, `@moduletag :search` — it reads the Tag index); everything
else stays `async: true`, including reverse search (Postgres intensity rows,
no OpenSearch). This closes phase 6 and the project: every route line in
`test/route_coverage.txt` is `[x]`, and a second meta-test in
`route_coverage_test.exs` now fails on any unchecked line, so new routes
demand characterization tests (or a deliberate meta-test edit) to land.

- **`Channel.NsfwController` is a pure cookie toggle** — no DB touch, no auth
  gate (anonymous and logged-in behave identically), no failure surface, so no
  failure-path test exists. Both verbs write the JS-readable `chan_nsfw`
  cookie (`http_only: false`, `SameSite=Lax`, ~25-year max-age) and redirect
  to `/channels` with the same info flash; DELETE writes an explicit
  `"false"` value rather than expiring the cookie. Assert via
  `conn.resp_cookies` — the struct exposes `value`/`http_only`/`max_age`/`extra`.
- **Scrape tests exercise the Req.Test stub for real.** For a generic host
  only the `Raw` scraper performs HTTP — a HEAD probe whose raw
  `content-type` header is checked against a fixed allow-list, so the stub
  must set exactly `"image/png"` (`put_resp_header`, not
  `put_resp_content_type`, which appends a charset). A non-image
  content-type, a hostless URL (short-circuits before any HTTP — no stub
  needed), and a missing `url` param all render the JSON literal `null` as a
  200 (KNOWN-ODDITIES.md).
- **The autocomplete versions are deliberately divergent** (the controller
  comments say so — v1 is frozen for cached frontends): v1 (no `vsn`)
  returns a bare `[%{label, value}]` list and swallows every validation
  error into an empty 200 list; v2 (`vsn=2`) returns
  `%{suggestions: [%{alias, canonical, images}]}` and surfaces too-short/
  missing terms and an out-of-range `limit` as 422 `{"error": …}`. Both
  filter out zero-image tags. A field-note, not an oddity — the divergence
  is documented intent.
- **`Autocomplete.CompiledController` serves the pregenerated binary raw**:
  404 with an empty `text/plain` body when no binary row exists, otherwise
  200 with the exact bytes and `cache-control: public, max-age=86400`; both
  paths `configure_session(drop: true)` (deliberate — the endpoint is
  cache-friendly and sessionless). New fixture module
  `Philomena.AutocompleteFixtures` (`autocomplete_fixture/1`) inserts a row
  with known bytes via the context changeset — `generate_autocomplete!/0`
  builds a real binary but doesn't return the row, so the direct insert is
  the practical arrangement.
- **`Fetch.TagController` responds `%{tags: [...]}`** (id/name/images/
  `spoiler_image_uri` prefixed with `:tag_url_root`), silently caps at 50
  ids, and returns an empty list for unknown ids — but its single
  `when is_list(ids)` clause makes a missing, scalar, or empty-list `ids`
  param (the empty list serializes away entirely) a
  `Phoenix.ActionClauseError` 500 (KNOWN-ODDITIES.md).
- **Reverse search HTML mirrors the API flavor**: `index` (GET) just renders
  the form (`images` nil — neither results nor "No images found!" render),
  POST with a matching `ImageIntensity` row (the shared 1×1 PNG's 54.213 in
  all quadrants) renders the image box, no match renders "No images
  found!", and no upload / invalid params re-render the plain form at 200 —
  no error surface, same as the API. The upload here is a plain
  `%Plug.Upload{}` at the repo fixture path (`Path.absname/1`) — reverse
  search never gives the file away, so the `Plug.Upload.random_file/1`
  dance from the upload tests is unnecessary.

## Explicit non-goals

- No refactoring of controllers while characterizing.
- No full-HTML snapshot/golden-master testing.
- No view/template unit tests, plug unit tests, or LiveView-style browser
  tests — `Phoenix.ConnTest` only.
- No coverage of dead code: if a controller action is not reachable from the
  router, note it as a removal candidate instead of testing it.
