# X Feed

A native client for the logged-in X (x.com) timeline: For you, Following, Bookmarks,
Search, profiles and threads, with in-app video/GIF playback and media sharing. It is the
app counterpart of the `chrome-declutter` extension's X module: what the extension hides
on x.com never reaches this UI at all.

| Extension feature | Here |
|---|---|
| Hide promoted posts | `promoted-*` entries and items with `promotedMetadata` are dropped by `XTimelineParser` |
| Hide Premium upsell, Grok, Who to follow, trends | Not tweets, so the parser skips those modules (`_skippedEntryPrefixes`) |
| Real URLs for t.co | Text shows the `display_url`, taps open `expanded_url`; no t.co request |
| Never autoplay | Nothing plays until it is opened |
| Video buttons (copy link, download mp4) | Post menu and player: share, save, copy video link |
| Copy image | Post menu and photo viewer: image bytes go to the clipboard |
| Keyboard: arrows, Space, F | Left/right (keyboard) or up/down step post to post; Down enters a post's media, Space or Play opens it, OK opens the thread, long OK opens the menu; letter keys below |

## How it talks to X

There is no official API in use. The tool calls the same private GraphQL API x.com's web
app uses (`x.com/i/api/graphql/<queryId>/<Operation>`), authenticated with the browser
session cookies `auth_token` and `ct0`, plus the web app's public bearer token.

X changes three things without notice; all of them are read from x.com at runtime
(`XWebConfig`), cached for a few hours in the tool's settings, and refetched once when a
request is rejected (400/404/422):

- **Query ids** — scanned from the `main.*.js` bundle, then from lazy webpack chunks
  until every operation in `XWebConfig.requiredOperations` is found. The home and
  bookmark timelines live in such chunks; their URLs come from the webpack runtime's
  name and hash maps in the page (`scriptCandidates`). Only the logged-in page serves
  this client: logged out, x.com ships a different (Relay) bundle the tool cannot use.
- **Feature flags** — each operation's `featureSwitches` list from the same bundle; values
  from the home page's state, unknown ones sent as `true`.
- **`x-client-transaction-id`** — `XTransactionId` rebuilds the web client's signature
  from the home page's verification key, its hidden loading SVG and the `ondemand.s` chunk.
  If that shape changes the header is left out and requests go unsigned.

Each response's `Set-Cookie: ct0=…` replaces the stored CSRF token. A 401/403 marks the
session expired and the shell asks for a new login.

**Settings → Advanced → Refresh API data now** drops the cache.

## Seen posts

X's web app reports which posts were on screen through the `seenTweetIds` variable of its
home timeline requests, and the For you ranking stops serving those again. Without it the
same posts keep coming back after a refresh.

A post counts as seen when at least half of it stays on screen on For you or Following
for a second after scrolling settles (`XTimelineView`), or when it is opened from anywhere
(`XNavigation.openPost`). `XFeedState` buffers the ids and sends the whole buffer with the
next home request — launch, refresh or next page — then clears what was sent; a failed
request keeps them for the next one. Nothing is dropped, and like x.com a request with
seen ids is a POST, so the batch size is not bound by URL length. Unlike x.com, ids already
sent this session (the last 5000) are not sent again, so each batch holds only new ones.
No request is ever made just for seen ids. The buffer is kept in the tool's settings so ids seen right
before the app closes go out on the next launch.

## Translation

Posts whose `lang` is neither `en` nor `de` and that X marks `is_translatable`, or that
came with a translation, get x.com's "Translate post" link under the text, a menu entry and
the T key. The target is **Settings → Translate posts to** (app language, English or
German). `XTranslator` holds the translations, which ones are shown and the fetch queue.

Every request sends the target as `X-Twitter-Client-Language`, the way x.com sends the
reader's language, and X then attaches a Grok translation to some posts
(`grok_translated_post_with_availability`, parsed into `XPost.inlineTranslation`). Those
show at once without a request. X's `is_translatable` misses some of them, so a post that
came with a translation counts as translatable on its own.

For the others, `XApi.translatePost` does what x.com does on demand: it refetches the post
with `TweetResultByRestId` in the target language with
`responsive_web_grok_show_grok_translated_post` on, and falls back to the older strato
column `.../translation/service/translateTweet` (untested so far).

**Settings → Translate automatically** shows translations without asking. Ones X sent
along cost nothing; missing ones are fetched as post cards are built near the viewport,
one request at a time, each post once, and fetching stops for the session after a 429.
"Show original" hides a translation for that post. Everything is dropped when the tool
closes.

## Login

The session never leaves the device except when the user sends it to a TV. It lives in
secure storage (`XSessionStore`); logging out deletes it and the WebView cookies.

1. **In-app login** (`WebLogin`, shared in `lib/widgets/web_login/`) opens
   `x.com/i/flow/login` — an embedded WebView on Android, a native browser window
   (WebView2 / WebKitGTK via `desktop_webview_window`) on Windows and Linux — and polls
   the cookies until `auth_token` and `ct0` exist. Google / Apple sign-in may refuse an
   embedded WebView; username + password works.
2. **Paste session cookies** — copy `auth_token` and `ct0` from any logged-in browser's
   developer tools. Works everywhere.
3. **Log in from your phone** (Android, made for Android TV) — the TV listens on a random
   LAN port and shows a QR code with its addresses, the port and a one-time AES-256 key.
   The phone (Settings → Send login to a TV) scans it and POSTs the session AES-GCM
   encrypted. A request that fails the MAC check is rejected, so only the TV showing the
   code accepts it. The listener closes with the dialog.

## Playback and media

`VideoPlayerPage` (shared, `lib/widgets/video_player/`) plays the best mp4 variant:
ExoPlayer via `video_player` on Android, libmpv via `media_kit` on Windows and Linux.
Android renders into a platform `SurfaceView`, not a texture: on some Android TV decoders
the texture path draws the video shrunk into a corner instead of filling the frame.
Playback streams the URL and starts while it buffers; only share and save download the
whole file. GIFs are mp4s and loop. The controls stay hidden until the user taps, moves
the mouse or presses a key, and come up by themselves only at the end or on an error.
Keyboard and remote: Space (and OK while the controls are hidden)
toggles, left/right seek 5 s while playing or while the controls are hidden, Esc or Backspace closes,
any other key shows the controls. The photo viewer also closes on Esc.

Share and save stream the file into the tool's `TempFileScope` first, then use
`FileSaveHelper.showShareChooser` / `saveFileFromPath`.

## Keyboard and TV

- Each post is a focus stop on every platform; its inner controls are excluded from
  traversal, except the media, and stay clickable. OK opens the thread, holding OK or the
  menu key opens `XPostMenu` with every action, Space opens the post's video (or first
  photo), and Down moves into the post's media. The first post takes focus.
- Each media tile is its own focus stop: arrows move between tiles, OK plays the video
  or opens the photo, and Up on the top row returns to the post.
- Moving Down to a later post aligns its top with the feed viewport when possible.
  Moving Up keeps the normal scrolling behavior for reading tall posts.
- Without TV mode, left/right jump to the previous / next post and scroll it to the top.
  In TV mode they stay with the rail and the media tiles.
- Shift+Down / Shift+Up scroll the feed smoothly by a fifth of the viewport without
  moving the focus, for reading long posts; holding the keys keeps scrolling.
- Letter keys (`XKeys`, ignored with Ctrl / Alt / Meta held or while typing):

  | Where | Key | Action |
  |---|---|---|
  | List | J / K | Next / previous post (also in TV mode) |
  | List | Home | First post |
  | List | R | Reload, like pull-to-refresh |
  | Post | L / B | Like / bookmark |
  | Post | U | Author's profile |
  | Post | T | Translate / show original |
  | Feed | 1 – 4 | For you, Following, Bookmarks, Search; focus returns to where it was |
  | Feed | / | Search field |
  | Thread, profile, search page, photo viewer, player | Backspace | Back |
  | Player | K / J / L / M | Play-pause / back 10 s / forward 10 s / mute |

  `XBackKey` wraps each pushed page in its own focus scope, so Backspace arrives even
  before anything inside has taken the focus.
- **Settings → Post text size** scales all text inside posts on top of the system text
  scale; stored in the tool's settings.
- The rail sits beside the feed whenever there is room, so it is reachable with left.
- Without a browser, links fail with a message instead of opening.

## Platforms

- Android, Android TV, Windows: full support.
- Linux: needs `libwebkit2gtk-4.1` + `libsoup-3.0` (build) and `libmpv` (runtime).
- Android runs the tool in its own process (`:x_feed`); `MainActivity` gives every
  non-main process its own WebView data directory, which Android requires.
