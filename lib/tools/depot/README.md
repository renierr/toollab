# Depot

Portfolio overview on top of [Parqet](https://parqet.com). The tool mirrors your Parqet
portfolios, holdings, performance and activities into a local database, and turns broker
PDF statements into Parqet activities.

Parqet is the source of truth. Everything shown is a local copy that a sync refreshes;
nothing is edited locally except imported statements before they are sent.

- **API reference:** <https://developer.parqet.com/docs/api>
- **OpenAPI spec (machine-readable, the most precise source):**
  <https://developer.parqet.com/api-spec/current.json>
- **Developer console (integrations):** <https://developer.parqet.com/console/integrations>

## Tabs

| Tab | Shows | Source |
|---|---|---|
| Overview | KPIs, value chart, allocation, holdings for the selected period and portfolio | `POST /performance` |
| Dividends | Calendar, missing and upcoming payments, per year and per position | Parqet bookings plus Yahoo Finance for ex-dates and amounts |
| Activities | Realized-per-year card and the booking list with filters | `GET /portfolios/{id}/activities` |
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
automatically. **Disconnect** removes the tokens and every synced row from the device.
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
4. Other periods are fetched only when selected and their cached copy is stale.

**Sync all data again** (settings) re-reads every period and every activity. It is only
needed when a booking is edited in Parqet without changing the holding's activity count.

### Periods and the "today" interval

Periods map to Parqet's `relative` timeframes (`1m`, `ytd`, `max`, …), except **today**.
Parqet's relative `1d` starts at the close *before* yesterday, so on a Tuesday it would
report Monday plus Tuesday. Today is therefore requested as an `absolute` timeframe from
today's midnight, which starts at yesterday's close. Its chart has a single point, so the
day's change comes from the summary's start and end values instead of the chart.

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

Pages of up to 500 activities are read, up to 4 requests run in parallel, and a
rate-limited request is retried a few times with a short back-off.

## Local data

Tables in the tool database (`DepotStore`): portfolios, holdings, holding performance per
period, summaries and chart points per scope and period, transactions, activity counts per
holding, dividend data from Yahoo Finance, and holding logos (downloaded only on request
from the settings). Summaries and charts exist per portfolio and for all portfolios
combined (scope `_all`).
