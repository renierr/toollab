# Weather (Wetter)

Weather for saved places, built only on open data from the German Weather
Service (DWD). It covers current conditions, hourly and 10-day forecasts,
official and short-term warnings, an animated rain radar with nowcast, a home
screen widget in three sizes and warning notifications. It targets Android,
Windows and Linux; the widget, notifications and background refresh are
Android only.

This file is the reference for the tool. Keep it current when you change a
source, a mapping, a schema, a default or a native contract (see `AGENTS.md`,
*Keep Tool Reference Docs Current*).

## Features

- **Places:** free search via Nominatim (on submit only), the device location
  (GPS, refreshed on use), rename, reorder by drag (icon at once, long press
  anywhere on the row) or Move up/down in the menu, undo on delete. Search
  results and the hero show the coordinates, linked to OpenStreetMap, to tell
  same-named places apart. A **default place** moves to the top of the list,
  opens first and drives the widget fallback, background
  refresh and notifications. Per place the forecast and measurement stations
  can be pinned; otherwise the nearest suitable ones are chosen.
- **Overview:** hero with the current temperature (measured when the station
  reading is at most 150 min old, else the forecast hour), condition, feels
  like, today's high/low. Warning banner, next 48 hours strip, rain radar
  preview, 10-day list with a day sheet, detail tiles (wind with compass,
  gusts, humidity, dew point, pressure and trend, clouds, visibility,
  sunshine, sun arc, moon phase), trend charts with a hover/touch tooltip that
  hides itself after 3 s (touch) or 6 s (mouse), and a source footer.
- **Warnings:** official DWD warnings per station plus automatic short-term
  nowcast warnings (thunderstorms, heavy rain) for places inside the warned
  polygon. Merged, de-duplicated and sorted by severity. Nowcast items are
  marked "Short-term warning".
- **Rain radar:** observed frames for the last 2 hours and about 2 hours of
  nowcast in 5-minute steps, a timeline slider with play/pause and speed,
  rain outlook for the place ("rain in about 20 min"), map layers (light,
  dark, satellite base; lightning; warning areas), legend, subtle city
  labels, pan and zoom. The place sits in the upper third of the full view
  (42 % in the preview) so the time slider card does not hide it; it stays
  there on resize until the user pans or zooms, and every newly shown view
  starts there again. Full screen on narrow layouts; on desktop at least
  1280 px wide a hideable side panel or a preview card.
- **History:** every network load records hourly values per place
  (measured first, forecast only for gaps). A history page shows a day, week,
  month or year with charts, key figures (extremes with time, mean,
  precipitation and rain days, sunshine, strongest gust, warmest/coldest/
  wettest day), coverage and a comparison with the same period a year
  earlier. The overview shows the last 7 days.
- **Offline first:** the last saved weather shows instantly and the network
  refresh follows; every download is cached in the tool database.
- **Settings page:** default place, units (°C/°F, km/h, m/s, kn, Bft, mph,
  hPa/mmHg/inHg, mm/in), animated icons, refresh interval while open,
  background refresh (interval, places, night pause, Wi-Fi only, pause on low
  battery), warning levels for notifications and for display, widget extra
  details, radar defaults, clear saved data.
- **Android:** home screen widget (current / plus hours / plus days, place
  picker), warning notifications, own process, own launcher icon and pinned
  shortcut.
- Times always use the 24-hour clock; texts are localized (en, de).

## Architecture

```
config.dart                  ToolModel: id 'weather', route /weather, providers,
                             onClose releases both states, background task,
                             androidProcessIsolated: true
weather_page.dart            Thin coordinator. One LayoutBuilder decides: split
                             (sidebar 300 + forecast [+ radar panel 460 at
                             >= 1280 px]) or narrow (drawer + pager). Reads the
                             ?place=<id> query a widget or notification opens with.
weather_radar_page.dart      Full-screen radar for narrow layouts.
weather_history_page.dart    History: period picker, navigation, charts,
                             key figures, previous-year comparison.
weather_history_store.dart   Read access to recorded hours; widget tests swap
                             in memory because DB I/O never completes in fake time.
weather_state.dart           ChangeNotifier: places, snapshots, selection,
                             search, settings, debounced publish to Android.
weather_radar_state.dart     ChangeNotifier: radar timeline, blocks, frame
                             loading, playback, rain sampling.
weather_repository.dart      Loads a WeatherSnapshot with the cache; no provider
                             dependency, so the background run uses it as well.
weather_db_helper.dart       Tool DB: tables `locations`, `cache`, `history`.
weather_settings.dart        Typed settings, persisted per key.
weather_background.dart      BackgroundTask 'weather-refresh'.
weather_publisher.dart       Widget JSON + warning notifications via the bridge.
weather_warning_alerts.dart  Announce-once logic for notifications.
radar_frame_store.dart       Session cache (memory LRU + temp files) and the
                             lasting store (tool DB) for radar images.
weather_units.dart           Unit conversion and value texts.
weather_l10n.dart            Condition labels, directions, moon phases, levels,
                             WeatherTimeFormat (24 h).
weather_colors.dart          Tool palette, sky gradients, warning colours.
api/                         One client per source (see Data sources).
models/                      Typed models; rows never leave the DB helper as maps.
widgets/                     One file per visual component.
```

State flow: `WeatherState.ensureLoaded()` loads catalog, settings and places;
then `_refreshInOrder` refreshes the selected place first and the others one by
one. `refresh(id)` first puts a cache-only snapshot on screen when none is in
memory, then loads from the network; concurrent calls for a place join.

## Data sources

All network access goes through `api/weather_http.dart` (`WeatherHttp.getBytes`,
errors as `WeatherException(WeatherError.unreachable|notFound|httpStatus|invalidData)`).

| What | Endpoint | Format / notes |
|---|---|---|
| Forecast | `opendata.dwd.de/weather/local_forecasts/mos/MOSMIX_L/single_stations/<id>/kml/MOSMIX_L_LATEST_<id>.kmz` | ZIP with one KML, ISO-8859-1, 247 hourly steps (~10 days). Units: temperature K, pressure Pa, wind m/s, precipitation kg/m², `ww` present-weather code. `api/mosmix_client.dart` |
| Live measurements | `opendata.dwd.de/weather/weather_reports/poi/<id>-BEOB.csv` | `;` separated, decimal comma, `---` = missing. Row 1 English keys, rows 2–3 units and German labels. Last ~24 h. `api/observation_client.dart` |
| Days + station warnings | `app-prod-ws.warnwetter.de/v30/stationOverviewExtended?stationIds=a,b,c` | JSON per station: `days` (sun/moon, icon) and `warnings`. Knows only part of the stations, so the nearest others are asked along and the first present wins. Unofficial backend of the WarnWetter app, no SLA. `api/warnwetter_client.dart` |
| Short-term warnings | `s3.eu-central-1.amazonaws.com/app-prod-static.warnwetter.de/v16/warnings_nowcast.json` | Gzip-compressed JSON **without** a Content-Encoding header. `warnings[].regions[].polygon` is a flat lat,lon list. Ids change with every model run. `api/nowcast_client.dart`, `models/area_warning.dart` (ray casting) |
| Rain radar | WMS `maps.dwd.de/geoserver/dwd/wms`, layer `dwd:Niederschlagsradar`, EPSG:3857 | `time` dimension in 5-min steps; capabilities from `.../dwd/Niederschlagsradar/wms`. Rendered on demand, 1–30 s per image. Overlays as PNG8 (transparent, exact legend colours), satellite base `dwd:bluemarble` as JPEG, borders `dwd:Laender` style `Laender_grau` + `dwd:Gewaesser`, `dwd:Blitzdichte`, `dwd:Warnungen_Landkreise`. `api/dwd_radar.dart` |
| Place search | `nominatim.openstreetmap.org/search` | Only on submit, at most one request per second, User-Agent `ToolLab-Weather/1.0`, countries de,at,ch,nl,be,lu,fr,dk,pl,cz. `api/geocoding_client.dart` |
| Station catalog | `assets/weather/stations.json` | 3,632 stations `[id, name, lat, lon, elevation, hasObservations]`, built from the MOSMIX catalog (coordinates converted from degrees.minutes) by a one-off script. `api/station_catalog.dart` |

### Station choice

`StationCatalog.nearest` ranks by distance plus 1 km per 50 m of height
difference; without a place elevation the median of the 5 nearest stations is
used. This keeps mountain stations (e.g. Kleiner Feldberg, 825 m) from winning
for a valley town. Forecasts try 3 candidates within 100 km; measurements try
3 stations with observations within 60 km and take the first whose latest
reading is at most 150 min old.

### Conditions

`models/weather_condition.dart` has 21 conditions. Mapping: `fromWw` for the
MOSMIX/BEOB `ww` code, `fromCloudCover` when no significant weather is
reported, `fromDwdCode` for WarnWetter day icons. Widget icons use the key
`<snake_case_name>_<d|n>` (`WeatherPublisher.iconKey`).

## Cache and freshness

Table `cache(key TEXT PRIMARY KEY, body BLOB, fetched_at INTEGER)` stores raw
payloads. Keys and maximum age before a normal load refetches:

| Key | Max age |
|---|---|
| `mosmix:<id>` | 60 min |
| `obs:<id>` | 10 min |
| `overview:<id,id,...>` | 15 min |
| `nowcast` | 5 min |
| `radar:base:<layer>:<block>` | kept (static), pruned after 30 days |

Modes: `normal` (fresh cache wins), `force` (network first), `cacheOnly`
(any age, no network). A failed network load falls back to the cache and marks
the snapshot stale; a 404 does not, so a vanished station hands over to the
next candidate.

## History

Table `history` (schema version 2), one row per place and UTC hour,
`PRIMARY KEY (location_id, hour)`, `WITHOUT ROWID`, about 80 bytes per row
(~0.7 MB per place and year): `hour` (epoch seconds), `source` (0 measured,
1 forecast), `temperature`, `dew_point`, `pressure`, `wind_speed`,
`wind_gust`, `wind_direction`, `precipitation`, `cloud_cover`, `sunshine`
(minutes), `condition` (`WeatherCondition.name`).

- **Recording:** `WeatherRepository.load` (not cache-only) writes
  `WeatherHistoryEntry.fromSnapshot`: station readings at full hours as
  measured (`INSERT OR REPLACE`), past forecast hours as forecast
  (`INSERT OR IGNORE`, so they never overwrite a measurement). No UPSERT
  syntax: the system SQLite on older Android lacks it.
- **Pruning:** `pruneHistory(settings.historyCutoff(now))` on tool start and in
  every background run; it also drops hours of deleted places. Deleting a
  place keeps its rows until then, and undo restores the place under its old
  id, so its history comes back.
- **Aggregation:** `models/weather_history_summary.dart`. `HistoryRange` is a
  local calendar period (weeks start Monday); `HistorySummary` buckets by day
  (week, month) or month (year). Rain day = at least 1 mm. The comparison
  shows only when both periods are at least 50 % recorded.

## Rain radar design

- **Blocks:** the radar loads square 1280 px images snapped to a grid at 600,
  1200 or 2400 m/px. The view must fit within 85 % of the block; a block is
  kept while the view still fits, so panning rarely reloads. Zoom is capped at
  220 m/px because the radar grid is 1 km.
- **Loading order:** current frame, then quarter hours, then the rest, nearest
  to now first; 6 parallel requests, 60 s timeout, 2 retries. Responses are
  checked for a PNG/JPEG signature; XML error documents are never cached and
  frames the server cannot render are tracked as missing.
- **Preview vs. full:** `attach(full: false)` (overview card) loads only the
  current frame; the full view loads all frames. Frames from index −2 to +5
  stay decoded.
- **Caching:** session store (24 MB memory LRU + session temp files via
  `TempFileScope`); the base map in the tool DB. The timeline survives
  closing the tool, so reopening within 5 min costs no request.
- **Playback:** 250 ms per frame at 1× (0.5×, 2× selectable). A tick waits
  up to four intervals for the next frame to decode instead of drawing a
  neighbour, and while playing the decode window wraps to the first frames so
  the loop restarts without a gap.
- **Freshness:** while a view is shown the timeline is checked every minute
  and refetched when 5 min old, also on app resume; lightning and warnings
  reload with it. A timeline older than 15 min is dropped and the views show
  loading, and a frame that failed shows nothing rather than an older one.
  Radar frames are never kept across app starts.
- **Viewports:** each map registers with `addView`; only the newest one
  resizes the shared viewport, so the preview under a full-screen route
  cannot move it. A newly shown view, or the one revealed again, recentres on
  the place at the default zoom.
- **Rain at the place:** each frame is sampled at the focus pixel and mapped
  through `RadarPalette.classes` (15 legend colours → mm/h). `RainOutlook`
  turns the series into raining now / stops in / starts in / dry.

## Warnings and notifications

`WeatherSnapshot.warnings(now)` merges station and nowcast warnings, drops
ended ones, de-duplicates by id and sorts by level, then start.

`WeatherWarningAlerts.takeNew(warnings, minLevel, now)` returns what is worth
a notification and remembers it (setting `announced_warnings`). A warning
counts as announced if its id was announced, or one with the same event and an
equal or higher level still overlaps it (nowcast ids change every run). A
higher level is news again. Entries expire at the warning's end. Level 0 turns
notifications off. Only the default place notifies.

Display has its own threshold (`warning_show_level`): the overview banner and
the widget chip show a warning from that level up (level 0 items count as 1);
0 hides them. Both settings are thresholds, so the chips light up the chosen
level and every higher one.

## Settings

Stored with `DatabaseService.setSetting(WeatherTool.config.id, key, value)`:

| Key | Default | Meaning |
|---|---|---|
| `unit_temperature`, `unit_wind`, `unit_pressure`, `unit_precipitation` | celsius, kmh, hPa, mm | Units |
| `default_location` | first place | Default place id |
| `auto_refresh_minutes` | 30 | Refresh while open; 0 = off |
| `warning_notify_level` | 2 | Lowest level that notifies; 0 = off |
| `warning_show_level` | 1 | Lowest level shown in overview and widget; 0 = off |
| `widget_details` | all | Comma list of `WeatherWidgetDetail` names shown on a wide widget |
| `animated_icons` | true | |
| `radar_base_map`, `radar_speed`, `radar_lightning`, `radar_warnings`, `radar_panel` | light, 1.0, false, false, false | Radar defaults |
| `background_scope` | defaultPlace | `defaultPlace` or `allPlaces` |
| `quiet_hours`, `quiet_from`, `quiet_to` | true, 23, 6 | Night pause (local hours, wraps midnight) |
| `background_wifi_only` | false | WorkManager unmetered network |
| `background_battery_not_low` | true | WorkManager battery-not-low |
| `history_months` | 12 | Months of history kept; 0 = forever |
| `announced_warnings` | – | JSON list kept by `WeatherWarningAlerts` |

The background interval itself is stored by `BackgroundTaskService`
(default 1 h, off allowed).

## Background refresh (Android)

`WeatherBackground.task` (`weather-refresh`) runs through
`BackgroundTaskService` on WorkManager with `requiresNetwork` and the
user's constraints (Wi-Fi only, battery not low; changing either reschedules).
A scheduled run skips during the night pause ("Run now" does not,
via `BackgroundTaskService.isManualRun`), refreshes the default place or all places
(only stale requests hit the network), then calls `WeatherPublisher.publish`.
Android decides the exact time and defers runs in Doze.

## Android native side

The tool runs in its own process `:weather` (`WeatherActivity`,
`WeatherAlias`, `ShortcutHelper.isolatedTools`). Native code lives in
`android/app/src/main/kotlin/de/renier/tool_lab/weather/`.

**Why a bridge plugin:** app channels exist only on the activity's engine, so a
headless background run could not reach native code. `packages/tool_lab_bridge`
is a local plugin registered on every engine; it sends package-local broadcasts
and checks/opens notification settings.

Flow: `WeatherPublisher.publish()` (after a refresh in the app, debounced 3 s,
or at the end of a background run) takes the snapshots the caller already
holds and reads only the other places from the cache, writes
`files/weather/widget.json`, broadcasts `REFRESH_WIDGETS`, then broadcasts
`NOTIFY` for each new warning. `WeatherReceiver` (in `:weather`) refreshes the
widgets or posts the notification.

### Contracts

Broadcast actions (constants in `WeatherPublisher` and `WeatherIntents.kt`):

- `de.renier.tool_lab.weather.REFRESH_WIDGETS` — no extras.
- `de.renier.tool_lab.weather.NOTIFY` — `key` (String, notification id
  source), `title`, `body`, `color` (signed 32-bit ARGB int), `placeId` (int).

`files/weather/widget.json` (every text already localized and in the user's
units; written atomically via a `.tmp` rename):

```json
{
  "updatedAt": 1795188912000,
  "defaultId": 3,
  "places": [{
    "id": 3, "name": "Eschborn", "temp": "12°", "condition": "Leicht bewölkt",
    "icon": "partly_cloudy_d", "theme": "day|night|gray|storm",
    "range": "14° / 6°", "updated": "Aktualisiert 14:05",
    "details": ["Gefühlt 10°", "Wind 12 km/h", "Regenrisiko 40 %",
                "Luftfeuchte 82 %", "↑ 07:45  ↓ 16:30"],
    "hours": [{"time": "15:00", "icon": "rain_d", "temp": "11°"}],
    "days": [{"label": "Heute", "icon": "cloudy_d", "high": "14°", "low": "6°"}],
    "warning": {"text": "Sturmböen", "color": 4294945280}
  }]
}
```

### Widget

`WeatherWidgetProvider` is one resizable widget. From its size options it shows
the header only (small), plus 5 hours (from 220×150 dp), plus up to 5 days
(from 220×290 dp); from 300 dp width the `details` lines sit beside the
icon (which ones is the `widget_details` setting), and the warning chip appears from 150 dp height. The chip's level colour
tints a rounded image behind the text, since RemoteViews can only set a flat
background colour. Background gradient by `theme`. Each widget can be bound to a place in
`WeatherWidgetConfigActivity` (SharedPreferences `weather_widget`); unbound
widgets follow the default place. A tap opens `/weather?place=<id>`.

Condition icons are PNGs in `res/drawable-nodpi/weather_icon_<key>.png`,
rendered once from the app's `WeatherIconPainter` so widget and app look
alike. `WeatherIcons.kt` maps each key to its `R.drawable` directly: a lookup
by name (`getIdentifier`) lets release resource shrinking drop the icons, and
the widget then shows the fallback for every condition. Add new keys there. Regenerate them (and the launcher icon) with the scratch renderer in
`.agents/temp/weather/icons_test.dart`, then run
`dart run tool/sync_launcher_icons.dart weather`.

### Notifications

Channel `weather_warnings` (high importance), small icon `ic_stat_weather`,
colour by warning level, tap opens the place. Posting is skipped when the app
may not notify; the settings page then shows a hint with a button to the
system settings.

## Tests

`test/tools/weather/` — tests never touch the network: every client gets a fake
fetch reading `test/fixtures/weather/` (MOSMIX KMZ, BEOB CSV, WarnWetter JSON,
gzipped nowcast, Nominatim, radar capabilities and a radar PNG). Prove it with
`unshare -rn bash -c 'ip link set lo up; flutter test test/tools/weather'`.
Databases use `inMemoryDatabasePath`. Every test file has a one-minute
timeout so a hang fails fast. Widget tests use `MaterialApp.router`
because `ToolBackButton` needs a `GoRouterState`.

- `weather_parsers_test.dart` — every parser against its fixture.
- `station_catalog_test.dart` — ranking and elevation penalty.
- `weather_repository_test.dart` — snapshot assembly, cache modes, fallbacks,
  nowcast polygon match, state actions, alerts, background run, publisher.
- `weather_radar_test.dart` — timeline, palette, outlook, viewport, frame
  loading, preview mode, lasting store.
- `weather_page_test.dart` — layouts on phone/tablet/desktop in de/en without
  overflow; settings page; history page in every period.
- `weather_history_test.dart` — ranges, aggregation, record and prune rules.
- `weather_trend_chart_test.dart` — tooltip behaviour.
- `weather_android_launcher_test.dart` — manifest, process, icons, widget
  drawables for every condition.

## Extending

- **New data field:** parse it in the client, add it to the model, show it in a
  widget under `widgets/`; if the widget needs it, add it to
  `WeatherPublisher.widgetJson`, `WeatherFiles.kt` and the layout, and update
  the JSON above.
- **New condition:** add it to `WeatherCondition`, the mappings, the painter,
  `WeatherConditionL10n` and both ARB files, then re-render the widget icons.
- **New setting:** field, key, `load`/`save`/`copyWith` in
  `weather_settings.dart`, a control on `weather_settings_page.dart`, ARB keys,
  and a row in the settings table above.

## Planned

A final polish pass on devices.
