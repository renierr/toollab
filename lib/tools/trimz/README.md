# Trimz

Browses the trimz.tv catalog of AI-made series and plays them in the shared
`VideoPlayerPage`, one series as one playlist.

## API

trimz.tv has no documented API. The tool calls the same public JSON endpoints
the web app does, found in its Next.js bundles (search a bundle for
`api.trimz.tv/api`; the client prefixes every path with `/ms`). No login,
cookies or tokens are needed, and the video URLs are not signed.

Base: `https://api.trimz.tv/api/ms`

| Endpoint | Use |
| :--- | :--- |
| `GET /explore-feed?locale=&genre=&client_layouts=` | Home sections (`hero`, `trending`, `latest`, …) or, with `genre`, that genre's sections |
| `GET /explore-feed/paginate?section_id=&offset=&limit=&genre=&client_layouts=` | Next page of a section with `hasMore` |
| `GET /explore-genres?locale=` | Genre chips |
| `GET /search?q=&limit=&offset=&locale=&client_layouts=` | Search |
| `GET /series/by-slug/<slug>?locale=` | A series with every episode in `videos` |

- `client_layouts` lists the section layouts the client can draw. Without it
  the feed leaves out grid and genre sections and ignores `genre`. The value is
  `TrimzApi._layouts`, copied from the web app's `m()` helper.
- `locale` translates section titles and, where trimz has them,
  `localized_title` / `localizedTitle`.
- Feed items use snake_case (`project_id`, `poster_16_9_url`, `episode_count`);
  the series endpoint uses camelCase (`projectId`, `videos[].muxPlaybackUrl`).
- Each episode carries an MP4 (`url`, on `cdn.trimz.co`, full quality and large)
  and an adaptive Mux HLS stream (`muxPlaybackUrl`). The "Adaptive streaming"
  setting picks between them. An episode with neither is skipped, which is
  what a paywalled episode looks like.

When trimz changes its API, compare against the live web app's network calls
first; the parsing lives in `models/` and `trimz_api.dart`.

## Stored data

One table, `series` (tool database), holds every series the viewer watched or
put on their list: the episode they are in, the position inside it, and
`watched_at` / `saved_at`. A row with neither is soft-deleted (`deleted = 1`).
`TrimzPlayback` is the player's `VideoResumeStore`, so playback writes go
straight into that row and "continue" resumes there.

Watched is not stored per episode: everything before `episode_index` counts as
watched, plus that episode once played to its end. Marking an episode watched
therefore finishes it (and every earlier one), unmarking it moves the position to
its start (unmarking every later one).

## Sync

`TrimzSyncDelegate` syncs the `series` table with the backend, one record per
series keyed by the trimz project id, so every device shares the history, the
list and where to continue.

- Every write bumps `updated_at` above its previous value; the newer row wins
  as a whole (last writer wins, no field merge).
- A deletion stays as a tombstone until it was pushed, or until a server
  tombstone at least as new removes the row.
- The page syncs on open and after changes: about 2 s after a list or history
  action, and at most every 30 s while progress is being saved during playback.
  Closing the tool runs a sync that was still waiting.
- Rows written by sync fire `TrimzDbHelper.remoteChanges`, which reloads the
  open tool's history and list.
