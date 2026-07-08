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

Pinned in: `test/philomena_web/controllers/forum_controller_test.exs`

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
