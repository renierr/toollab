# Depot

Portfolio overview on top of [Parqet](https://parqet.com). The tool mirrors your Parqet
portfolios, holdings, performance and activities into a local database, and turns broker
PDF statements into Parqet activities.

Parqet is the source of truth for the portfolio. Its data is mirrored locally and
refreshed by sync; intraday sparklines and dividend estimates use Yahoo Finance.
Only imported statements and the local wishlist are edited here.

- **API reference:** <https://developer.parqet.com/docs/api>
- **OpenAPI spec (machine-readable, the most precise source):**
  <https://developer.parqet.com/api-spec/current.json>
- **Developer console (integrations):** <https://developer.parqet.com/console/integrations>

## Tabs

| Tab | Shows | Source |
|---|---|---|
| Overview | KPIs, value chart, allocation, biggest movers, holdings for the selected period and portfolio | `POST /performance` |
| Allocation | Position-weight donut and list, X-Ray through ETF holdings, plus region, sector, industry and asset-type split | Parqet values, onvista, Yahoo Finance and Nasdaq metadata |
| Dividends | Calendar, missing and upcoming payments, per year and per position | Parqet bookings plus Yahoo Finance for ex-dates and amounts |
| Activities | Realized-per-year card and the booking list with filters | `GET /portfolios/{id}/activities` |
| Wishlist | Stocks, ETFs and crypto with quotes, trend and a 12-month chart | Local database, optional backend sync and Yahoo Finance |
| Import | Parse DKB / ING PDF statements, export as Parqet CSV or send to Parqet | `POST /portfolios/{id}/activities` |

## Creating a connection

Parqet Connect uses OAuth 2.0 with PKCE as a public client: there is no client secret,
only the client ID of an integration you create yourself.

1. Open the [developer console](https://developer.parqet.com/console/integrations) and
   create a private integration.
2. Grant it **read and write** access to portfolios. Read is enough for viewing; write
   (`portfolio:write`) is only used to send imported statements.
3. Register the redirect URL exactly as shown in the tool's settings:
   `http://127.0.0.1:47615/callback`. The app listens on this loopback port during login,
   which works on Android and Windows without an app link. The URL must match
   character for character.
4. In the tool, open **Settings → Parqet connection**, paste the client ID and tap
   **Connect with Parqet**. The browser opens Parqet's login; after approving, the tab
   returns to the loopback page and the app stores the tokens.
5. The first sync starts right away.

Tokens live in secure storage, never in the database. The access token is refreshed
automatically. **Disconnect** removes only the tokens; every synced row stays on the device
as an offline copy. Reconnecting syncs again and mirrors the connected account.
**Delete local data** (Settings → Data, with a confirmation) empties every synced table;
the wishlist and the tokens stay, so a connected account syncs again from scratch.
The settings page shows whether the grant includes write access; if not, reconnect after
enabling write in the console.

If port 47615 is busy (another login still waiting), the login fails with a "port busy"
error: finish or cancel the other login and retry.

## How sync works

`DepotParqetSync.run` is shared by the open tool, pull-to-refresh and the hourly
background task (`DepotBackgroundSync`), so all of them write the same shape.

1. **Selected period first.** The period on screen is fetched and stored before anything
   else, so the view updates quickly.
2. **Max period.** Holdings (shares, prices, all-time figures) and each holding's
   `activityCount` come from the Max period, so it is always fetched.
3. **Activities by count.** Parqet's `activityCount` per holding is compared with the
   count stored after the last read:
   - unchanged holdings are not read again;
   - a holding whose count changed (new, backdated or deleted bookings) is re-read on its
     own with the `holdingId` filter and its stored rows are replaced;
   - with more than a handful of changed holdings, or with no stored counts yet, the whole
     portfolio is read once instead;
   - the newest bookings of each portfolio are always read too, for holdings Parqet lists
     without a count (such as cash).
4. Other periods are fetched only when selected and their cached copy is stale. Every
   period response also updates the stored holdings' price, value and quote time, so
   they stay in step with that period's figures; sold holdings are only replaced by Max.

**Sync all data again** (settings) re-reads every period and every activity. It is only
needed when a booking is edited in Parqet without changing the holding's activity count.

### Periods and the "today" interval

Periods map to Parqet's `relative` timeframes (`1m`, `ytd`, `max`, …), except **today**.
Parqet's relative `1d` starts at the close *before* yesterday, so on a Tuesday it would
report Monday plus Tuesday. Today is therefore requested as an `absolute` timeframe from
today's midnight, which starts at yesterday's close. Its chart has a single point, so the
day's change comes from the summary's start and end values instead of the chart. The
overview hides the chart for Today; other periods still show it.

Depot text and detail values can be selected and copied, including ISINs. On touch
screens, long-press a value to select it; on desktop, select it with the mouse.

### Reading a holding

A fictive position, **Example Corp**: 100 shares bought at 50 €, now quoted at 60 €,
yesterday's close 59 €, 300 € net dividends received over the years. The 45 € fees and
taxes paid are already contained in the buy price and the net dividends.
The open positions of the selected portfolio are worth 60,000 € in total.

Collapsed row, with the period selector on **Today**:

```
┌──────────────────────────────────────────────────────────────────┐
│ ┌──┐  Example Corp                                    6,000.00 €  │ ← current value
│ │EC│  Stock  +100.00 €                     +1.69 %     60.00 €   │
│ └──┘    │        │                            │           │      │
│         │        └ gain in the period         │           └ current price
│         └ kind, or "Sold"                     └ return in the period
└──────────────────────────────────────────────────────────────────┘
```

Fully sold positions are hidden unless the holdings filter shows them; then they appear
muted (faded avatar, grey text, tinted background, a tag icon before "Sold") and their
current value is 0.

The same row with **Max** selected reads `+1,300.00 €` and `+26.00 %`: only the two period
figures change, the value and price stay the same.

Expanded details (German UI labels in brackets), on **Today**:

| Row | Example | Meaning |
|---|---|---|
| Type (Typ) | Stock | Stock, ETF or fund is guessed from the name; Parqet only says "security". |
| ISIN / Symbol | DE000EXAMPLE | ISIN for securities, symbol for crypto. |
| Shares (Anteile) | 100 | Shares held now. |
| Avg. buy price (Ø Kaufkurs) | 50.00 € | Average price paid per share still held. |
| Current price (Aktueller Kurs) | 60.00 € | Latest quote. |
| Previous close (Schlusskurs Vortag) | 59.00 € | Quote at the start of the period; on other periods this row reads "Price at start (…)". |
| Quote from (Kurs vom) | today 14:08 | Time of the latest quote. |
| Exchange (Börse) | langschwarz | Where the quote comes from. |
| Cost basis (Einstandswert) | 5,000.00 € | Shares × average buy price. |
| Current value (Aktueller Wert) | 6,000.00 € | Shares × current price. |
| Weight (Gewichtung) | 10.00 % | Current value ÷ value of all open positions in the selected portfolio. |
| Gain (Today) (Gewinn) | +100.00 € | Price change, realized gains and dividends within the period, net of fees and taxes. Same as the row's subtitle. |
| Return (Today) (Rendite) | +1.69 % | Gain ÷ money at stake, see below. Same as the row's percentage. |
| Unrealized (total) | +1,000.00 € (+20.00 %) | Current value − cost basis, and that in percent of the cost basis. Ignores the period. |
| Realized (total) | 0.00 € | Gains locked in by sales, all time. |
| Dividends (total) | 300.00 € | Net dividends, all time. |
| Fees & taxes (Gebühren & Steuern) | 45.00 € | Paid on this holding, all time. |
| IRR (p.a.) (IZF) | +7.80 % | Money-weighted annual return over the whole holding period, as Parqet computes it. |
| First activity (Erste Aktivität) | 2022-03-01 | Date of the first booking. |

Rows tagged *(total)* always cover the whole history. Only *Gain* and *Return* (and the
start price) follow the period selector.

### Returns shown per holding

The percentage next to a holding is its period gain relative to the money at stake: the
value held at the period start, or the cost basis when the position was opened within the
period (always the case for Max). It therefore shares the sign of the money gain.

| Period | Gain | Base | Return |
|---|---|---|---|
| Today | +100 € (100 × (60 − 59)) | 5,900 € value at yesterday's close | +1.69 % |
| Max | +1,300 € (1,000 unrealized + 300 dividends) | 5,000 € cost basis | +26.00 % |

Parqet's time-weighted return (TTWROR) is deliberately not used per holding: it ignores
when and how much money went in, so it can be positive while the money gain is negative
(e.g. most shares bought later at higher prices). Fully sold positions have no cost basis
left and show no Max percentage. Portfolio-level KPIs still show TTWROR and IRR.

## PDF report

The PDF icon on the Overview tab saves the current selection as an A4 report: the
selected portfolio and period, and the holdings exactly as the filter and sort show them.

1. Header: portfolio, period, active filter and sort, creation and sync time.
2. KPI box: the same figures as the overview tiles.
3. Value chart (value filled, invested capital dashed) next to the allocation by kind.
   On **Today** the chart has a single point, so the biggest movers take its place.
4. Biggest movers: up to five gains and five losses of the period by return percentage,
   as diverging bars the same card the overview shows above the holdings. Both follow
   the holdings filter.
5. Holdings table: shares, price, value, weight (with a small bar), and the period's gain
   and return, with a total row. Sold holdings are muted.
6. All-time table per holding: average buy price, cost basis, unrealized (amount and
   percent), realized, dividends, fees and taxes, IRR and date of the first activity.

Logos appear when they were downloaded from the settings and are PNG or JPEG; otherwise
the initials badge from the app is drawn.

## Importing statements

1. Add DKB or ING PDF statements (file picker or Android share sheet). They are parsed
   locally; nothing leaves the device at this step.
2. Review and edit the parsed activities.
3. Either export a Parqet CSV, or **Send to Parqet**: the app asks `GET /user` which
   portfolios it may write to, offers only those, and creates the activities.

Every sent activity carries an `externalId` derived from the statement, so sending the
same PDF twice does not create duplicates. The sync after sending picks the new bookings
up through the activity counts, even when the statement dates lie further back.

## Endpoints used

| Endpoint | Used for |
|---|---|
| `GET /portfolios` | Portfolio list |
| `POST /performance` | Summaries, charts, holdings and per-holding performance per period |
| `GET /portfolios/{id}/activities` | Bookings, paged; optionally filtered by `holdingId` |
| `POST /portfolios/{id}/activities` | Sending imported statements |
| `GET /user` | Write permissions before sending |

Pages of up to 500 activities are read, at most two requests run in parallel, and
request starts are spaced out. A rate-limited request waits for Parqet's
`Retry-After` header (or backs off exponentially) for up to four attempts;
transient network and server errors are retried once. The error card on the
overview and activities tabs links to a copyable details dialog.

Parqet Connect has no watchlist and no security search endpoint, so the wishlist cannot be
read from or written to Parqet. Its quotes come from Yahoo Finance instead:

| Endpoint | Used for |
|---|---|
| `GET /v1/finance/search?q=…` | Security search by name, ticker or ISIN; filtered to stocks, ETFs, funds and crypto. Also the sector and industry of a holding |
| `GET /v8/finance/chart/{symbol}?period1=…&period2=…&interval=5m` | Latest quote and the last 24 hours for wishlist entries and visible holdings |
| `GET /v8/finance/chart/{symbol}?range=1y&interval=1d` | One year of daily closes, loaded on opening wishlist details |
| `GET /v10/finance/quoteSummary/{symbol}?modules=assetProfile,topHoldings` | Country of a stock, and a fund's sector weights and top holdings |
| `GET https://api.nasdaq.com/api/company/{symbol}/company-profile` | Region fallback for US-listed stocks when Yahoo country is unavailable |
| `GET https://api.onvista.de/api/v1/funds/ISIN:{isin}/breakdowns` | A fund's full country and sector split and its ten largest holdings (with ISIN) |
| `GET https://api.onvista.de/api/v1/stocks/ISIN:{isin}/snapshot` | Country fallback for a stock when Yahoo has none |

Yahoo's unofficial endpoints may change or be unavailable, and quotes may be delayed.
The latest quote is Yahoo's `fulldayPrice`, which includes pre- and post-market trades,
so US listings keep moving while Wall Street is closed; without it the regular-session
price is used.
Holding sparklines load only for visible rows with room to show them. For securities,
the ISIN is sent to Parqet's public asset endpoint to resolve confirmed listing symbols;
crypto symbols are searched on Yahoo. Yahoo receives the selected listing symbol, not
portfolio amounts. Up to four holding lookups run concurrently, deduplicated by asset,
with intraday results cached in memory for 15 minutes. The cache holds at most 128 trends
and 128 failed lookups, and removes expired entries even while the tool is closed. Up to
three confirmed listings are tried if a listing has fewer than two prices or cannot be
loaded. Each line contains only prices
within the last 24 hours, including available pre- and post-market data; it disappears
when fewer than two points remain. The line uses the listing currency, not the holding's
selected performance period or necessarily the same exchange as Parqet. Unsupported
or unmatched assets have no line.
Wishlist detail history is cached in memory for 24 hours (at most 16 entries) and fetched
only on opening details. Leaving Depot drops these histories and the in-memory logo bytes,
and reduces retained intraday lines to at most 48 points per asset. Saved wishlist items,
database-cached logos, and in-memory cache timestamps remain intact. Returning within 15
minutes reuses the reduced holding lines; the manual Parqet refresh does not bypass this throttle.
Prices and history are not sent to Parqet.
The selected Yahoo listing determines the exchange and trading currency. The wishlist's
entries are ordered by today's percentage change, highest first; entries without a daily
change appear last. The order updates when quotes refresh. The wishlist's
saved currency switch selects native prices or an approximate EUR price, marked `≈`, using
Yahoo's latest currency rate; it falls back to native currency if no rate is available.
Details retain the listing currency for the chart, historical prices and returns; the EUR
price is a current conversion, not a historical EUR return.
Wishlist logos are fetched by symbol from Financial Modeling Prep, cached locally and
fall back to initials when unavailable. No account credentials are sent to that provider.
An ISIN search also checks Parqet's public asset data and stores the ISIN only for Yahoo
symbols explicitly listed on the matching asset. If Yahoo's ISIN search returns no match,
the app searches by a confirmed symbol instead. Existing entries can be linked from the
search result; if Parqet cannot confirm the match, the ISIN remains unknown.

The Allocation tab resolves sector, industry and country per open holding. A fund has no
single sector or country, so ETFs and funds are looked up on onvista by ISIN first: its
country and sector split covers the whole fund, and its top ten holdings feed the X-Ray.
onvista's German names are mapped onto Yahoo's sector names and into the region table;
cash and "other" buckets stay "Unclassified". Only when onvista lacks a split is Yahoo
asked: its `topHoldings` sector weights, and a region split approximated from the domicile
of up to ten largest constituents. Yahoo's `quoteType` also overrides the name heuristic,
so a fund without "ETF" or "Fonds" in its name is no longer counted as a stock.
Stocks use Yahoo for sector, industry and country, then onvista's stock snapshot for a
missing country, then Nasdaq region data and up to three US-format listings confirmed by
Parqet for the same ISIN.

The X-Ray merges direct stocks with every fund's top holdings, scaled by the fund's value
and keyed by ISIN (Yahoo fallbacks by symbol), and lists the 20 largest; each expands to
the positions that hold it. Fund value outside the published top holdings is shown as
"Other fund holdings". In the position list ETFs and funds expand to their top holdings,
and every row carries a kind badge.

Profiles are stored in their own tables (see Local data) and loaded without network
requests; only changed entries are written back. Opening the tab never fetches. The refresh button only fetches positions without
a profile or with incomplete metadata, at most once per asset every 24 hours, and keeps
known values. A complete profile is never fetched again on its own; bumping
`DepotAssetProfile.currentVersion` re-fetches fund profiles once. **Reload all allocation
data** in the settings re-fetches every open security and lets new values replace cached
ones; cached values stay until replaced. Portfolio sync remains independent.

## Local data

Tables in the tool database (`DepotStore`): portfolios, holdings, holding performance per
period, summaries and chart points per scope and period, transactions, activity counts per
holding, dividend data from Yahoo Finance, holding logos (downloaded only on request from
the settings), the wishlist, and allocation metadata. Summaries and charts exist per
portfolio and for all portfolios combined (scope `_all`).

Allocation metadata is keyed by ISIN, or by symbol for fund constituents and alternate
listings:

| Table | Content |
|---|---|
| `asset_profiles` | Kind, sector, industry, country, region, cache version, `fetched_at` and the last lookup `attempted_at`. A row without `fetched_at` only records a failed lookup |
| `asset_shares` | A fund's sector and country weights, one row per `dimension` (`sector` / `country`) and name |
| `fund_constituents` | A fund's top holdings by `rank`, with name, ISIN or symbol and weight |

These tables are part of the data export, are kept on **Disconnect** and are emptied by
**Delete local data**. Older versions kept this cache as JSON in tool settings; the schema
migration moves it into the tables and deletes the settings entries.

Depot tests use in-memory SQLite and block real HTTP requests. Run them with
`flutter --suppress-analytics test --no-pub test/tools/depot` to also suppress Flutter CLI
telemetry and avoid dependency downloads.

The wishlist is keyed by Yahoo symbol and stores name, type, exchange, currency, verified
ISIN when available, the price when added and the date. It is never sent to Parqet and
survives Parqet sync. When cloud sync is enabled for Depot, entries and
deletions sync through the backend; quotes, logos and the currency preference stay local.
Existing entries are included in the first backend sync.

### Exporting the data

**Settings → Data → Export all data** saves one ZIP. It is meant as an exit path: the
files stay usable in a spreadsheet, a database tool or a script if Parqet is no longer
available. The ZIP holds:

- `depot.sqlite`: a standalone SQLite database with every table under its plain name
  (`transactions`, `holdings`, …), the app's schema and raw values, logo images included.
  Dates there are epoch milliseconds, as in the app.
- One CSV per table, named like the table (`transactions.csv`, …): comma-separated,
  UTF-8 with BOM, one header row, dot as decimal separator. Date columns (`datetime`,
  `date`, `quote_at`, `synced_at`, …) are ISO 8601 in UTC. Logo images are left out.

Amounts are in the portfolio currency, as Parqet booked them.
