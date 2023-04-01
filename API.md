<h1>API</h1>

<p>Derpibooru provides a JSON API for major site functionality, which can be freely used by anyone wanting to produce tools for the site or other web applications that use the data provided within Derpibooru.</p>

<p>Note that if you are looking to <em>continuously scrape the entire website</em>, we offer <a href="https://derpibooru.org/pages/data_dumps">nightly database dumps</a> instead. Consider if these suit your needs first, then rely on the API if they do not.</p>

<h2>Licensing</h2>

<p>Anyone may use the API. Users making abusively high numbers of requests or excessively expensive requests will be asked to stop, and banned if they do not. Your application must properly cache, and respect server-side cache expiry times. Your client must gracefully back off if requests fail, preferably exponentially or fatally.</p>

<p>If images are used, the artist must always be credited (if provided) and the original source URL must be displayed alongside the image, either in textual form or as a link. A link to the Derpibooru page is optional but recommended; we recommend the derpibooru.org domain as a canonical domain. The <code>https:</code> protocol must be specified on all URLs.</p>

<h2>Parameters</h2>

<p>This is a list of general parameters that are useful when working with the API. Not all parameters may be used in every request.</p>

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>filter_id</code></td>
      <td>Assuming the user can access the filter ID given by the parameter, overrides the current filter for this request. This is primarily useful for unauthenticated API access.</td>
    </tr>
    <tr>
      <td><code>key</code></td>
      <td>An optional authentication token. If omitted, no user will be authenticated.<br/><br/>You can find your authentication token in your <a href="https://derpibooru.org/registration/edit">account settings</a>.</td>
    </tr>
    <tr>
      <td><code>page</code></td>
      <td>Controls the current page of the response, if the response is paginated. Empty values default to the first page.</td>
    </tr>
    <tr>
      <td><code>per_page</code></td>
      <td>Controls the number of results per page, up to a limit of 50, if the response is paginated. The default is 25.</td>
    </tr>
    <tr>
      <td><code>q</code></td>
      <td>The current search query, if the request is a search request.</td>
    </tr>
    <tr>
      <td><code>sd</code></td>
      <td>The current sort direction, if the request is a search request.</td>
    </tr>
    <tr>
      <td><code>sf</code></td>
      <td>The current sort field, if the request is a search request.</td>
    </tr>
  </tbody>
</table>

<h2>Routes</h2>

<p>The interested reader may find the implementations of these endpoints <a href="https://github.com/derpibooru/philomena/tree/master/lib/philomena_web/controllers/api">here</a>. For the purposes of this document, a brief overview is given.</p>

<table>
  <thead>
    <tr>
      <th>Method</th>
      <th>Path</th>
      <th>Allowed Query Parameters</th>
      <th>Description</th>
      <th>Response Format</th>
      <th>Example</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/comments/:comment_id</code></td>
      <td></td>
      <td>Fetches a <em>comment response</em> for the comment ID referenced by the <code>comment_id</code> URL parameter.</td>
      <td><code>{"comment":<a href="#comment-response">comment-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/comments/1000"><code>/api/v1/json/comments/1000</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/images/:image_id</code></td>
      <td><code>key, filter_id</code></td>
      <td>Fetches an <em>image response</em> for the image ID referenced by the <code>image_id</code> URL parameter.</td>
      <td><code>{"image":<a href="#image-response">image-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/images/1"><code>/api/v1/json/images/1</code></a></td>
    </tr>
    <tr>
      <td><code>POST</code></td>
      <td><code>/api/v1/json/images</code></td>
      <td><code>key, url</code></td>
      <td>Submits a new image. Both <code>key</code> and <code>url</code> are required. Errors will result in an <code>{"errors":<a href="#image-errors-response">image-errors-response</a>}</code>.</td>
      <td><code>{"image":<a href="#image-response">image-response</a>}</code></td>
      <td><a href="#posting-images">Posting images</a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/images/featured</code></td>
      <td><code></code></td>
      <td>Fetches an <em>image response</em> for the for the current featured image.</td>
      <td><code>{"image":<a href="#image-response">image-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/images/featured"><code>/api/v1/json/images/featured</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/tags/:tag_id</code></td>
      <td><code></code></td>
      <td>Fetches a <em>tag response</em> for the <em>tag slug</em> given by the <code>tag_id</code> URL parameter. The tag's ID is <em>not</em> used.</td>
      <td><code>{"tag":<a href="#tag-response">tag-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/tags/artist-colon-atryl"><code>/api/v1/json/tags/artist-colon-atryl</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/posts/:post_id</code></td>
      <td><code></code></td>
      <td>Fetches a <em>post response</em> for the post ID given by the <code>post_id</code> URL parameter.</td>
      <td><code>{"post":<a href="#post-response">post-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/posts/2730144"><code>/api/v1/json/posts/2730144</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/profiles/:user_id</code></td>
      <td><code></code></td>
      <td>Fetches a <em>profile response</em> for the user ID given by the <code>user_id</code> URL parameter.</td>
      <td><code>{"user":<a href="#user-response">user-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/profiles/216494"><code>/api/v1/json/profiles/216494</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/filters/:filter_id</code></td>
      <td><code>key</code></td>
      <td>Fetches a <em>filter response</em> for the filter ID given by the <code>filter_id</code> URL parameter.</td>
      <td><code>{"filter":<a href="#filter-response">filter-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/filters/56027"><code>/api/v1/json/filters/56027</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/filters/system</code></td>
      <td><code>page</code></td>
      <td>Fetches a list of <em>filter responses</em> that are flagged as being <em>system</em> filters (and thus usable by anyone).</td>
      <td><code>{"filters":[<a href="#filter-response">filter-response</a>]}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/filters/system"><code>/api/v1/json/filters/system</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/filters/user</code></td>
      <td><code>key, page</code></td>
      <td>Fetches a list of <em>filter responses</em> that belong to the user given by <em>key</em>. If no <em>key</em> is given or it is invalid, will return a <em>403 Forbidden</em> error.</td>
      <td><code>{"filters":[<a href="#filter-response">filter-response</a>]}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/filters/user"><code>/api/v1/json/filters/user</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/user</code></td>
      <td><code>key</code></td>
      <td>Fetches the basic user data that belong to the user given by <em>key</em>. If no <em>key</em> is given or it is invalid, will return a <em>403 Forbidden</em> error.</td>
      <td><code>{"user":<a href="#user-response">user-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/user"><code>/api/v1/json/user</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/oembed</code></td>
      <td><code>url</code></td>
      <td>Fetches an <em>oEmbed response</em> for the given app link or CDN URL.</td>
      <td><code><a href="#oembed-response">oembed-response</a></code></td>
      <td><a href="https://derpibooru.org/api/v1/json/oembed?url=https://derpicdn.net/img/2012/1/2/3/full.png"><code>/api/v1/json/oembed?url=https://derpicdn.net/img/2012/1/2/3/full.png</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/search/comments</code></td>
      <td><code>key, page</code></td>
      <td>Executes the search given by the <code>q</code> query parameter, and returns <em>comment responses</em> sorted by descending creation time.</td>
      <td><code>{"comments":[<a href="#comment-response">comment-response</a>]}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/search/comments?q=image_id:1000000"><code>/api/v1/json/search/comments?q=image_id:1000000</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/search/galleries</code></td>
      <td><code>key, page</code></td>
      <td>Executes the search given by the <code>q</code> query parameter, and returns <em>gallery responses</em> sorted by descending creation time.</td>
      <td><code>{"galleries":[<a href="#gallery-response">gallery-response</a>]}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/search/galleries?q=title:mean*"><code>/api/v1/json/search/galleries?q=title:mean*</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/search/posts</code></td>
      <td><code>key, page</code></td>
      <td>Executes the search given by the <code>q</code> query parameter, and returns <em>post responses</em> sorted by descending creation time.</td>
      <td><code>{"posts":[<a href="#post-response">post-response</a>]}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/search/posts?q=subject:time wasting thread"><code>/api/v1/json/search/posts?q=subject:time wasting thread</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/search/images</code></td>
      <td><code>key, filter_id, page, per_page, q, sd, sf</code></td>
      <td>Executes the search given by the <code>q</code> query parameter, and returns <em>image responses</em>.</td>
      <td><code>{"images":[<a href="#image-response">image-response</a>]}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/search/images?q=safe"><code>/api/v1/json/search/images?q=safe</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/search/tags</code></td>
      <td><code>page</code></td>
      <td>Executes the search given by the <code>q</code> query parameter, and returns <em>tag responses</em> sorted by descending image count.</td>
      <td><code>{"tags":[<a href="#tag-response">tag-response</a>]}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/search/tags?q=analyzed_name:wing"><code>/api/v1/json/search/tags?q=analyzed_name:wing</code></a></td>
    </tr>
    <tr>
      <td><code>POST</code></td>
      <td><code>/api/v1/json/search/reverse</code></td>
      <td><code>key, url, distance</code></td>
      <td>Returns <em>image responses</em> based on the results of reverse-searching the image given by the <code>url</code> query parameter.</td>
      <td><code>{"images":[<a href="#image-response">image-response</a>]}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/search/reverse?url=https://derpicdn.net/img/2019/12/24/2228439/full.jpg" data-method="post"><code>/api/v1/json/search/reverse?url=https://derpicdn.net/img/2019/12/24/2228439/full.jpg</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/forums</code></td>
      <td></td>
      <td>Fetches a list of <em>forum responses</em>.</td>
      <td><code>{"forums":<a href="#forum-response">forum-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/forums"><code>/api/v1/json/forums</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/forums/:short_name</code></td>
      <td></td>
      <td>Fetches a <em>forum response</em> for the abbreviated name given by the <code>short_name</code> URL parameter.</td>
      <td><code>{"forum":<a href="#forum-response">forum-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/forums/dis"><code>/api/v1/json/forums/dis</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/forums/:short_name/topics</code></td>
      <td><code>page</code></td>
      <td>Fetches a list of <em>topic responses</em> for the abbreviated forum name given by the <code>short_name</code> URL parameter.</td>
      <td><code>{"topics":<a href="#topic-response">topic-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/forums/dis/topics"><code>/api/v1/json/forums/dis/topics</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/forums/:short_name/topics/:topic_slug</code></td>
      <td></td>
      <td>Fetches a <em>topic response</em> for the abbreviated forum name given by the <code>short_name</code> and topic given by <code>topic_slug</code> URL parameters.</td>
      <td><code>{"topic":<a href="#topic-response">topic-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/forums/dis/topics/ask-the-mods-anything"><code>/api/v1/json/forums/dis/topics/ask-the-mods-anything</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/forums/:short_name/topics/:topic_slug/posts</code></td>
      <td><code>page</code></td>
      <td>Fetches a list of <em>post responses</em> for the abbreviated forum name given by the <code>short_name</code> and topic given by <code>topic_slug</code> URL parameters.</td>
      <td><code>{"posts":<a href="#post-response">post-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/forums/dis/topics/ask-the-mods-anything/posts"><code>/api/v1/json/forums/dis/topics/ask-the-mods-anything/posts</code></a></td>
    </tr>
    <tr>
      <td><code>GET</code></td>
      <td><code>/api/v1/json/forums/:short_name/topics/:topic_slug/posts/:post_id</code></td>
      <td></td>
      <td>Fetches a <em>post response</em> for the abbreviated forum name given by the <code>short_name</code>, topic given by <code>topic_slug</code> and post given by <code>post_id</code> URL parameters.</td>
      <td><code>{"post":<a href="#post-response">post-response</a>}</code></td>
      <td><a href="https://derpibooru.org/api/v1/json/forums/dis/topics/ask-the-mods-anything/posts/2761095"><code>/api/v1/json/forums/dis/topics/ask-the-mods-anything/posts/2761095</code></a></td>
    </tr>
  </tbody>
</table>

<h2>Posting Images</h2>

<p>Posting images should be done via request body parameters. An example with all parameters included is shown below.</p>

<p>You are <em>strongly recommended</em> to test code using this endpoint using a local copy of the website's source code. Abuse of the endpoint <strong>will result in a ban</strong>.</p>

<p>You <em>must</em> provide the direct link to the image in the <code>url</code> parameter.</p>

<p>You <em>must</em> set the <code>content-type</code> header to <code>application/json</code> for the site to process your request.</p>

<pre>POST /api/v1/json/images?key=API_KEY</pre>

<pre>{
"image": {
  "description": "[bq]Hey there this is a test post![/bq]\nDescriptions are *weird*.\nHave a >>0 re-upload :)\n",
  "tag_input": "artist needed, safe, derpy hooves, pegasus, pony, adventure in the comments, bag, building, chair, cigar, derpibooru legacy, eyes, featured image, female, grin, gritted teeth, hilarious in hindsight, image macro, it begins, j. jonah jameson, letter, mail, male, mare, meme, muffin, necktie, paper, parody, phone, ponified, sitting, smiling, smoking, song in the comments, spider-man, stallion, swinging",
  "source_url": "https://derpibooru.org/images/0"
},
"url": "https://derpicdn.net/img/view/2012/1/2/0.jpg"
}</pre>

<h2>Image Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>animated</code></td>
      <td>Boolean</td>
      <td>Whether the image is animated.</td>
    </tr>
    <tr>
      <td><code>aspect_ratio</code></td>
      <td>Float</td>
      <td>The image's width divided by its height.</td>
    </tr>
    <tr>
      <td><code>comment_count</code></td>
      <td>Integer</td>
      <td>The number of comments made on the image.</td>
    </tr>
    <tr>
      <td><code>created_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The creation time, in UTC, of the image.</td>
    </tr>
    <tr>
      <td><code>deletion_reason</code></td>
      <td>String</td>
      <td>The hide reason for the image, or <code>null</code> if none provided. This will only have a value on images which are deleted for a rule violation.</td>
    </tr>
    <tr>
      <td><code>description</code></td>
      <td>String</td>
      <td>The image's description.</td>
    </tr>
    <tr>
      <td><code>downvotes</code></td>
      <td>Integer</td>
      <td>The number of downvotes the image has.</td>
    </tr>
    <tr>
      <td><code>duplicate_of</code></td>
      <td>Integer</td>
      <td>The ID of the target image, or <code>null</code> if none provided. This will only have a value on images which are merged into another image.</td>
    </tr>
    <tr>
      <td><code>duration</code></td>
      <td>Float</td>
      <td>The number of seconds the image lasts, if animated, otherwise .04.</td>
    </tr>
    <tr>
      <td><code>faves</code></td>startUniswap
      <td><code>first_seen_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The time, in UTC, the image was first seen (before any duplicate merging).</td>
    </tr>
    <tr>
      <td><code>format</code></td>
      <td>String</td>
      <td>The file extension of the image. One of <code>"gif", "jpg", "jpeg", "png", "svg", "webm"</code>.</td>
    </tr>
    <tr>
      <td><code>height</code></td>
      <td>Integer</td>
      <td>The image's height, in pixels.</td>
    </tr>
    <tr>
      <td><code>hidden_from_users</code></td>
      <td>Boolean</td>
      <td>Whether the image is hidden. An image is hidden if it is merged or deleted for a rule violation.</td>
    </tr>
    <tr>
      <td><code>id</code></td>
      <td>Integer</td>
      <td>The image's ID.</td>
    </tr>
    <tr>
      <td><code>intensities</code></td>
      <td>Object</td>
      <td>Optional object of <a href="https://github.com/derpibooru/cli_intensities">internal image intensity data</a> for deduplication purposes. May be <code>null</code> if intensities have not yet been generated.</td>
    </tr>
    <tr>
      <td><code>mime_type</code></td>
      <td>String</td>
      <td>The MIME type of this image. One of <code>"image/gif", "image/jpeg", "image/png", "image/svg+xml", "video/webm"</code>.</td>
    </tr>
    <tr>
      <td><code>name</code></td>
      <td>String</td>
      <td>The filename that the image was uploaded with.</td>
    </tr>
    <tr>
      <td><code>orig_sha512_hash</code></td>
      <td>String</td>
      <td>The SHA512 hash of the image as it was originally uploaded.</td>
    </tr>
    <tr>
      <td><code>processed</code></td>
      <td>Boolean</td>
      <td>Whether the image has finished optimization.</td>
    </tr>
    <tr>
      <td><code>representations</code></td>
      <td>Object</td>
      <td>A mapping of representation names to their respective URLs. Contains the keys <code>"full", "large", "medium", "small", "tall", "thumb", "thumb_small", "thumb_tiny"</code>.</td>
    </tr>
    <tr>
      <td><code>score</code></td>
      <td>Integer</td>
      <td>The image's number of upvotes minus the image's number of downvotes.</td>
    </tr>
    <tr>
      <td><code>sha512_hash</code></td>
      <td>String</td>
      <td>The SHA512 hash of this image after it has been processed.</td>
    </tr>
    <tr>
      <td><code>size</code></td>
      <td>Integer</td>
      <td>The number of bytes the image's file contains.</td>
    </tr>
    <tr>
      <td><code>source_url</code></td>
      <td>String</td>
      <td>The current source URL of the image.</td>
    </tr>
    <tr>
      <td><code>spoilered</code></td>
      <td>Boolean</td>
      <td>Whether the image is hit by the current filter.</td>
    </tr>
    <tr>
      <td><code>tag_count</code></td>
      <td>Integer</td>
      <td>The number of tags present on the image.</td>
    </tr>
    <tr>
      <td><code>tag_ids</code></td>
      <td>Array</td>
      <td>A list of tag IDs the image contains.</td>
    </tr>
    <tr>
      <td><code>tags</code></td>
      <td>Array</td>
      <td>A list of tag names the image contains.</td>
    </tr>
    <tr>
      <td><code>thumbnails_generated</code></td>
      <td>Boolean</td>
      <td>Whether the image has finished thumbnail generation. Do not attempt to load images from <code>view_url</code> or <code>representations</code> if this is false.</td>
    </tr>
    <tr>
      <td><code>updated_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The time, in UTC, the image was last updated.</td>
    </tr>
    <tr>
      <td><code>uploader</code></td>
      <td>String</td>
      <td>The image's uploader.</td>
    </tr>
    <tr>
      <td><code>uploader_id</code></td>
      <td>Integer</td>
      <td>The ID of the image's uploader. <code>null</code> if uploaded anonymously.</td>
    </tr>
    <tr>
      <td><code>upvotes</code></td>
      <td>Integer</td>
      <td>The image's number of upvotes.</td>
    </tr>
    <tr>
      <td><code>view_url</code></td>
      <td>String</td>
      <td>The image's view URL, including tags.</td>
    </tr>
    <tr>
      <td><code>width</code></td>
      <td>Integer</td>
      <td>The image's width, in pixels.</td>
    </tr>
    <tr>
      <td><code>wilson_score</code></td>
      <td>Float</td>
      <td>The lower bound of the <a href="https://en.wikipedia.org/wiki/Binomial_proportion_confidence_interval#Wilson_score_interval">Wilson score interval</a> for the image, based on its upvotes and downvotes, given a z-score corresponding to a confidence of 99.5%.</td>
    </tr>
  </tbody>
</table>

<h2>Comment Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>author</code></td>
      <td>String</td>
      <td>The comment's author.</td>
    </tr>
    <tr>
      <td><code>avatar</code></td>
      <td>String</td>
      <td>The URL of the author's avatar. May be a link to the CDN path, or a <code>data:</code> URI.</td>
    </tr>
    <tr>
      <td><code>body</code></td>
      <td>String</td>
      <td>The comment text.</td>
    </tr>
    <tr>
      <td><code>created_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The creation time, in UTC, of the comment.</td>
    </tr>
    <tr>
      <td><code>edit_reason</code></td>
      <td>String</td>
      <td>The edit reason for this comment, or <code>null</code> if none provided.</td>
    </tr>
    <tr>
      <td><code>edited_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The time, in UTC, this comment was last edited at, or <code>null</code> if it was not edited.</td>
    </tr>
    <tr>
      <td><code>id</code></td>
      <td>Integer</td>
      <td>The comment's ID.</td>
    </tr>
    <tr>
      <td><code>image_id</code></td>
      <td>Integer</td>
      <td>The ID of the image the comment belongs to.</td>
    </tr>
    <tr>
      <td><code>updated_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The time, in UTC, the comment was last updated at.</td>
    </tr>
    <tr>
      <td><code>user_id</code></td>
      <td>Integer</td>
      <td>The ID of the user the comment belongs to, if any.</td>
    </tr>
  </tbody>
</table>

<h2>Forum Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>String</td>
      <td>The forum's name.</td>
    </tr>
    <tr>
      <td><code>short_name</code></td>
      <td>String</td>
      <td>The forum's short name (used to identify it).</td>
    </tr>
    <tr>
      <td><code>description</code></td>
      <td>String</td>
      <td>The forum's description.</td>
    </tr>
    <tr>
      <td><code>topic_count</code></td>
      <td>Integer</td>
      <td>The amount of topics in the forum.</td>
    </tr>
    <tr>
      <td><code>post_count</code></td>
      <td>Integer</td>
      <td>The amount of posts in the forum.</td>
    </tr>
  </tbody>
</table>

<h2>Topic Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>slug</code></td>
      <td>String</td>
      <td>The topic's slug (used to identify it).</td>
    </tr>
    <tr>
      <td><code>title</code></td>
      <td>String</td>
      <td>The topic's title.</td>
    </tr>
    <tr>
      <td><code>post_count</code></td>
      <td>Integer</td>
      <td>The amount of posts in the topic.</td>
    </tr>
    <tr>
      <td><code>view_count</code></td>
      <td>Integer</td>
      <td>The amount of views the topic has received.</td>
    </tr>
    <tr>
      <td><code>sticky</code></td>
      <td>Boolean</td>
      <td>Whether the topic is sticky.</td>
    </tr>
    <tr>
      <td><code>last_replied_to_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The time, in UTC, when the last reply was made.</td>
    </tr>
    <tr>
      <td><code>locked</code></td>
      <td>Boolean</td>
      <td>Whether the topic is locked.</td>
    </tr>
    <tr>
      <td><code>user_id</code></td>
      <td>Integer</td>
      <td>The ID of the user who made the topic. <code>null</code> if posted anonymously.</td>
    </tr>
    <tr>
      <td><code>author</code></td>
      <td>String</td>
      <td>The name of the user who made the topic.</td>
    </tr>
  </tbody>
</table>

<h2>Post Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>author</code></td>
      <td>String</td>
      <td>The post's author.</td>
    </tr>
    <tr>
      <td><code>avatar</code></td>
      <td>String</td>
      <td>The URL of the author's avatar. May be a link to the CDN path, or a <code>data:</code> URI.</td>
    </tr>
    <tr>
      <td><code>body</code></td>
      <td>String</td>
      <td>The post text.</td>
    </tr>
    <tr>
      <td><code>created_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The creation time, in UTC, of the post.</td>
    </tr>
    <tr>
      <td><code>edit_reason</code></td>
      <td>String</td>
      <td>The edit reason for this post.</td>
    </tr>
    <tr>
      <td><code>edited_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The time, in UTC, this post was last edited at, or <code>null</code> if it was not edited.</td>
    </tr>
    <tr>
      <td><code>id</code></td>
      <td>Integer</td>
      <td>The post's ID (used to identify it).</td>
    </tr>
    <tr>
      <td><code>updated_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The time, in UTC, the post was last updated at.</td>
    </tr>
    <tr>
      <td><code>user_id</code></td>
      <td>Integer</td>
      <td>The ID of the user the post belongs to, if any.</td>
    </tr>
  </tbody>
</table>

<h2>Tag Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>aliased_tag</code></td>
      <td>String</td>
      <td>The slug of the tag this tag is aliased to, if any.</td>
    </tr>
    <tr>
      <td><code>aliases</code></td>
      <td>Array</td>
      <td>The slugs of the tags aliased to this tag.</td>
    </tr>
    <tr>
      <td><code>category</code></td>
      <td>String</td>
      <td>The category class of this tag. One of <code>"character", "content-fanmade", "content-official", "error", "oc", "origin", "rating", "species", "spoiler"</code>.</td>
    </tr>
    <tr>
      <td><code>description</code></td>
      <td>String</td>
      <td>The long description for the tag.</td>
    </tr>
    <tr>
      <td><code>dnp_entries</code></td>
      <td>Array</td>
      <td>An array of objects containing DNP entries claimed on the tag.</td>
    </tr>
    <tr>
      <td><code>id</code></td>
      <td>Integer</td>
      <td>The tag's ID.</td>
    </tr>
    <tr>
      <td><code>images</code></td>
      <td>Integer</td>
      <td>The image count of the tag.</td>
    </tr>
    <tr>
      <td><code>implied_by_tags</code></td>
      <td>Array</td>
      <td>The slugs of the tags this tag is implied by.</td>
    </tr>
    <tr>
      <td><code>implied_tags</code></td>
      <td>Array</td>
      <td>The slugs of the tags this tag implies.</td>
    </tr>
    <tr>
      <td><code>name</code></td>
      <td>String</td>
      <td>The name of the tag.</td>
    </tr>
    <tr>
      <td><code>name_in_namespace</code></td>
      <td>String</td>
      <td>The name of the tag in its namespace.</td>
    </tr>
    <tr>
      <td><code>namespace</code></td>
      <td>String</td>
      <td>The namespace of the tag.</td>
    </tr>
    <tr>
      <td><code>short_description</code></td>
      <td>String</td>
      <td>The short description for the tag.</td>
    </tr>
    <tr>
      <td><code>slug</code></td>
      <td>String</td>
      <td>The slug for the tag.</td>
    </tr>
    <tr>
      <td><code>spoiler_image_uri</code></td>
      <td>String</td>
      <td>The spoiler image for the tag.</td>
    </tr>
  </tbody>
</table>

<h2>User Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>id</code></td>
      <td>Integer</td>
      <td>The ID of the user.</td>
    </tr>
    <tr>
      <td><code>name</code></td>
      <td>String</td>
      <td>The name of the user.</td>
    </tr>
    <tr>
      <td><code>slug</code></td>
      <td>String</td>
      <td>The slug of the user.</td>
    </tr>
    <tr>
      <td><code>role</code></td>
      <td>String</td>
      <td>The role of the user.</td>
    </tr>
    <tr>
      <td><code>description</code></td>
      <td>String</td>
      <td>The description (bio) of the user.</td>
    </tr>
    <tr>
      <td><code>avatar_url</code></td>
      <td>String</td>
      <td>The URL of the user's thumbnail. <code>null</code> if the avatar is not set.</td>
    </tr>
    <tr>
      <td><code>created_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The creation time, in UTC, of the user.</td>
    </tr>
    <tr>
      <td><code>comments_count</code></td>
      <td>Integer</td>
      <td>The comment count of the user.</td>
    </tr>
    <tr>
      <td><code>uploads_count</code></td>
      <td>Integer</td>
      <td>The upload count of the user.</td>
    </tr>
    <tr>
      <td><code>posts_count</code></td>
      <td>Integer</td>
      <td>The forum posts count of the user.</td>
    </tr>
    <tr>
      <td><code>topics_count</code></td>
      <td>Integer</td>
      <td>The forum topics count of the user.</td>
    </tr>
    <tr>
      <td><code>links</code></td>
      <td>Object</td>
      <td>The links the user has registered. See <a href="#links-response">links-response</a>.</td>
    </tr>
    <tr>
      <td><code>awards</code></td>
      <td>Object</td>
      <td>The awards/badges of the user. See <a href="#awards-response">awards-response</a>.</td>
    </tr>
  </tbody>
</table>

<h2>Filter Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>id</code></td>
      <td>Integer</td>
      <td>The id of the filter.</td>
    </tr>
    <tr>
      <td><code>name</code></td>
      <td>String</td>
      <td>The name of the filter.</td>
    </tr>
    <tr>
      <td><code>description</code></td>
      <td>String</td>
      <td>The description of the filter.</td>
    </tr>
    <tr>
      <td><code>user_id</code></td>
      <td>Integer</td>
      <td>The id of the user the filter belongs to. <code>null</code> if it isn't assigned to a user (usually <code>system</code> filters only).</td>
    </tr>
    <tr>
      <td><code>user_count</code></td>
      <td>Integer</td>
      <td>The amount of users employing this filter.</td>
    </tr>
    <tr>
      <td><code>system</code></td>
      <td>Boolean</td>
      <td>If <code>true</code>, is a system filter. System filters are usable by anyone and don't have a <code>user_id</code> set.</td>
    </tr>
    <tr>
      <td><code>public</code></td>
      <td>Boolean</td>
      <td>If <code>true</code>, is a public filter. Public filters are usable by anyone.</td>
    </tr>
    <tr>
      <td><code>spoilered_tag_ids</code></td>
      <td>Array</td>
      <td>A list of tag IDs (as integers) that this filter will spoil.</td>
    </tr>
    <tr>
      <td><code>spoilered_complex</code></td>
      <td>String</td>
      <td>The complex spoiled filter.</td>
    </tr>
    <tr>
      <td><code>hidden_tag_ids</code></td>
      <td>Array</td>
      <td>A list of tag IDs (as integers) that this filter will hide.</td>
    </tr>
    <tr>
      <td><code>hidden_complex</code></td>
      <td>String</td>
      <td>The complex hidden filter.</td>
    </tr>
  </tbody>
</table>

<h2>Links Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>user_id</code></td>
      <td>Integer</td>
      <td>The ID of the user who owns this link.</td>
    </tr>
    <tr>
      <td><code>created_at</code></td>
      <td>RFC3339 datetime</td>
      <td>The creation time, in UTC, of this link.</td>
    </tr>
    <tr>
      <td><code>state</code></td>
      <td>String</td>
      <td>The state of this link.</td>
    </tr>
    <tr>
      <td><code>tag_id</code></td>
      <td>Integer</td>
      <td>The ID of an associated tag for this link. <code>null</code> if no tag linked.</td>
    </tr>
  </tbody>
</table>

<h2>Awards Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>image_url</code></td>
      <td>String</td>
      <td>The URL of this award.</td>
    </tr>
    <tr>
      <td><code>title</code></td>
      <td>String</td>
      <td>The title of this award.</td>
    </tr>
    <tr>
      <td><code>id</code></td>
      <td>Integer</td>
      <td>The ID of the badge this award is derived from.</td>
    </tr>
    <tr>
      <td><code>label</code></td>
      <td>String</td>
      <td>The label of this award.</td>
    </tr>
    <tr>
      <td><code>awarded_on</code></td>
      <td>RFC3339 datetime</td>
      <td>The time, in UTC, when this award was given.</td>
    </tr>
  </tbody>
</table>

<h2>Gallery Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>description</code></td>
      <td>String</td>
      <td>The gallery's description.</td>
    </tr>
    <tr>
      <td><code>id</code></td>
      <td>Integer</td>
      <td>The gallery's ID.</td>
    </tr>
    <tr>
      <td><code>spoiler_warning</code></td>
      <td>String</td>
      <td>The gallery's spoiler warning.</td>
    </tr>
    <tr>
      <td><code>thumbnail_id</code></td>
      <td>Integer</td>
      <td>The ID of the cover image for the gallery.</td>
    </tr>
    <tr>
      <td><code>title</code></td>
      <td>String</td>
      <td>The gallery's title.</td>
    </tr>
    <tr>
      <td><code>user</code></td>
      <td>String</td>
      <td>The name of the gallery's creator.</td>
    </tr>
    <tr>
      <td><code>user_id</code></td>
      <td>Integer</td>
      <td>The ID of the gallery's creator.</td>
    </tr>
  </tbody>
</table>

<h2>Image Errors Responses</h2>

<p>Each field is optional and is an <code>Array</code> of <code>String</code>s.</p>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>image</code></td>
      <td>Array</td>
      <td>Errors in the submitted image</td>
    </tr>
    <tr>
      <td><code>image_aspect_ratio</code></td>
      <td>Array</td>
      <td>Errors in the submitted image</td>
    </tr>
    <tr>
      <td><code>image_format</code></td>
      <td>Array</td>
      <td>When an image is unsupported (ex. WEBP)</td>
    </tr>
    <tr>
      <td><code>image_height</code></td>
      <td>Array</td>
      <td>Errors in the submitted image</td>
    </tr>
    <tr>
      <td><code>image_width</code></td>
      <td>Array</td>
      <td>Errors in the submitted image</td>
    </tr>
    <tr>
      <td><code>image_size</code></td>
      <td>Array</td>
      <td>Usually if an image that is too large is uploaded.</td>
    </tr>
    <tr>
      <td><code>image_is_animated</code></td>
      <td>Array</td>
      <td>Errors in the submitted image</td>
    </tr>
    <tr>
      <td><code>image_mime_type</code></td>
      <td>Array</td>
      <td>Errors in the submitted image</td>
    </tr>
    <tr>
      <td><code>image_orig_sha512_hash</code></td>
      <td>Array</td>
      <td>Errors in the submitted image. If <em>has already been taken</em> is present, means the image already exists in the database.</td>
    </tr>
    <tr>
      <td><code>image_sha512_hash</code></td>
      <td>Array</td>
      <td>Errors in the submitted image</td>
    </tr>
    <tr>
      <td><code>tag_input</code></td>
      <td>Array</td>
      <td>Errors with the tag metadata.</td>
    </tr>
    <tr>
      <td><code>uploaded_image</code></td>
      <td>Array</td>
      <td>Errors in the submitted image</td>
    </tr>
  </tbody>
</table>

<h2>Oembed Responses</h2>

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Type</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>author_name</code></td>
      <td>String</td>
      <td>The comma-delimited names of the image authors.</td>
    </tr>
    <tr>
      <td><code>author_url</code></td>
      <td>String</td>
      <td>The source URL of the image.</td>
    </tr>
    <tr>
      <td><code>cache_age</code></td>
      <td>Integer</td>
      <td>Always <code>7200</code>.</td>
    </tr>
    <tr>
      <td><code>derpibooru_comments</code></td>
      <td>Integer</td>
      <td>The number of comments made on the image.</td>
    </tr>
    <tr>
      <td><code>derpibooru_id</code></td>
      <td>Integer</td>
      <td>The image's ID.</td>
    </tr>
    <tr>
      <td><code>derpibooru_score</code></td>
      <td>Integer</td>
      <td>The image's number of upvotes minus the image's number of downvotes.</td>
    </tr>
    <tr>
      <td><code>derpibooru_tags</code></td>
      <td>Array</td>
      <td>The names of the image's tags.</td>
    </tr>
    <tr>
      <td><code>provider_name</code></td>
      <td>String</td>
      <td>Always <code>"Derpibooru"</code>.</td>
    </tr>
    <tr>
      <td><code>provider_url</code></td>
      <td>String</td>
      <td>Always <code>"https://derpibooru.org"</code>.</td>
    </tr>
    <tr>
      <td><code>title</code></td>
      <td>String</td>
      <td>The image's ID and associated tags, as would be given on the title of the image page.</td>
    </tr>
    <tr>
      <td><code>type</code></td>
      <td>String</td>
      <td>Always <code>"photo"</code>.</td>
    </tr>
    <tr>
      <td><code>version</code></td>
      <td>String</td>
      <td>Always <code>"1.0"</code>.</td>
    </tr>
  </tbody>
</table>
