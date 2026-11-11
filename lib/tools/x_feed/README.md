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
| Keyboard: arrows, Space, F | D-pad moves post to post; Down enters a post's media, OK opens or plays, Play starts the video, long OK opens the menu |

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

A post on For you or Following counts as seen when at least half of it stays on screen
for a second after scrolling settles (`XTimelineView`). `XFeedState` buffers the ids — up
to 100, oldest dropped — and sends the whole batch with the next home request, refresh or
next page. Sent ids are not sent again this session. The pending buffer is kept in the
tool's settings so ids seen right before the app closes go out on the next launch.

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
GIFs are mp4s and loop. Remote: OK/Space toggles, left/right seek 10 s while the controls
are hidden, any other key shows them.

Share and save stream the file into the tool's `TempFileScope` first, then use
`FileSaveHelper.showShareChooser` / `saveFileFromPath`.

## TV

- Each post is a focus stop; its inner controls are excluded from traversal, except the
  media. OK opens the thread, holding OK or the menu key opens `XPostMenu` with every
  action, and Down moves into the post's media.
- Each media tile is its own focus stop: arrows move between tiles, OK plays the video
  or opens the photo, and Up on the top row returns to the post.
- The rail sits beside the feed whenever there is room, so it is reachable with left.
- Without a browser, links fail with a message instead of opening.

## Platforms

- Android, Android TV, Windows: full support.
- Linux: needs `libwebkit2gtk-4.1` + `libsoup-3.0` (build) and `libmpv` (runtime).
- Android runs the tool in its own process (`:x_feed`); `MainActivity` gives every
  non-main process its own WebView data directory, which Android requires.
