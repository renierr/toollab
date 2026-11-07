# News

News is a timeline reader for RSS 2.0, RSS 1.0/RDF and Atom feeds. It combines enabled sources by publication time, shows article cards, and opens an extracted reader view with a link to the original page. English and German are supported.

## Add and manage sources

1. Open **News**, then tap **Settings** and **Add source**.
2. In **Browse**, search by publisher or category and add a feed. To use another feed, select **By URL**, enter its HTTP(S) RSS or Atom feed URL, optionally set a name and category, and tap **Add feed**. A normal website URL is not automatically discovered as a feed.
3. In News settings, enable, disable, edit or remove configured sources. Disabled sources and their unread counts are hidden from the timeline; their cached articles remain available if the source is re-enabled. Removing a source also removes its cached articles.

Custom feeds are checked when added and need at least one usable entry. Feed URLs and availability can change; a source can fail temporarily or block requests.

## Reading

- Opening an article marks it as read. Optionally, **Mark as read while scrolling** marks visible articles after they pass above the viewport. Read cards are dimmed.
- With **Hide read articles** enabled, articles read in the current timeline remain visible until the next refresh, so they can be revisited by scrolling back. Previously read articles are filtered when the timeline is loaded or the filter is enabled.
- Refresh using the toolbar button or pull-to-refresh. **Refresh when opened** uses a ten-minute minimum interval during initialization.
- The reader extracts the source page on a best-effort basis. If the site blocks access, requires JavaScript, or does not expose a readable body, News shows the feed summary and a link to the original instead. Paywalls are not bypassed.

## Fetching and storage

- Refresh processes up to three enabled feeds concurrently, uses `ETag` and `Last-Modified` when available, and parses up to 80 entries per feed. Feed responses are buffered before the 8 MB size check.
- Cards use images supplied by the feed. For visible cards without one, News fetches the article page to look for an image and readable text, with at most two preview requests in flight. Opening an article shares an in-flight preview request where possible. Article responses are buffered before the 6 MB size check. Publishers can still block requests or omit images.
- Sources, article metadata, extracted Markdown, image URLs and read marks are stored locally in SQLite. Image bytes use Flutter's image cache rather than the News database. Clearing cached articles also clears read marks, but keeps sources.
- Configured sources sync through the backend when News sync is enabled. Cached articles and read marks remain device-local.
- Refresh prunes read articles published more than 30 days ago, all articles published more than 365 days ago, and entries beyond the newest 5,000. The timeline query shows up to 2,000 articles.

## Built-in catalog

On a fresh setup, **BBC Top Stories**, **NPR News**, and **The Guardian World** are enabled. **Al Jazeera** is present but disabled by default. Existing source settings are not changed by the defaults. All other catalog entries are optional.

The catalog and feed URLs are defined in [`news_catalog.dart`](news_catalog.dart):

### Top stories

- [BBC Top Stories](https://feeds.bbci.co.uk/news/rss.xml)
- [NPR News](https://feeds.npr.org/1001/rss.xml)
- [Al Jazeera](https://www.aljazeera.com/xml/rss/all.xml)
- [Deutsche Welle](https://rss.dw.com/rdf/rss-en-all)
- [France 24](https://www.france24.com/en/rss)
- [New York Times World](https://rss.nytimes.com/services/xml/rss/nyt/World.xml)

### World

- [BBC World](https://feeds.bbci.co.uk/news/world/rss.xml)
- [The Guardian World](https://www.theguardian.com/world/rss)

### Germany

- [tagesschau](https://www.tagesschau.de/xml/rss2/)
- [SPIEGEL](https://www.spiegel.de/schlagzeilen/index.rss)
- [ZEIT ONLINE](https://newsfeed.zeit.de/index)

### Technology

- [Ars Technica](https://feeds.arstechnica.com/arstechnica/index)
- [The Verge](https://www.theverge.com/rss/index.xml)
- [Wired](https://www.wired.com/feed/rss)
- [TechCrunch](https://techcrunch.com/feed/)
- [Hacker News](https://hnrss.org/frontpage)
- [heise online](https://www.heise.de/rss/heise-atom.xml)
- [BBC Technology](https://feeds.bbci.co.uk/news/technology/rss.xml)
- [The Guardian Technology](https://www.theguardian.com/uk/technology/rss)
- [New York Times Technology](https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml)

### Business

- [BBC Business](https://feeds.bbci.co.uk/news/business/rss.xml)
- [The Guardian Business](https://www.theguardian.com/business/rss)
- [Financial Times](https://www.ft.com/rss/home)
- [CNBC](https://www.cnbc.com/id/100003114/device/rss/rss.html)

### Science

- [NASA](https://www.nasa.gov/rss/dyn/breaking_news.rss)
- [ScienceDaily](https://www.sciencedaily.com/rss/all.xml)
- [Nature](https://www.nature.com/nature.rss)
- [The Guardian Science](https://www.theguardian.com/science/rss)

### Sport

- [BBC Sport](https://feeds.bbci.co.uk/sport/rss.xml)
- [The Guardian Sport](https://www.theguardian.com/sport/rss)
- [Sky Sports](https://www.skysports.com/rss/12040)

### Culture

- [The Guardian Culture](https://www.theguardian.com/culture/rss)
- [BBC Entertainment & Arts](https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml)
- [Variety](https://variety.com/feed/)
- [Rolling Stone](https://www.rollingstone.com/feed/)

## Add a built-in catalog entry

Add a `NewsCatalogSource` with a publisher name, feed URL and site URL to the appropriate `byCategory` list in `news_catalog.dart`. Update this catalog list too. A new category also needs a category entry, localized labels in both ARB files, and a mapping in `news_l10n.dart`. Add entries to `seeds` only when they should be configured on first run; set `enabledByDefault: false` to seed a disabled source.
