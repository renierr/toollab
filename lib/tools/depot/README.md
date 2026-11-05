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
| Allocation | Position-weight donut and list, X-Ray through ETF holdings, ETF overlap, fund running costs, plus region, sector, industry and asset-type split | Parqet values, onvista, Yahoo Finance and Nasdaq metadata |
| Dividends | Calendar, missing and upcoming payments, per year and per position | Parqet bookings plus Yahoo Finance for ex-dates and amounts |
| Activities | Realized-per-year card and the booking list with filters | `GET /portfolios/{id}/activities` |
| Wishlist | Stocks, ETFs and crypto with quotes, trend and a 12-month chart | Local database, optional backend sync and Yahoo Finance |
| Import | Parse DKB / ING / Postbank PDF statements, export as Parqet CSV or send to Parqet | `POST /portfolios/{id}/activities` |

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
It is disabled while a sync runs, and a sync already running when data is cleared
(for example the background one) discards its result instead of writing a partial
history back.
The settings page shows whether the grant includes write access; if not, reconnect after
enabling write in the console.

If port 47615 is busy (another login still waiting), the login fails with a "port busy"
error: finish or cancel the other login and retry.

## How sync works

`DepotParqetSync.run` is shared by the open tool, pull-to-refresh and the hourly
background task (`DepotBackgroundSync`), so all of them write the same shape.

Only one sync runs at a time. The tool lives in its own `:depot` process while the
background task runs in the main process, so the guard is a lease row in
`tool_settings` (`parqet_sync_lease`: owner and expiry), claimed inside a write
transaction and renewed while the sync runs; a process killed mid-sync frees it once it
expires. A background run that finds the lease taken is skipped. A sync started in the
tool waits for the running one and then reloads what it stored; **Sync all data again**
still runs its own full sync afterwards.

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

A sync the user starts (sync button, pull-to-refresh, retry, **Sync all data again**,
after connecting or importing) and the allocation refresh hold a `BackgroundWorkLease`:
a partial CPU wake lock plus a `dataSync` foreground notification, so they finish with
the screen off or the app in the background. The automatic stale check on opening the
tool takes none, so opening Depot does not flash a notification. The scheduled
background task needs none either: WorkManager keeps the CPU awake while it runs.

### Periods and the "today" interval

Periods map to Parqet's `relative` timeframes (`1m`, `ytd`, `max`, …), except **today**.
Parqet's relative `1d` starts at the close *before* yesterday, so on a Tuesday it would
report Monday plus Tuesday. Today is therefore requested as an `absolute` timeframe from
today's midnight, which starts at yesterday's close. Its chart has a single point, so the
day's change comes from the summary's start and end values instead of the chart. The
overview hides the chart for Today; other periods still show it.

Depot text and detail values can be selected and copied, including ISINs. On touch
screens, long-press a value to select it; on desktop, select it with the mouse.

### Risk, dividends and comparison

The risk card starts collapsed with the largest open position's name and weight.
Expanding it lists the three largest positions, and optional detail sections show the
largest known underlying holdings, country and sector with their contributing positions.
Weights are percentages of all open positive-value positions, regardless of filters.
The country and sector sections show data coverage and identify missing security
breakdowns separately from cash and other asset types. Country names from Yahoo
(English) and onvista (German) are merged under one English name. Fund breakdowns are cached;
the stock look-through uses only available fund top holdings. Both can be incomplete.
The Allocation link opens the full breakdown and its refresh controls.
Value drawdowns and daily changes use the selected period's chart and include deposits
and withdrawals, so they are not cash-flow-adjusted investment returns. Drawdown needs
at least two valid chart points; daily changes need consecutive calendar days.

The movers card switches between period return and absolute net gain contribution.
Both use the visible holdings filter; gains include realized gains and dividends and
are not a complete reconciliation of the portfolio. Expanded holding details add
the all-time total of the three Parqet net components and, when sales exist,
a link to that exact holding's sales. The link replaces the existing activity filters.
Securities with an ISIN also get **Add to wishlist**: it looks the ISIN up like the
wishlist search, takes the listing Parqet confirms for it (else the first match) and
keeps the holding's name. Once listed, the button opens the wishlist instead.

Yahoo dividend data is cached per position. Opening the Dividends tab, and every sync
while it is shown, fetches only positions that are new, in another currency or older than
a day; pull-to-refresh syncs Parqet and then does the same. The tab has no reload button:
**Reload dividend data** in settings fetches every position again.

The dividend position list shows the trailing 12 months of net booked dividends
divided by the current cost basis as yield on cost. This is not a historical cost
basis and may include payments from shares since sold. Estimated monthly income is
the existing forward 12-month net estimate divided by 12, not a payment schedule.
Yield on cost is omitted when a recent booking is in another currency; no historical
exchange rate is assumed.
The expandable booked-dividend history compares each year with its preceding year
by booking currency, with per-position totals and their share of that currency's
booked dividends. Unknown currencies are excluded and counted. Purchases, sales and
an incomplete current year affect comparisons; forecast amounts are excluded.

Invested capital in the app is net money: Parqet's `capitalHistory` minus the realized
gains of all sales up to each chart point's day, applied once when the charts load. Parqet's
capital only drops by the cost of what was sold, but without a cash account the whole
proceeds leave the depot, so a realized gain would otherwise read as a market loss on the
sale day. The value chart, range gain, benchmark, PDF report, growth card and return index
all use this net capital, so the value chart's invested line is lower than in Parqet by the
realized gains so far, and value minus invested includes them.

The optional benchmark compares the portfolio with EUR-listed accumulating ETF
proxies for MSCI World (EUNL.DE) or the S&P 500 (SXR8.DE). It fetches Yahoo daily
closing prices on demand; EUR portfolios only. Both lines start at 100 on their
first overlapping date. It starts off and resets when leaving Depot. The static
comparison replaces the value plot inside its card; its selector is hidden when
there is no chart, including Today. Portfolio returns approximate cash flows from
changes in invested capital between chart points; the ETF line uses unadjusted
closing prices.
Differences are indicative, not risk-adjusted alpha, and can be affected by costs,
taxes, missing data and timing. A failed or unavailable comparison leaves the
original value chart untouched. Prices may be delayed.

The growth card splits each year's value change into new money and market gain, from
the stored Max chart whatever period is selected, and adds the year's net dividends as a
third bar. New money is the change of the net invested capital (see above), so what went
in or out. Market gain is the rest of the value change, realized gains included. Dividends are paid out of the depot, so they are
not part of the value and are summed from the dividend transactions. The first year
starts from zero. Tapping a year lists its months. Without a cash account, a sale
followed by a buy shows as money out and money in. The card starts collapsed with the
latest year's split and the totals over all years. Chips switch between these amounts and
a return heatmap: years as rows, months as columns, each cell the month's time-weighted
return from the same index as the rises (see below), colored by size up to 8 %, plus the
year's return at the end. Numbers show in the cells only when they are wide enough;
tapping a cell shows its month and return. The current month is still running.

The savings plan card is detected from the selected scope's buys; Parqet bookings carry no
plan flag. A plan is one buy per consecutive calendar month in the same holding and booking
currency at the same amount (within 1 %, at least 5 cents, as broker amounts drift by
fractions of a cent), for at least three months. A different amount or a skipped month
ends a run, so a rate change starts a new plan; the row then names the first plan's start.
The plan's day is the median day of its last twelve runs. A run counts as missing once
that day plus a grace of the runs' day spread (5 to 10 days) has passed; two missed months
mark the plan as ended and hide it. Invested through plans sums every run of every plan,
ended ones included; one-off buys are all other buys. Amounts are per booking currency,
not converted. Tapping a plan opens its buys in Activities, and an expanded holding with
a running plan shows its rate and day. The card is hidden when no plan is running.

The drawdowns card reads Parqet's `drawdown` figure of the stored Max chart, whatever
period is selected, so deposits and withdrawals do not count as falls. This differs from
the risk card's value drawdown. A fall starts at the last point at zero (the high) and
ends at the next point back at zero; its depth is the lowest point in between. Falls of
5 % or more are listed deepest first, an ongoing one included; the collapsed line always
shows the current distance from the high. Recovery time runs from the high to the point
back at it. Older Max points are weekly, so dates can be a few days off.
The card is titled Highs and lows and switches between drops and rises. A rise runs from
the low of a listed drop (or the first point) to the high where the next listed drop
starts, or to the newest point while still climbing. Parqet's drawdown says nothing about
climbs, so the rise's return is a time-weighted index worked out from the Max chart, with
each step's change of net invested capital taken out. The amount is the value change
minus that change of capital. Rises of 5 % or more are listed strongest first, plus the
ongoing one at any size.

The Activities yearly card can export a CSV for the selected year and active
activity filters. It contains individual bookings and their original currencies,
not a tax calculation or filing. Check the broker's tax documents.
Its realized gains, dividends and interest use Parqet's net amounts. Taxes and
fees are separate totals across all activity types, not additional deductions
from the net total. The yearly summary covers the whole year and is not changed
by the activity filters.
The net total is profit and income, not sale proceeds or available cash; it
excludes the invested capital returned when selling.

Below it, the allowance card compares the selected year's taxable income with the saver's
allowance (1,000 or 2,000, picked by chips and stored in the tool settings). Income is
gross: dividends and interest are net amount plus tax, sale gains are Parqet's net
realized gain plus the sale's tax. Stock sales are kept apart because a stock loss only
offsets stock gains; every other result offsets all income. Only bookings in the
portfolio currency count. For the running year it lists the open holdings (stocks, ETFs,
ETCs, funds) with an unrealized loss and how much of those losses would lower the
taxable income above the allowance. Equity funds (ETFs and funds whose name does not
read as a bond or money market fund) get the 30 % partial exemption on distributions,
sale gains and open losses; bond funds none. For the running year the card also estimates
next January's advance lump sum (Vorabpauschale) per fund: the price on 1 January (worked
out from the year-to-date gain, today's value and the year's bookings) × 70 % × the BMF
base rate, one twelfth less per full month before a purchase, capped by the year's price
rise plus distributions, minus distributions, then the partial exemption. Today's price
stands in for the year-end price. The running year's base rate is a depot setting,
stored per year and prefilled from the known rates in `models/depot_advance_lump.dart`;
the BMF publishes it in January only as a letter, with no machine-readable source, so it
is entered by hand. Add each new rate to that constant too. Without a rate the card shows
no estimate. The lump sum is income of the next year, so it
uses that year's allowance first. A rough guide only: the bank's actual loss pots, losses
carried from earlier years and allowances split across banks are not known.
The yearly summary groups gains, income, taxes and fees by the activity's
currency, without conversion or a combined total. The usual single-currency
view stays compact. Activities without a currency are counted separately and
excluded from the totals: their values may represent different currencies.
The expandable sales section shows net proceeds and known realized gains per booking
currency, plus the largest individual gains and losses. It counts sales without a
reported gain and does not infer a returned cost basis or apply the activity filters.
The yearly net totals also mark missing sale gains; their known totals can be incomplete.
The expandable fee section breaks the year's fees down per booking currency: total, number
of trades (and how many were free), average fee per trade and the fee rate of the traded
volume (shares × price, or the booked amount when that is zero). Fees are split into buys,
sells and other bookings (custody, dividend fees), by broker when more than one is booked,
and the three trades with the highest fee rate are listed, marked above 1 %. The previous
year's fee total is shown for comparison. Like the sales section it ignores the activity
filters, and it is hidden when the year has no fees.

The activity list groups bookings by month, newest first. The two newest matching
months start expanded; older months start collapsed, and each can be toggled.
Search, type and an
optional inclusive date range filter the selected portfolio's activities. The
filtered CSV exports all matching bookings, including collapsed months, across all matching years,
including their original currencies and booking details. Date filtering and
month grouping use the same local calendar dates shown in the list. Clearing the
date range leaves the other filters intact.

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
| Type (Typ) | Stock | Stock, ETF, ETC or fund is guessed from the name; Parqet only says "security". ETC covers exchange-traded commodities and notes (ETC, ETN, ETP, physical gold or silver, Xetra-Gold, EUWAX Gold). |
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

1. Add DKB, ING or Postbank PDF statements (file picker or Android share sheet). They are parsed
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
| `GET /v1/finance/search?q=…` | Security search by name, ticker or ISIN; filtered to stocks, ETFs, funds and crypto. Also the sector and industry of a holding, and a holding sparkline's fallback listing |
| `GET /v8/finance/chart/{symbol}?period1=…&period2=…&interval=5m` | Latest quote and the last 24 hours for wishlist entries and visible holdings |
| `GET /v8/finance/chart/{symbol}?range=1y&interval=1d` | One year of daily closes, loaded on opening wishlist details |
| `GET /v10/finance/quoteSummary/{symbol}?modules=assetProfile,topHoldings,fundProfile` | Country of a stock, and a fund's sector weights, top holdings and TER |
| `GET https://api.nasdaq.com/api/company/{symbol}/company-profile` | Region fallback for US-listed stocks when Yahoo country is unavailable |
| `GET https://api.onvista.de/api/v1/funds/ISIN:{isin}/breakdowns` | A fund's full country and sector split and its ten largest holdings (with ISIN) |
| `GET https://api.onvista.de/api/v1/funds/ISIN:{isin}/snapshot` | A fund's ongoing charges (TER) when Yahoo has none |
| `GET https://api.onvista.de/api/v1/stocks/ISIN:{isin}/snapshot` | Country fallback for a stock when Yahoo has none |

Yahoo's unofficial endpoints may change or be unavailable, and quotes may be delayed.
The latest quote is Yahoo's `fulldayPrice`, which includes pre- and post-market trades,
so US listings keep moving while Wall Street is closed; without it the regular-session
price is used.
Holding sparklines load only for visible rows. On narrow rows a chart sits below the
holding details; wider rows show it beside the name. For securities,
the ISIN is sent to Parqet's public asset endpoint to resolve confirmed listing symbols;
crypto symbols are searched on Yahoo. After the matching quote exchange, OTC listings are
tried last because they often have no intraday chart. When Parqet lists no symbol or none of
its symbols has a chart, the first supported result of Yahoo's ISIN search is the fallback.
Yahoo does not return the ISIN in search results, so this fallback is not independently
confirmed. Yahoo receives the selected listing symbol, not portfolio amounts. Up to four holding lookups run
concurrently, deduplicated by asset, with intraday results cached in memory for 15
minutes and failed lookups retried after 5 minutes. The cache holds at most 128 trends
and 128 failed lookups, and removes expired entries even while the tool is closed. Up to
three Parqet listings and one Yahoo search result are tried if a listing has fewer than
two prices or cannot be loaded. Yahoo requests fail over between its two query hosts on
connection errors, throttling or invalid responses. Each line contains only prices within
the last 24 hours, including available pre- and post-market data; it disappears
when fewer than two points remain. The line uses the listing currency, not the holding's
selected performance period or necessarily the same exchange as Parqet. Unsupported
or unmatched assets have no line.
Wishlist detail history is cached in memory for 24 hours (at most 16 entries) and fetched
only on opening details. Leaving Depot drops these histories and the in-memory logo bytes,
and reduces retained intraday lines to at most 48 points per asset. Saved wishlist items,
database-cached logos, and in-memory cache timestamps remain intact. Returning within 15
minutes reuses the reduced holding lines; the manual Parqet refresh does not bypass this throttle.
Prices and history are not sent to Parqet.
The wishlist also places its sparkline below the row on narrow screens and beside the
name on wider screens. The selected Yahoo listing determines the exchange and trading
currency. The wishlist's
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

A row of jump links above the Allocation and Dividends tabs scrolls to each section and
highlights the one in view; sections without data get no link. Activities has a row of
years instead, which jumps to that year's latest month and follows the year in view.

The Allocation tab resolves sector, industry and country per open holding. A fund has no
single sector or country, so ETFs and funds are looked up on onvista by ISIN first: its
country and sector split covers the whole fund, and its top ten holdings feed the X-Ray.
onvista's German names are mapped onto Yahoo's sector names and into the region table;
cash and "other" buckets stay "Unclassified". Only when onvista lacks a split is Yahoo
asked: its `topHoldings` sector weights, and a region split approximated from the domicile
of up to ten largest constituents. Yahoo's `quoteType` also overrides the name heuristic,
so a fund without "ETF" or "Fonds" in its name is no longer counted as a stock. An ETC
name wins over that, since Yahoo reports most ETCs as "ETF"; ETCs are not looked up and
count as other assets, not as missing data, in the sector and country risk split.
Stocks use Yahoo for sector, industry and country, then onvista's stock snapshot for a
missing country, then Nasdaq region data and up to three US-format listings confirmed by
Parqet for the same ISIN.

Funds have no industry of their own, so the industry split looks through each ETF and
fund to its top ten holdings: each holding's industry gets the fund's value times its
weight. The refresh looks up those holdings on Yahoo by ISIN or symbol, deduplicated
across funds and skipping companies held directly, which already have a profile. Fund
value outside the top holdings shows as "ETFs & funds (other holdings)"; only holdings
whose lookup found no industry stay "Unclassified".

Below the region split a line estimates the USD exposure: the US share of the securities
whose country is known, looking through fund country weights, with stocks lacking a
country placed by their ISIN prefix. It also prices a 10 % weaker dollar. It is hidden for
a USD portfolio.

The X-Ray merges direct stocks with every fund's top holdings, scaled by the fund's value
and keyed by ISIN (Yahoo fallbacks by symbol), and lists the 20 largest; each expands to
the positions that hold it. Fund value outside the published top holdings is shown as
"Other fund holdings". In the position list ETFs and funds expand to their top holdings,
and every row carries a kind badge.

ETF overlap compares every pair of open ETFs and funds that have published top holdings.
A pair's score is the sum, over the companies both hold, of the smaller of the two fund
weights. Only the top holdings are known, so the score is a lower bound. Below 5 % it is
low, from 15 % high. With three to eight funds a heatmap shows every pair; the list ranks
the pairs, and each opens the shared holdings with their weight in both funds, marking
companies also held directly.

Running costs show each open ETF and fund's TER and its cost per year (value × TER),
merged per ISIN across portfolios. The TER comes from Yahoo's `fundProfile` when the
quote summary is fetched anyway, otherwise from onvista's fund snapshot (`ongoingCharges`).
A fund without one is retried at most weekly and listed by name instead of being counted
as free. "Avg. TER funds" weights by fund value; "Avg. TER depot" spreads the
same cost over all open positions except funds without a TER. TERs above 0.5 % are amber,
above 1 % red. The expanded holding on the Overview shows the same TER and cost.

Profiles are stored in their own tables (see Local data) and loaded without network
requests; only changed entries are written back. Opening the tab never fetches. The refresh button only fetches positions without
a profile or with incomplete metadata, at most once per asset every 24 hours (a fund that
lacks only its TER every 7 days), and keeps known values, except that a newly fetched TER
replaces the stored one. A complete fund profile is fetched again once it is 90 days old,
to pick up TER cuts and rebalanced holdings; a complete stock profile never is. Bumping
`DepotAssetProfile.currentVersion` re-fetches fund profiles once. **Reload all allocation
data** in the settings re-fetches every open security and lets new values replace cached
ones; cached values stay until replaced. Portfolio sync remains independent.

## Local data

Tables in the tool database (`DepotStore`): portfolios, holdings, holding performance per
period, summaries and chart points per scope and period, transactions, activity counts per
holding, dividend data from Yahoo Finance, holding logos (downloaded only on request from
the settings), custom holding order (`holding_order`), the wishlist, and allocation
metadata. Summaries and charts exist per portfolio and for all portfolios combined (scope
`_all`).

Allocation metadata is keyed by ISIN, or by symbol for fund constituents and alternate
listings:

| Table | Content |
|---|---|
| `asset_profiles` | Kind, sector, industry, country, region, a fund's `expense_ratio` (TER as a fraction), cache version, `fetched_at` and the last lookup `attempted_at`. A row without `fetched_at` only records a failed lookup |
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
