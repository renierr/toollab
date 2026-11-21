# Local Weather Station API (version 1)

This document defines the HTTP interface a **local weather station** offers so
the ToolLab Weather tool can show its data as a place. It is written for people
and for AI coding tools that build such a station server outside the app (on a
Raspberry Pi, a NAS, an ESP32 with a web server, a script next to a weather
station console, or plain static files written by a cron job).

The interface is read-only, plain HTTP(S) `GET`, JSON in UTF-8. Every file may
be static; nothing needs to be computed per request.

A working reference implementation with fake data lives next to this file:
[`example_server.dart`](example_server.dart), see
[section 9](#9-reference-server-example_serverdart).

## 1. How the app uses it

1. The user enters a server address in the Weather tool: *Add place → Local
   weather station*, e.g. `http://192.168.1.50:8080` or
   `https://example.org/garden/`.
2. The app requests the **manifest** `weather-station.json` under that address.
   If the entered address itself ends in `.json`, it is used as the manifest
   URL as is.
3. The manifest names the station, its position and the **sections** it
   offers, each with the list of **fields** it delivers.
4. The app saves the station as a place at the manifest's coordinates and from
   then on requests the offered sections whenever it refreshes.
5. Every section the station does **not** offer is filled by the app from the
   German Weather Service (DWD) for the station's coordinates (nearest
   forecast station, measurements, warnings, sun times). A station that only
   measures therefore still gets a 10-day forecast. Fields a section does not
   list are taken from the DWD forecast hour where the app shows them.

Only fields declared in the manifest are read. Unknown keys are ignored, so a
server may send more than it declares.

## 2. Addresses

- Manifest: `<base>/weather-station.json`, where `<base>` is the address the
  user entered (a missing trailing `/` is added).
- Section URLs in the manifest are resolved **relative to the manifest URL**
  (RFC 3986), so `"observations.json"` and `"/api/obs"` and an absolute
  `"http://other-host/obs"` all work.
- `http` and `https` are allowed. There is no authentication in version 1;
  keep the server inside a trusted network or put it behind a reverse proxy.
- Respond with status `200` and a JSON body. `Content-Type: application/json`
  is recommended but not required. Status `404` for a section means "no data".
  Any other error makes the app show the last saved data marked as offline.
- Keep each response below 8 MB.

## 3. Conventions

| Kind | Format |
|---|---|
| Time | ISO 8601 string **with offset**, e.g. `"2026-11-21T14:00:00Z"` or `"2026-11-21T15:00:00+01:00"`. A time without offset is read as the device's local time. |
| Date | `"YYYY-MM-DD"`, the station's local calendar day. |
| Number | JSON number. Missing or unknown values are `null` or left out, never `-999`, `"---"` or `NaN`. |
| Units | Fixed, see the field tables. The app converts to the user's units. |

## 4. Manifest — `weather-station.json`

```json
{
  "api": "toollab.weather-station",
  "version": 1,
  "station": {
    "id": "garden-01",
    "name": "Garden station",
    "latitude": 50.1427,
    "longitude": 8.5713,
    "elevation": 140
  },
  "observations": {
    "url": "observations.json",
    "refreshSeconds": 300,
    "fields": ["temperature", "humidity", "dewPoint", "pressure",
               "windSpeed", "windDirection", "windGust",
               "precipitation1h", "precipitation24h", "condition"]
  },
  "forecast": {
    "url": "forecast.json",
    "refreshSeconds": 3600,
    "fields": ["temperature", "dewPoint", "precipitation",
               "precipitationProbability", "cloudCover", "condition"]
  },
  "warnings": { "url": "warnings.json", "refreshSeconds": 300 },
  "days": {
    "url": "days.json",
    "refreshSeconds": 21600,
    "fields": ["sunrise", "sunset"]
  }
}
```

| Key | Required | Meaning |
|---|---|---|
| `api` | yes | Always `"toollab.weather-station"`. |
| `version` | yes | Integer interface version. This document is `1`. The app refuses a higher version it does not know. |
| `station.id` | yes | Stable id of the station (any string). |
| `station.name` | yes | Display name; becomes the place name (the user can rename it). |
| `station.latitude`, `station.longitude` | yes | WGS 84 decimal degrees. Used for the radar, sun times, nowcast warnings and every DWD fallback. |
| `station.elevation` | no | Metres above sea level. |
| `observations`, `forecast`, `warnings`, `days` | at least `observations` or `forecast` | Sections, see below. Leave a section out when the station does not offer it. |
| `<section>.url` | yes | Where the section is served, relative to the manifest. |
| `<section>.fields` | yes for `observations`, `forecast`, `days` | Field names the section delivers, from the tables below. Unknown names are ignored. |
| `<section>.refreshSeconds` | no | How long the app keeps a response before asking again. Defaults: observations 300, forecast 3600, warnings 300, days 21600. Minimum 60. |

The app re-reads the manifest at most once an hour, so new sections or fields
show up without re-adding the place. Coordinates are taken when the place is
added.

## 5. Sections

### 5.1 `observations` — measured values

```json
{
  "rows": [
    {"time": "2026-11-21T14:05:00+01:00", "temperature": 7.4, "humidity": 86,
     "dewPoint": 5.2, "pressure": 1012.8, "windSpeed": 3.1,
     "windDirection": 240, "windGust": 7.9, "precipitation1h": 0.4,
     "precipitation24h": 3.2, "condition": "lightRain"},
    {"time": "2026-11-21T14:00:00+01:00", "temperature": 7.5, "humidity": 85}
  ]
}
```

`rows` may be in any order; the newest row is "now". Serve the **latest
reading** (any minute) plus one row **at every full hour** for at least the
last 24 hours: the app records full-hour rows (minute 0) into its history and
charts. A reading older than 150 minutes no longer counts as current; the app
then shows the forecast hour instead.

| Field | Unit | Notes |
|---|---|---|
| `time` | ISO 8601 | Required in every row. End of the measuring interval. |
| `temperature` | °C | Air temperature, 2 m. |
| `humidity` | % | Relative humidity 0–100. |
| `dewPoint` | °C | |
| `pressure` | hPa | Reduced to **sea level** (QFF/QNH), not station pressure; the 3 h trend compares it with the forecast. |
| `windSpeed` | m/s | Mean wind (10 min). |
| `windDirection` | ° | Direction the wind comes **from**, 0 = north, 90 = east. |
| `windGust` | m/s | Strongest gust of the last hour. |
| `precipitation1h` | mm | Sum of the last hour. |
| `precipitation24h` | mm | Sum of the last 24 hours. |
| `cloudCover` | % | 0–100. Derives the condition when `condition` is missing. |
| `visibility` | m | |
| `sunshineMinutes` | min | Sunshine within the last hour (0–60). |
| `condition` | text | One of the [condition names](#6-condition-names). |

### 5.2 `forecast` — hourly forecast

```json
{
  "issued": "2026-11-21T12:00:00+01:00",
  "hours": [
    {"time": "2026-11-21T15:00:00+01:00", "temperature": 7.8, "dewPoint": 5.0,
     "precipitation": 0.2, "precipitationProbability": 40,
     "cloudCover": 90, "condition": "lightRain"}
  ]
}
```

One entry per hour, ascending, ideally from the current hour up to 10 days
ahead. The app builds the daily list (high, low, rain sum, condition) from
these hours; a day needs at least 6 hours to be shown. `issued` is optional.

| Field | Unit | Notes |
|---|---|---|
| `time` | ISO 8601 | Required. End of the forecast hour. |
| `temperature` | °C | |
| `dewPoint` | °C | Humidity is derived from temperature and dew point. |
| `pressure` | hPa | Sea level. |
| `windSpeed` | m/s | |
| `windDirection` | ° | From, 0 = north. |
| `windGust` | m/s | |
| `cloudCover` | % | |
| `precipitation` | mm | Sum within the hour. |
| `precipitationProbability` | % | Chance of precipitation in the hour. |
| `sunshineMinutes` | min | Within the hour. |
| `visibility` | m | |
| `condition` | text | [Condition name](#6-condition-names); without it the app derives one from `cloudCover`. |

### 5.3 `warnings` — weather warnings

```json
{
  "warnings": [
    {"id": "garden-frost-2026-11-22", "level": 2,
     "start": "2026-11-21T22:00:00+01:00", "end": "2026-11-22T09:00:00+01:00",
     "event": "Frost", "headline": "Frost expected tonight",
     "description": "Temperatures down to -4 °C near the ground.",
     "instruction": "Protect sensitive plants."}
  ]
}
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | Stable while the warning lasts; the app announces each id once. |
| `level` | yes | 1 notice, 2 moderate, 3 severe, 4 extreme (DWD scale). |
| `start` | yes | ISO 8601. |
| `end` | no | ISO 8601; ended warnings are hidden. |
| `event` | yes | Short name ("Frost", "Gale"). |
| `headline`, `description`, `instruction` | no | Plain text. |

An empty list means "no warnings". DWD short-term (nowcast) warnings for the
station's coordinates are always added by the app.

### 5.4 `days` — sunrise and sunset

```json
{
  "days": [
    {"date": "2026-11-21", "sunrise": "2026-11-21T07:45:00+01:00",
     "sunset": "2026-11-21T16:35:00+01:00"}
  ]
}
```

| Field | Notes |
|---|---|
| `date` | Required, `YYYY-MM-DD`. |
| `sunrise`, `sunset` | ISO 8601. Without them the app computes sun times itself. They decide day or night icons and the sun arc. |

The moon phase is always computed by the app.

## 6. Condition names

`clear`, `mostlyClear`, `partlyCloudy`, `cloudy`, `overcast`, `fog`,
`drizzle`, `freezingDrizzle`, `lightRain`, `rain`, `heavyRain`,
`freezingRain`, `sleet`, `lightSnow`, `snow`, `heavySnow`, `hail`,
`rainShower`, `sleetShower`, `snowShower`, `thunderstorm`.

An unknown name is treated as missing. Day and night variants of the icons are
chosen by the app from the sun times.

## 7. Checklist for an implementation

- [ ] `GET <base>/weather-station.json` returns the manifest with `api`,
      `version: 1`, `station` with coordinates and at least one of
      `observations` / `forecast`.
- [ ] Every `fields` list names only fields the server really fills.
- [ ] All times carry an offset; all values use the units above.
- [ ] Observations hold the latest reading plus full-hour rows for 24 h.
- [ ] Pressure is reduced to sea level.
- [ ] Missing values are `null` or omitted.
- [ ] Compare the responses with those of the
      [reference server](#9-reference-server-example_serverdart).

## 8. Versioning

Additions that old apps can ignore (new optional fields, new sections) keep
`version: 1`. A change that breaks a reader (renamed field, other unit) raises
`version`; the app then refuses the station with a message instead of showing
wrong values.

## 9. Reference server (`example_server.dart`)

A small standalone server that implements this interface with plausible fake
data, for testing the app and as a template for a real station. It is a single
Dart file that uses only `dart:io`; the app never imports it, and it needs no
packages, so it runs with any Dart SDK (the one inside Flutter is enough).

### Start

From the repository root:

```sh
dart lib/tools/weather/local_station/example_server.dart
```

Use plain `dart <file>`, not `dart run <file>`: inside this project `dart run`
first builds the native-asset hooks of every app dependency (that is where
messages about Visual Studio or `vswhere.exe` come from) and may fail before
the server starts. The server itself needs nothing but the Dart SDK.

On start it lists the addresses to enter in the app (every IPv4 network
interface of the computer) and then logs every request:

```
Local weather station "Example station" is running on port 8080
Sections: days, forecast, observations, warnings
Enter one of these addresses in the Weather tool
(Add place -> Local weather station):
  This computer:     http://localhost:8080
  Network (wlo1): http://192.168.1.76:8080
  Android emulator:  http://10.0.2.2:8080
Manifest: http://localhost:8080/weather-station.json
Press Ctrl+C to stop.

GET /weather-station.json 200
```

If the port is taken it says so and exits; pick another with `--port`.

| Option | Default | Meaning |
|---|---|---|
| `--bind <addr>` | `0.0.0.0` | Interface to listen on; `127.0.0.1` keeps it local to the machine. |
| `--port <n>` | `8080` | TCP port. |
| `--id <id>` | `example-01` | `station.id`. |
| `--name <name>` | `Example station` | `station.name`, the place name in the app. |
| `--lat <deg>`, `--lon <deg>` | `50.1427`, `8.5713` | Station position (Eschborn). |
| `--elevation <m>` | `140` | Station height. |
| `--sections <list>` | all four | Comma list of `observations,forecast,warnings,days`; must contain `observations` or `forecast`. Leave sections out to see the DWD fallback. |

Examples:

```sh
# measurements only: forecast, warnings and sun times come from the DWD
dart lib/tools/weather/local_station/example_server.dart --sections observations

# another place and port
dart lib/tools/weather/local_station/example_server.dart --name Balkon --lat 52.52 --lon 13.40 --port 9000
```

### Add it in the app

Weather → *Add place* → *Local weather station*, enter the address, *Check*,
then *Add*:

| App runs on | Address |
|---|---|
| The same desktop (Linux, Windows) | `http://localhost:8080` |
| Android emulator | `http://10.0.2.2:8080` (the host machine) |
| A phone in the same Wi-Fi | `http://<computer's LAN IP>:8080`, e.g. `http://192.168.1.20:8080`; allow the port in the computer's firewall |

### What it serves

| Path | Content |
|---|---|
| `/` and `/weather-station.json` | Manifest with the chosen sections and every field the app can show. |
| `/observations.json` | Latest reading (rounded to 5 min) plus full-hour rows for the last 24 h. |
| `/forecast.json` | 240 hourly steps from the next full hour (10 days). |
| `/warnings.json` | A frost warning for the coming night when it would drop to 2 °C or below, else an empty list. |
| `/days.json` | Rough sunrise and sunset for 10 days at the station's latitude. |

The weather is a daily temperature cycle with a slow drift, cloud waves and
showers. Noise is seeded per hour, so repeated requests within the same hour
agree. Times carry the computer's local offset.

### Turning it into a real station

Keep `_manifest` and the routing, and replace `_weatherAt` with readings from
the sensors or the station console (for example values a logger writes to a
file or database). Remove fields from `_observationFields` /
`_forecastFields` that the station does not measure, and drop sections it
cannot fill; the app then takes them from the DWD. A station without a
forecast simply starts with `--sections observations`.
