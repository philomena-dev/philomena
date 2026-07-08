# Known Oddities

Surprising behaviors discovered while writing characterization tests (see
CHARACTERIZATION-TESTS.md). The tests pin these behaviors as-is; fixes should
be separate changes that update the corresponding test.

## `GET /forums` 500s when the user can see no forums

`PhilomenaWeb.ForumListPlug` (in the `:browser` pipeline) assigns `:forums`
with only the forums visible to the current user. Canary's
`load_and_authorize_resource` in `PhilomenaWeb.ForumController` finds that
assign already populated and probes `Enum.at(resources, 0).__struct__` to
decide whether to reuse it — which raises `BadMapError` when the list is
empty. Any user who can see zero forums (e.g. anonymous when only
staff/assistant forums exist) gets a 500 instead of an empty index. Unlikely
in production (a public forum always exists) but trivially reproducible.
`GET /admin/forums` shares the shape (its Canary `load_resource` has no
`only:`, so it runs on `:index` and reuses the `ForumListPlug` assign): an
admin viewing the index with an empty forums table gets the same
`BadMapError` 500.

Pinned in: `test/philomena_web/controllers/forum_controller_test.exs`,
`test/philomena_web/controllers/admin/forum_controller_test.exs`

## Unknown and restricted forums are indistinguishable on the HTML side

`GET /forums/:short_name` for a nonexistent short name redirects to `/` with
the flash "You can't access that page." — the _authorization_ message from
`NotAuthorizedPlug`, not the not-found message from `NotFoundPlug`. Canary
authorizes `nil` against the ability rules, no rule matches, and it takes the
unauthorized path. Restricted (staff/assistant) forums behave identically, so
the two cases can't be told apart (which does avoid existence leaks).

Pinned in: `test/philomena_web/controllers/forum_controller_test.exs`

## JSON API 404s are empty `text/plain` bodies

`/api/v1/json/*` endpoints respond to missing resources with
`put_status(:not_found) |> text("")` — an empty text/plain body rather than a
JSON error object. Consistent across the API controllers; clients must key
off the status code alone.

Pinned in: `test/philomena_web/controllers/api/json/forum_controller_test.exs`

## API requests from disabled accounts crash instead of returning an error

`PhilomenaWeb.EnsureUserEnabledPlug` (in the `:api` pipeline) handles
unconfirmed and deactivated users by calling `put_flash` and
`UserAuth.log_out_user` — both of which assume a fetched session. The `:api`
pipeline fetches neither session nor flash, so any `/api/v1` request carrying
a valid `?key=` for an unconfirmed or deactivated account raises
`ArgumentError` (a 500) instead of returning 403. This is pipeline-level, so
it affects every API endpoint, not just filters.

Pinned in: `test/philomena_web/controllers/api/json/filter/user_filter_controller_test.exs`

## Oembed 404s are JSON error objects, unlike the rest of the API

`GET /api/v1/json/oembed` responds to any lookup failure (missing `url`
parameter, no number in the path, unknown or hidden image) with status 404 and
the JSON body `{"error": "Couldn't find an image"}` — the one API endpoint
that does _not_ use the empty `text/plain` 404 described above.

Pinned in: `test/philomena_web/controllers/api/json/oembed_controller_test.exs`

## `GET /api/v1/json/oembed` 500s on a host-only URL

`OembedController.try_oembed/2` runs regexes directly on `URI.parse(url).path`.
For a URL without a path (e.g. `?url=https://derpibooru.org`) the path is
`nil`, so `Regex.run/3` raises `FunctionClauseError` (a 500) instead of
returning the 404 error object. Similarly, an id whose value exceeds the
integer column range (e.g. `/images/99999999999999999999`) is interpolated
into the query unchecked and raises `DBConnection.EncodeError` — the oembed
flavor of the non-integer-id problem below (the regexes guarantee digits, so
`Ecto.Query.CastError` itself can't happen here).

Pinned in: `test/philomena_web/controllers/api/json/oembed_controller_test.exs`

## Oembed can mistake a CDN URL's date component for the image id

The oembed CDN regex (`\/img\/.*\/(\d+)(\.|[\/_][_\w])`) grabs the last
number followed by `/x`, `_x` or `.`, so for a CDN-shaped URL with no id
segment (e.g. `/img/2026/7/7/full.png`) the day component is looked up as an
image id and can resolve to an unrelated image.

Pinned in: `test/philomena_web/controllers/api/json/oembed_controller_test.exs`

## `GET /api/v1/json/filters/:id` 500s on a non-integer id

`PhilomenaWeb.Api.Json.FilterController.show/2` interpolates the raw `id`
path segment into `where(id: ^id)`, so a non-integer id raises
`Ecto.Query.CastError` (a 500) rather than responding 404. Other API show
endpoints that load by numeric id likely share this shape; check as they are
characterized.

Pinned in: `test/philomena_web/controllers/api/json/filter_controller_test.exs`

## `GET /api/v1/json/forums/:forum_id/topics/:topic_id/posts` 500s on any empty page

`PhilomenaWeb.Api.Json.Forum.Topic.PostController.index/2` computes the
response total as `hd(posts).topic.post_count`, so any request that matches
zero posts — an unknown topic or forum, a restricted forum, or a `page`
past the last post — raises `ArgumentError` on `hd([])` (a 500) instead of
returning a 404 or an empty list. The page window is also hardcoded to 25
posts by `topic_position`; `per_page` is ignored, unlike the sibling topic
index.

Pinned in: `test/philomena_web/controllers/api/json/forum/topic/post_controller_test.exs`

## Posts in hidden topics stay in search results as null stubs

Hiding a topic does not mark its posts `hidden_from_users` in the post
search index, so `GET /api/v1/json/search/posts` still matches and returns
them. The view then renders the topic-hidden branch: every field is null
except the post `id`. Clients get anonymous-looking husk objects (and the
total counts them) for content that is otherwise inaccessible.

Pinned in: `test/philomena_web/controllers/api/json/search/post_controller_test.exs`

## API write endpoints 500 on requests without a User-Agent header

`PhilomenaWeb.UserAttributionPlug` fingerprints `/api` requests with
`:erlang.crc32(user_agent)`, which raises `ArgumentError` when the header is
absent — so a UA-less `POST /api/v1/json/images` is a 500 before reaching
the controller. Real HTTP clients virtually always send a User-Agent, which
is why this doesn't surface in practice.

Pinned in: `test/philomena_web/controllers/api/json/image_controller_test.exs`

## `GET /rules` 500s when no rules exist

`PhilomenaWeb.RuleController.index/2` computes the page's "last updated"
stamp with `Enum.max/2` over the rule timestamps, which raises
`Enum.EmptyError` on an empty rules table instead of rendering an empty
index. Unlikely in production (rules always exist) but trivially
reproducible.

Pinned in: `test/philomena_web/controllers/rule_controller_test.exs`

## `GET /rules/:id` 500s on a non-integer position

The HTML flavor of the non-integer-id problem: Canary loads rules by the
raw `position` path segment (`Repo.get_by`), so `GET /rules/not-a-position`
raises `Ecto.Query.CastError` (a 500) rather than redirecting like an
unknown position does.

Pinned in: `test/philomena_web/controllers/rule_controller_test.exs`

## `GET /images/:id` 500s on a non-integer id

`ImageController.load_image/2` interpolates the raw `id` path segment into
`where(id: ^id)`, so `GET /images/not-a-number` (and the `GET /:id`
shorthand route via any unrouted path segment, e.g. a typoed URL) raises
`Ecto.Query.CastError` (a 500) rather than redirecting like an unknown
numeric id does.

Pinned in: `test/philomena_web/controllers/image_controller_test.exs`

## `GET /commissions` 500s on invalid search parameters

When the commission search changeset rejects its params (e.g.
`commission[price_min]=not-a-price`), `CommissionController.index/2` renders
the index with `commissions: []` — but the pagination partial expects a
Scrivener page struct and raises `BadMapError` on the bare list. Invalid
search input is a 500 instead of a form error; the `changeset` from the
error branch is discarded (the template receives a fresh one), so the
validation message could not be shown even if rendering succeeded.

Pinned in: `test/philomena_web/controllers/commission_controller_test.exs`

## Unknown ids 500 on non-`:show` actions loaded with plain `load_resource`

Canary's `load_resource` runs the configured not-found handler for `:show`
actions (see `/profiles/:id/commission`, `/adverts/:id`), but not for other
actions — there it assigns `nil` and lets the controller crash. So
`GET /pages/:slug/history` and `GET /tags/:slug/details` (`:index`) with an
unknown slug raise `BadMapError`, and `POST /images/:image_id/read`,
`POST /galleries/:gallery_id/read`, and `POST /channels/:channel_id/read`
(`:create`) with an unknown id raise `FunctionClauseError` in the
notification-clearing context functions — all 500s where the sibling
`:show` routes redirect with the not-found flash. The tag-slug toggles
share the shape: `POST/DELETE /tags/:tag_id/watch`, `/filters/hide`, and
`/filters/spoiler` with an unknown tag slug raise `BadMapError` on
`tag.id` in `Users.watch_tag/2` / `Filters.hide_tag/2` /
`Filters.spoiler_tag/2`. `GET /adverts/:id` also shares the
non-integer-id `Ecto.Query.CastError` 500 shape described for
images/rules above. `GET /admin/badges/:badge_id/users` (`:index`) is the
admin flavor: an unknown `badge_id` leaves `@badge` nil and the user query
raises `BadMapError` on `^nil.id`.

Pinned in: `test/philomena_web/controllers/page/history_controller_test.exs`,
`test/philomena_web/controllers/tag/detail_controller_test.exs`,
`test/philomena_web/controllers/advert_controller_test.exs`,
`test/philomena_web/controllers/image/read_controller_test.exs`,
`test/philomena_web/controllers/gallery/read_controller_test.exs`,
`test/philomena_web/controllers/channel/read_controller_test.exs`,
`test/philomena_web/controllers/tag/watch_controller_test.exs`,
`test/philomena_web/controllers/filter/hide_controller_test.exs`,
`test/philomena_web/controllers/filter/spoiler_controller_test.exs`,
`test/philomena_web/controllers/admin/badge/user_controller_test.exs`

## A form-encoded vote request always counts as a downvote

`Image.VoteController.create/2` decides vote direction with
`params["up"] == true` — a comparison against the boolean. The JSON fetch
client in `assets/js/interactions.ts` sends a real boolean, but any
form-encoded body (`up=true`) delivers the string `"true"`, which fails the
comparison and records a **downvote**. The same applies to a missing `up`
parameter. Clients other than the bundled frontend can silently downvote
when they meant to upvote.

Pinned in: `test/philomena_web/controllers/image/vote_controller_test.exs`

## Unsubscribing while not subscribed is a 500

`Philomena.Subscriptions.delete_subscription/4` (used by the image, topic,
forum, gallery, and channel subscription controllers) builds a subscription
struct from the ids and calls `Repo.delete/1` without checking that the row
exists, so `DELETE .../subscription` when the user is not subscribed raises
`Ecto.StaleEntryError` instead of rendering the `_error.html` partial the
controllers' error branches expect to serve. Subscribing is idempotent
(`on_conflict: :nothing`), so the error branches appear unreachable in
practice — `create` never returns an error and `delete` raises first.

Pinned in: the shared `subscription_toggle_tests()` generator in
`test/support/singleton_toggle_tests.ex` (instantiated by the image, topic,
forum, gallery, and channel subscription controller tests)

## `PATCH /filters/spoiler_type` 500s on an invalid spoiler type

`Filter.SpoilerTypeController.update/2` pattern-matches
`{:ok, user} = Users.update_spoiler_type(...)`, so a `spoiler_type` value
outside `static/click/hover/off` raises `MatchError` instead of rendering
an error, and a request without `user` params raises
`Phoenix.ActionClauseError`. Only crafted requests hit either (the bundled
frontend submits a select), but both are 500s on user input.

Pinned in: `test/philomena_web/controllers/filter/spoiler_type_controller_test.exs`

## Invalid report submissions 500 instead of re-rendering the form

The shared `PhilomenaWeb.ReportController.create/5` re-renders `"new.html"`
on changeset failure and "depend[s] on the controller that called us to have
set up the view already (Phoenix does this)" — but Phoenix's default view is
derived from the _calling_ controller's name, and none of
`PhilomenaWeb.Image.ReportView`, `PhilomenaWeb.Image.Comment.ReportView`, or
`PhilomenaWeb.Conversation.ReportView` exist (only the wrappers' `new`
actions call `put_view(ReportView)`; `create` does not). So every invalid
report submission — blank reason, or a missing/empty hidden `user_agent`
field (the changeset `validate_required`s it) — raises `ArgumentError`
(a 500) instead of showing the validation error. Confirmed for the topic
post and gallery wrappers too (`PhilomenaWeb.Topic.Post.ReportView` and
`PhilomenaWeb.Gallery.ReportView` don't exist either); likely affects every
`*.ReportController` wrapper — check the profile ones as they are
characterized.

Pinned in: `test/philomena_web/controllers/image/report_controller_test.exs`,
`test/philomena_web/controllers/image/comment/report_controller_test.exs`,
`test/philomena_web/controllers/conversation/report_controller_test.exs`,
`test/philomena_web/controllers/topic/post/report_controller_test.exs`,
`test/philomena_web/controllers/gallery/report_controller_test.exs`

## `DELETE /notifications/:id` is routed but has no controller action

The router declares `resources "/notifications", NotificationController,
only: [:index, :delete]`, but the controller defines no `delete/2`, so any
request to the route raises `UndefinedFunctionError` (a 500). Notification
clearing actually happens through the per-type read controllers. Removal
candidate.

Pinned in: `test/philomena_web/controllers/notification_controller_test.exs`

## `GET /tag_changes` resource params change the heading but not the results

`TagChangeController.index/2` passes `resource_type`/`resource_id` through
to the template, which renders a "Showing tag changes for image #X" heading
— but `TagChanges.load/3` builds its search query from the `tcq` param
alone, so the listing still contains every tag change. A link carrying only
resource params claims a filter it does not apply; actual filtering relies
on the caller also passing `tcq` (e.g. `image_id:X`).

Pinned in: `test/philomena_web/controllers/tag_change_controller_test.exs`

## Poll votes are recorded for options of any poll

`PollVotes.filter_options/4` maps the submitted `option_ids` straight into
insert rows without checking that they belong to the poll being voted on
(the function carries a `# TODO: enforce integrity at the constraint level`
admitting the gap). `POST .../poll/votes` with an option id from a
different poll succeeds, counts against that other poll's option, and even
lets a user effectively vote twice on the foreign poll (the `voted?` guard
only inspects the poll in the URL). A non-integer option id raises
`ArgumentError` in `String.to_integer/1` (a 500) instead of rendering an
error.

Pinned in: `test/philomena_web/controllers/topic/poll/vote_controller_test.exs`

## `POST /dnp` 500s when the tag is not one of the user's linked tags

`DnpEntries.create_dnp_entry/3` looks the submitted `tag_id` up in the
selectable-tags list and passes a miss (`nil`) straight into
`DnpEntry.update_changeset/3`, which crashes on `tag.id` with
`BadMapError`. The bundled form only offers valid tags, but any crafted
submission naming a tag outside the user's verified artist links is a 500
instead of a validation error. Same nil pass-through family as the
`load_resource` entry above; `update_dnp_entry/3` shares the shape.

Pinned in: `test/philomena_web/controllers/dnp_entry_controller_test.exs`

## `DELETE /profiles/:profile_id/artist_links/:id` is a dead route

The router generates a full `resources "/artist_links"` set, but
`Profile.ArtistLinkController` defines no `delete/2`. Nobody below admin
can reach it (the Canary `:delete` check on the profile user fails first,
redirecting with the authorization flash), and an admin — who passes every
ability check — gets `UndefinedFunctionError` (a 500). Either the route
should be restricted like `:index`/`:show`/etc. or the action implemented;
until then it is a removal candidate.

Pinned in: `test/philomena_web/controllers/profile/artist_link_controller_test.exs`

## Moderators creating a commission on another profile create it for themselves

`Profile.CommissionController`'s `:ensure_correct_user` lets moderators and
admins through, and `:ensure_no_commission`/`:ensure_links_verified` check
the _profile_ user — but `create/2` builds the commission from
`current_user`. A moderator POSTing to an artist's
`/profiles/:slug/commission` therefore creates a commission attached to the
moderator's own account (and is redirected to their own profile), while the
artist still has none. The same applies to a moderator using the `new` form
on another profile.

Pinned in: `test/philomena_web/controllers/profile/commission_controller_test.exs`

## The artist-links index always lists the current user's links

`Profile.ArtistLinkController.index/2` queries
`ArtistLink |> where(user_id: ^current_user.id)` — the `:profile_id` in the
URL only gates authorization (`:create_links`). A moderator opening an
artist's `/profiles/:slug/artist_links` page sees their own (usually empty)
link list rather than the artist's, with the artist's profile in the
breadcrumbs.

Pinned in: `test/philomena_web/controllers/profile/artist_link_controller_test.exs`

## Anonymous users get the authorization flash on `/filters/new`

`FilterController` places `load_and_authorize_resource` before
`RequireUserPlug`, and the anonymous Canada impl has no `:new`/`:create`
rules for `Filter`, so anonymous users hitting `/filters/new` (or POSTing
`/filters`) get "You can't access that page." instead of the sign-in
message the plug order suggests was intended. `RequireUserPlug` is
effectively dead on this controller.

Pinned in: `test/philomena_web/controllers/filter_controller_test.exs`

## `PATCH/PUT /registrations` is a dead route

The router declares `resources "/registrations", RegistrationController,
only: [:edit, :update], singleton: true`, but the controller defines no
`update/2` — account settings are actually saved through the nested
`Registration.*` singletons and `/settings`. Any logged-in request raises
`UndefinedFunctionError` (a 500). Removal candidate, same family as
`DELETE /notifications/:id`.

Pinned in: `test/philomena_web/controllers/registration_controller_test.exs`

## Enabling or disabling TOTP crashes after sending the redirect

The success branch of `Registration.TotpController.update/2` pipes the conn
through `UserAuth.totp_auth_user/3` (which sends the redirect) but then ends
with `Users.reindex_user(user)`, returning a `%User{}` instead of the conn.
Plug's pipeline check then raises `RuntimeError` ("expected action/2 to
return a Plug.Conn"). The user sees a working redirect — the TOTP change,
the reindex, and the response all happen — but every successful 2FA
enable/disable logs a 500, and the `:totp_backup_codes` flash it put on the
discarded conn still reaches the session only because `redirect` serializes
the session before the return value is inspected.

Pinned in: `test/philomena_web/controllers/registration/totp_controller_test.exs`

## A wrong TOTP code while enabling 2FA is a 500

`User.consume_totp_token_changeset/2` falls back to the backup-code check
when the token isn't a valid TOTP code — but a user who is still _enabling_
2FA has `otp_backup_codes: nil`, so `Enum.any?/2` raises
`Protocol.UndefinedError`. Mistyping the six-digit code on the setup page
crashes instead of re-rendering with a validation error (the wrong-password
branch, checked first, re-renders fine).

Pinned in: `test/philomena_web/controllers/registration/totp_controller_test.exs`

## A numeric token posted to `/sessions/totp` by a non-TOTP user is a 500

Nothing stops a logged-in user without TOTP enabled from reaching the
second-factor endpoint. A non-numeric token takes the invalid-token branch
(flash + logout), but a numeric one reaches `User.totp_secret/1` with nil
secret fields and crashes in the encryptor (`FunctionClauseError` from
`Base.decode64!(nil)`). A missing `"user"` param is likewise a `MatchError`
500 — `create/2` pattern-matches in the function body.

Pinned in: `test/philomena_web/controllers/session/totp_controller_test.exs`

## Submitting an empty username on `/registrations/name` is a 500

`cast/3` treats `""` as an empty value and turns the `:name` change into
`nil`, and `validate_name`'s `update_change(:name, &String.trim/1)` then
crashes with `FunctionClauseError`. Clearing the name field and submitting
the rename form is a 500 instead of a "can't be blank" error. (Other
`String.trim` `update_change`s on required fields likely share the shape.)

Pinned in: `test/philomena_web/controllers/registration/name_controller_test.exs`

## A logged-in unconfirmed user cannot use their confirmation link

`EnsureUserEnabledPlug` (in the `:browser` pipeline) logs out any session
whose account is unconfirmed before the confirmation controller can run, so
an unconfirmed user who is still logged in from registration and clicks
their emailed `/confirmations/:token` link is logged out with "Your account
is not currently active." and stays unconfirmed. The link works on the next
(logged-out) attempt, which is why this goes unnoticed.

Pinned in: `test/philomena_web/controllers/confirmation_controller_test.exs`

## Invalid user-ban submissions 500 instead of re-rendering the form

`Admin.UserBanController.create/2`'s error branch does
`render(conn, "new.html", changeset: changeset)`, but
`admin/user_ban/new.html.slime` reads `@target_user` — an assign only the
`new` action sets. Any changeset failure (blank reason, bad `valid_until`)
therefore raises `ArgumentError` ("assign @target_user not available")
instead of showing the validation error. The sibling subnet/fingerprint
ban, site notice, and mod note create-failure branches re-render fine —
their `new.html` templates read only `@changeset`/`@conn`.

Pinned in: `test/philomena_web/controllers/admin/user_ban_controller_test.exs`

## `GET /admin/mod_notes/new` without notable params is a 500

`Admin.ModNoteController.new/2` has a single clause pattern-matching
`%{"notable_type" => _, "notable_id" => _}` with no fallback (unlike the
subnet/fingerprint ban `new` actions, which accept a bare request), so
opening `/admin/mod_notes/new` without both query params passes
authorization and then raises `Phoenix.ActionClauseError`.

Pinned in: `test/philomena_web/controllers/admin/mod_note_controller_test.exs`

## Unparsable IPs crash the subnet-ban index and new form

Both `GET /admin/subnet_bans?ip=…` and `GET /admin/subnet_bans/new?specification=…`
pattern-match `{:ok, ip} = EctoNetwork.INET.cast(ip)`, so a value that
doesn't parse as an IP/CIDR raises `MatchError` (a 500) rather than
rendering a form error or ignoring the parameter.

Pinned in: `test/philomena_web/controllers/admin/subnet_ban_controller_test.exs`

## Badge create/update validation failures are 500s — the error branches are dead

`Badges.create_badge/1`, `update_badge/2`, and `update_badge_image/2`
return `{:error, %Ecto.Changeset{}}` on failure, but the corresponding
`Admin.BadgeController` / `Admin.Badge.ImageController` actions only match
`{:error, :badge, changeset, _changes}` — a Multi-shaped tuple the context
never produces. Any invalid submission (missing image, blank title) on
`POST /admin/badges`, `PATCH/PUT /admin/badges/:id`, or
`PATCH/PUT /admin/badges/:badge_id/image` raises `CaseClauseError` instead
of re-rendering the form. The advert controllers, otherwise near-identical,
match `{:error, changeset}` correctly and re-render (200).

Pinned in: `test/philomena_web/controllers/admin/badge_controller_test.exs`,
`test/philomena_web/controllers/admin/badge/image_controller_test.exs`

## `POST /admin/dnp_entries/:dnp_entry_id/transition` 500s on an unknown id

`Admin.DnpEntry.TransitionController` loads the entry with plain
`load_resource`, which has no not-found handler on `:create`, so an unknown
`dnp_entry_id` leaves `@dnp_entry` nil and `DnpEntries.transition_dnp_entry/3`
raises `FunctionClauseError` (it requires a `%DnpEntry{}`) — the admin-
transition flavor of the "Unknown ids 500 on non-`:show` actions loaded with
plain `load_resource`" family. The sibling artist-link create controllers use
`load_and_authorize_resource` instead, so their unknown-id case is the
not-authorized redirect rather than a crash; a non-integer id is still the
`Ecto.Query.CastError` 500 across all of them.

Pinned in:
`test/philomena_web/controllers/admin/dnp_entry/transition_controller_test.exs`

## `PATCH /admin/batch/tags` reports optimistic success for ids it never touched

`Admin.Batch.TagController.update/2`, on the `{:ok, _}` branch of
`Images.batch_update/4`, responds `%{succeeded: image_ids, failed: []}` echoing
back **every** id from the request — including ids that matched no image. The
batch query filters to existing, non-hidden images and the transaction
succeeds over whatever subset remains (even the empty set), so a client
batch-tagging a nonexistent or hidden image id is told it succeeded, and
`failed` is only ever populated by the otherwise-unreachable catch-all branch.
(A non-integer id is a separate `ArgumentError` 500 from `String.to_integer/1`
before the update runs.)

Pinned in:
`test/philomena_web/controllers/admin/batch/tag_controller_test.exs`

Pinned in (plain-moderator success on each child):
`test/philomena_web/controllers/admin/user/avatar_controller_test.exs`,
`.../activation_controller_test.exs`, `.../verification_controller_test.exs`,
`.../unlock_controller_test.exs`, `.../erase_controller_test.exs`,
`.../api_key_controller_test.exs`, `.../downvote_controller_test.exs`,
`.../vote_controller_test.exs`, `.../wipe_controller_test.exs`,
`.../force_filter_controller_test.exs`

## `Admin.User.*` children split unknown-slug handling by verb

The `Admin.User.*` singleton children load their target with plain
`load_resource` (`id_field: "slug"`, `persisted: true`), and Canary's global
`not_found_handler` runs only for `:show`/`:edit`/`:update`/`:delete`. So an
unknown slug behaves oppositely depending on the action's verb, even inside a
single controller: the `:delete` actions (deactivate, unverify, api_key,
downvotes, votes, unforce_filter) redirect to `/` with "Couldn't find what you
were looking for!", while the `:create`/`:new` actions pass the `nil` straight
into the context and 500 — `FunctionClauseError` from `reactivate_user` /
`verify_user` / `unlock_user` / `force_filter` / `change_user` (all require a
`%User{}`), and `WipeController` a `BadMapError` dereferencing `nil.id` before
the worker enqueue. This is the `Admin.User.*` flavor of the "Unknown ids 500
on non-`:show` actions loaded with plain `load_resource`" family;
`ActivationController` and `VerificationController` exhibit both shapes at once.
`EraseController` is the lone exception — a `prevent_deleting_nonexistent_users`
guard catches the `nil` and redirects `:new`/`:create` to `/admin/users`
instead of crashing.

Pinned in:
`test/philomena_web/controllers/admin/user/activation_controller_test.exs`,
`.../verification_controller_test.exs`, `.../unlock_controller_test.exs`,
`.../wipe_controller_test.exs`, `.../force_filter_controller_test.exs`,
`.../avatar_controller_test.exs`, `.../api_key_controller_test.exs`,
`.../downvote_controller_test.exs`, `.../vote_controller_test.exs`,
`.../erase_controller_test.exs`

## Replacing an image's file nulls its original hash even when the replacement fails

`Image.FileController.update/2` calls `Images.remove_hash/1` (which nulls
`image_orig_sha512_hash`, the dedup fingerprint that stops re-uploads of the
same file) **before** `Images.update_file/2`, and only branches on
`update_file`'s result afterward. So a moderator whose replace request fails —
e.g. a request with no file, which `image_changeset`'s
`validate_required(:image)` rejects, taking the "Failed to update file!"
branch — has already had the image's original hash wiped as a side effect,
without the file being replaced. A successful replace re-sets the hash from the
new file's analysis, so the null is only observable on the failure path.

Pinned in: `test/philomena_web/controllers/image/file_controller_test.exs`

## `PATCH/PUT /images/:image_id/uploader` 500s on an unknown username

`Image.Image.uploader_changeset/2` resolves the submitted `username` with
`Repo.get_by!(User, name: username)`, so reassigning an image's uploader to a
name that does not exist raises `Ecto.NoResultsError` (a 500) instead of
re-rendering with a validation error. The bundled form autocompletes real
names, so only a crafted request hits it. (A blank username is fine — it
anonymizes the image with `user_id: nil`.)

Pinned in: `test/philomena_web/controllers/image/uploader_controller_test.exs`

## `Image.AnonymousController` splits unknown-id handling by verb

`Image.AnonymousController` and `Image.UploaderController` load their image
with plain `load_resource` (after a hand-rolled `verify_authorized` gate on
`:show, :ip_address`), so Canary's global `not_found_handler` runs only on the
`:delete`/`:update` verbs. `DELETE /images/:image_id/anonymous` and
`PATCH/PUT /images/:image_id/uploader` with an unknown id therefore redirect to
`/` with "Couldn't find what you were looking for!", while
`POST /images/:image_id/anonymous` (`:create`) passes the `nil` straight into
`Images.update_anonymous/2` and raises `FunctionClauseError` (its head requires
a `%Image{}`). This is the image-mod-tools flavor of the "Unknown ids 500 on
non-`:show` actions loaded with plain `load_resource`" family. The sibling
`load_and_authorize_resource` controllers (`File`, `Scratchpad`, `TagLock`)
instead take the not-authorized redirect on an unknown id; a non-integer id is
the `Ecto.Query.CastError` 500 across all of them.

Pinned in: `test/philomena_web/controllers/image/anonymous_controller_test.exs`,
`test/philomena_web/controllers/image/uploader_controller_test.exs`

## Topic/post hide with a blank reason 500s — the error branch never matches

`Topics.hide_topic/3` and `Posts.hide_post/3` run a `Multi` whose first step is
the `hide_changeset`, which `validate_required`s `deletion_reason`. A blank
reason makes the transaction fail, and both context functions return the raw
`Multi` failure tuple unchanged (`error -> error`) — a 4-tuple
`{:error, :topic/:post, changeset, changes_so_far}`. But
`Topic.HideController.create/2` and `Topic.Post.HideController.create/2` only
match `{:ok, ...}` and `{:error, _changeset}` (a 2-tuple), so the 4-tuple
matches neither and raises `CaseClauseError` (a 500) instead of redirecting
with the "Unable to delete…" flash the error branch was meant to serve. The
error branch is effectively dead. (The sibling `Topic.LockController` does not
share this: `Topics.lock_topic/3` is a plain `Repo.update` that returns a
2-tuple, so a blank `lock_reason` correctly redirects with "Unable to lock the
topic!")

Pinned in: `test/philomena_web/controllers/topic/hide_controller_test.exs`,
`test/philomena_web/controllers/topic/post/hide_controller_test.exs`

## Moving a topic to a nonexistent forum 500s; the move error branch is dead

`Topic.MoveController.create/2` calls `String.to_integer/1` on the raw
`target_forum_id` (a non-integer value is an `ArgumentError` 500) and then
`Topics.move_topic/2`, which `put_change`s `forum_id` with no
`foreign_key_constraint`. A nonexistent target forum therefore raises
`Ecto.ConstraintError` (a 500) inside the `Multi` transaction. Its
`{:error, _changeset}` branch is unreachable for the same reason as the hide
controllers above (a `Multi` failure is a 4-tuple), and `create/2` has no
fallback clause, so a request without the `topic[target_forum_id]` param is a
`Phoenix.ActionClauseError` 500.

Pinned in: `test/philomena_web/controllers/topic/move_controller_test.exs`

## Poll editing is admin-only despite the moderator-shaped verify plug

`Topic.PollController` loads the `Forum` with a plain
`load_and_authorize_resource` and **no** `CanaryMapPlug`, so the forum is
authorized against the raw action name (`:edit`/`:update`). Moderators have only
`:show` on forums, so they are rejected with "You can't access that page." —
only an admin (the blanket `can?(admin, …)` rule) passes. This contradicts the
controller's later `verify_authorized` plug, which gates on `:hide` of the topic
(a moderator capability), and is inconsistent with the sibling topic mod tools
(move/stick/lock/hide) and `Topic.Poll.VoteController`, which all map their
forum check to `:show` via `CanaryMapPlug` and so admit moderators.

Pinned in: `test/philomena_web/controllers/topic/poll_controller_test.exs`

## Deleting a poll vote leaves the cached tallies stale

`PollVotes.delete_poll_vote/1` (behind `DELETE /poll/votes/:id`) is a bare
`Repo.delete/1`. Unlike the create path, which increments the option's
`vote_count` and the poll's `total_votes`, the delete path never decrements
them, so removing a vote drops the `poll_votes` row but leaves both cached
counters at their pre-deletion values. An unknown vote id is an
`Ecto.NoResultsError` 500 (`get_poll_vote!/1`) and a non-integer id an
`Ecto.Query.CastError` 500.

Pinned in: `test/philomena_web/controllers/topic/poll/vote_controller_test.exs`

## Badge-award create/update validation failures are 500s — the error branches are dead

`Profile.AwardController` create/update both branch on
`{:error, changeset}` to re-render the form, but `Badges.create_badge_award/3`
and `update_badge_award/2` call `Award.changeset/2`, which has **no
validations and never declares the `badge_id` foreign-key constraint**. So the
only way to make either fail is a bad `badge_id`, and that raises
`Ecto.ConstraintError` (a 500, `fk_rails_…` foreign_key_constraint) at
insert/update time rather than returning `{:error, changeset}` — the re-render
branches are unreachable. A nonexistent `badge_id` on
`POST /profiles/:slug/awards` creates nothing; on
`PATCH/PUT /profiles/:slug/awards/:id` the award keeps its old badge. (Same
family as the `Admin.BadgeController` dead-error-branch entry above, but the
crash is `Ecto.ConstraintError` rather than `CaseClauseError`.)

Pinned in: `test/philomena_web/controllers/profile/award_controller_test.exs`

## The IP profile pages 500 on an unparsable IP

`GET /ip_profiles/:id` and `GET /ip_profiles/:ip_profile_id/source_changes`
pattern-match `{:ok, ip} = EctoNetwork.INET.cast(ip)` on the raw path segment,
so a value that doesn't parse as an IP/CIDR raises `MatchError` (a 500) rather
than a not-found response — the same shape as the admin subnet-ban index/new
forms. The fingerprint equivalents (`GET /fingerprint_profiles/:id` and its
`/source_changes`) do **not** share this: the fingerprint is used directly as
a string, so any value renders a 200 (an empty listing when nothing matches).

Pinned in: `test/philomena_web/controllers/ip_profile_controller_test.exs`,
`test/philomena_web/controllers/ip_profile/source_change_controller_test.exs`

## `POST /duplicate_reports` 500s on an unknown image id

`DuplicateReportController.create/2` loads both the source and target images
with `Repo.get!/2` before authorizing or validating, so a request naming an
`image_id` (or `duplicate_of_image_id`) that does not exist raises
`Ecto.NoResultsError` (a 500) rather than a validation failure. The bundled
form is rendered from an existing image page, so only a crafted request hits
it. (Reporting an image as a duplicate of itself is a proper validation error
that redirects with the "Failed to submit duplicate report" flash.)

Pinned in: `test/philomena_web/controllers/duplicate_report_controller_test.exs`

## The tag-change revert endpoints 500 on malformed params

`TagChange.RevertController.create/2` only has a clause for
`%{"ids" => ids}` when `ids` is a list, so a scalar `ids` value has no
matching clause and raises `Phoenix.ActionClauseError` (a 500).
`TagChange.FullRevertController.create/2` dispatches on
`user_id`/`ip`/`fingerprint` with no fallback clause, so a request carrying
none of the three raises `CaseClauseError` (a 500). Both are moderator-gated
form endpoints, so only a crafted or malformed submission reaches the crash;
an empty `ids` list, by contrast, is a clean success that reverts nothing and
reports "0 tag changes".

Pinned in: `test/philomena_web/controllers/tag_change/revert_controller_test.exs`,
`test/philomena_web/controllers/tag_change/full_revert_controller_test.exs`

## Tag-image update validation failures are 500s — the error branch is dead

`Tag.ImageController.update/2` branches on `{:error, :tag, changeset, changes}`
— a `Multi`-shaped 4-tuple — but `Tags.update_tag_image/2` returns a plain
`{:error, changeset}` on failure (e.g. a request with no file, which
`image_changeset`'s `validate_required(:image)` rejects). The 2-tuple matches
neither the `{:ok, tag}` nor the 4-tuple branch, so a failed upload raises
`CaseClauseError` (a 500) instead of re-rendering the form. Same
dead-error-branch family as the badge (`CaseClauseError`) and topic/post-hide
entries above.

Pinned in: `test/philomena_web/controllers/tag/image_controller_test.exs`

## `PATCH/PUT /channels/:id` silently ignores fetcher-managed fields

`ChannelController.update/2` calls `Channels.update_channel/2`, whose changeset
(`Channel.changeset/2`) casts only `:type` and `:short_name`. The live-state
fields — `title`, `nsfw`, `is_live`, `viewers`, `thumbnail_url`,
`last_fetched_at` — are cast only by the separate `Channel.update_changeset/2`
used by `update_channel_state/2` (the fetcher path). So a crafted
`PATCH /channels/:id` carrying e.g. `channel[title]` succeeds and redirects
with "Channel updated successfully." but leaves the title unchanged. The
bundled edit form only exposes short_name/type/artist_tag, so this is a
crafted-request-only surprise rather than a user-facing bug; more a note that
the staff edit form and the fetcher own disjoint slices of the channel record.

Pinned in: `test/philomena_web/controllers/channel_controller_test.exs`

## Tag-admin CRUD unknown slugs redirect with different flashes by role

The `Tag.{Alias,Image,Reindex}Controller` children and `TagController`
edit/update/delete all load their target with
`load_and_authorize_resource(..., id_field: "slug", persisted: true)`. On an
unknown slug the resource is nil, and the flash the visitor gets depends on
their role: a plain/`role_map` moderator fails authorization on the nil
resource and takes Canary's **unauthorized** handler ("You can't access that
page."), while an admin — for whom `can?(admin, _, nil)` is true — passes
authorization and instead takes the **not-found** handler ("Couldn't find what
you were looking for!"). Both are a 302 to `/`; neither crashes (contrary to
what one might expect from the "admin passes every check → 500" family
elsewhere — `persisted: true` makes Canary run the not-found handler before the
controller action, so the nil never reaches the context functions here). More a
minor observability quirk than a bug: the flash text distinguishes "no such
tag" from "not allowed" only for admins.

Pinned in: `test/philomena_web/controllers/tag_controller_test.exs`,
`test/philomena_web/controllers/tag/alias_controller_test.exs`,
`test/philomena_web/controllers/tag/reindex_controller_test.exs`

## `GET /fetch/tags` 500s without a well-formed `ids` list

`Fetch.TagController.index/2` has a single clause matching
`%{"ids" => ids} when is_list(ids)` and no fallback, so a request with no
`ids` param, a scalar `ids` value, or an empty list (which the form encoding
serializes away to no param at all) raises `Phoenix.ActionClauseError`
(a 500) instead of responding with an empty `%{"tags" => []}`. The bundled
frontend always sends `ids[]` entries, so only crafted requests hit it —
same malformed-params family as the tag-change revert endpoints.

Pinned in: `test/philomena_web/controllers/fetch/tag_controller_test.exs`

## `POST /images/scrape` answers every non-result with the JSON literal `null`

`Image.ScrapeController.create/2` pipes whatever `Scrapers.scrape!/1`
returns straight into `json/2`, and `scrape!` returns `nil` whenever no
scraper claims the URL — a direct link with a non-image content type, a
hostless or malformed URL, or a missing/blank `url` param entirely. All of
these are a 200 whose body is the four characters `null`, not a 4xx or a
structured error object; clients must distinguish "no result" from success
by inspecting the body. (The bundled upload form handles the `null` body,
so this only surprises other API consumers.)

Pinned in: `test/philomena_web/controllers/image/scrape_controller_test.exs`
