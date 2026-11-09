# News

News is a timeline reader for RSS 2.0, RSS 1.0/RDF and Atom feeds. It combines enabled sources by publication time, shows article cards, and opens an extracted reader view with a link to the original page. English and German are supported.

## Add and manage sources

1. Open **News**, then tap **Settings** and **Add source**.
2. In **Browse**, search by publisher or category and add a feed. To use another feed, select **By URL**, enter its HTTP(S) RSS or Atom feed URL, optionally set a name and category, and tap **Add feed**. A normal website URL is not automatically discovered as a feed.
3. In News settings, enable, disable, edit or remove configured sources. Disabled sources and their unread counts are hidden from the timeline; their cached articles remain available if the source is re-enabled. Removing a source also removes its cached articles.

Custom feeds are checked when added and need at least one usable entry. Feed URLs and availability can change; a source can fail temporarily or block requests.

## Reading

- Opening an article marks it as read; returning to the feed also triggers a sync if configured. Optionally, **Mark as read while scrolling** marks visible articles after they pass above the viewport. The last cards can never pass the top, so pulling up past the end of the timeline marks all visible cards, including partially visible ones, as read and then refreshes. Merely reaching the end, or opening a short timeline, marks nothing. Read cards are dimmed.
- Use the text-size buttons in the article reader to adjust the headline, article text and fallback summary from 80% to 200% in 10% steps. The size is saved locally, applies to all articles, and works alongside the device text-size setting.
- With **Hide read articles** enabled, articles read in the current timeline remain visible until the next refresh, so they can be revisited by scrolling back. Previously read articles are filtered when the timeline is loaded or the filter is enabled.
- Refresh using the toolbar button, pull-to-refresh at the top, or a fresh pull up from the bottom of the timeline. The bottom pull arms at the same distance as the top one (a quarter of the list height); with a mouse wheel, keep scrolling past the end. A manual refresh returns the timeline to the top. With **Refresh when opened** enabled, News checks the last refresh during state initialization and fetches if it is at least ten minutes old. This is not a periodic ten-minute poll; reopening News while its state remains initialized does not by itself start another feed refresh.
- Articles stop counting as new or unread once they are more than 48 hours past their publication time. They are dimmed in the full timeline and excluded from **Hide read articles**, but are not deleted. The count updates as articles age while News is active. If a feed has no usable date, News uses the first local fetch time for that item; after clearing the cache, an undated item can appear new again.
- The reader extracts the source page on a best-effort basis. Direct video URLs found in HTML video elements get play buttons: Android uses ToolLab's native player, while desktop opens the URL in the default handler. Playback depends on the source, format, access restrictions and network. Embedded players such as YouTube are not extracted; open the original page to watch them. If the site blocks access, requires JavaScript, or does not expose a readable body, News shows the feed summary and a link to the original instead. Paywalls are not bypassed.
- Long-press an image in a card or reader to copy it; desktop also supports right-click. The copied image is converted to PNG and limited to 4096 pixels on its longest side. Linux requires `wl-copy` or `xclip`.
- At the bottom of the reader, copy the article URL or open the original in a browser. Android also offers system sharing.

## Fetching and storage

### How much is loaded per source?

Each refresh considers the **first 80 entries** returned by each enabled feed, in the feed's order. A feed may return fewer entries; unusable or duplicate entries are skipped. News does not page through older feed entries. Previously cached articles can remain available across refreshes, so the total stored for a source can exceed 80.

- Refresh processes up to three enabled feeds concurrently and uses `ETag` and `Last-Modified` when available. An unchanged feed can return no entries to process. Feed downloads stop and abort as soon as they pass 8 MB, and the 15-second timeout covers the whole download.
- The refresh message counts newly inserted articles only when their publication time is within the last 48 hours. Older entries can still be cached for the full timeline. A later usable feed date updates a cached item's publication time; missing dates do not reset its first-fetch fallback on each refresh.
- Cards use images supplied by the feed. For visible cards without one, News fetches the article page to look for an image and readable text, with at most two preview requests in flight. Opening an article shares an in-flight preview request where possible. Article downloads stop and abort past 6 MB or after 20 seconds. Publishers can still block requests or omit images.
- Sources, article metadata, extracted Markdown, video and image URLs, and read marks are stored locally in SQLite. Image bytes use Flutter's image cache rather than the News database. Existing cached article bodies are fetched once more to discover videos; if fetching fails, the cached body remains available. Clearing cached articles keeps recent read marks and sources.
- Refresh prunes read articles published more than 30 days ago, all articles published more than 365 days ago, and entries beyond the newest 5,000. The timeline query shows up to 2,000 articles.

## Synchronization

News uses the app's generic backend sync. To share data, devices must use the same backend URL and user ID, with News enabled in the per-tool sync settings. A blank user ID uses the shared, unsuffixed News namespace. Devices do not need to be online at the same time.

**Current switch limitation:** News's own automatic sync checks the server URL and the News switch, but does not check the global sync switch. Turning off the global switch alone therefore does not reliably stop News syncing when a URL is still configured. Turn off the News switch to stop News sync. The Android scheduled all-tools sync does check the global switch.

### When sync runs

- News attempts a sync when opened, after a manual feed refresh, after source changes, and when returning from an article reader. The app-wide **Sync Now** also includes News when its tool switch is on. Android's scheduled backend sync can include News if that task is enabled.
- Opening an article, scrolling past one, or using **Mark all as read** (enabled sources only) records the read locally. Cards dim at once; reads passed while scrolling are saved together in one transaction every 250 ms, and opening an article saves right away. While News is open, it attempts sync two seconds after the latest saved mark, and at most ten seconds after the first unsent one while scrolling continues. The timer can fire while the reader is open; returning to the feed requests another sync, including any pending changes.
- If a sync triggered by opening News, a buffered read, or returning from the reader finds another sync in progress, News syncs again as soon as that one ends. If it fails, News retries after 30 seconds while the page remains open. Source-edit and manual-refresh attempts do not independently schedule a retry. Pending changes are stored in SQLite, not just memory, and can be sent by a later sync. Closing the page saves queued reads and makes a best-effort sync attempt if reads are unsent; it does not guarantee completion.
- Sync is not a live push between devices. The other device applies changes on its next News or app-wide sync. A refresh also fetches feeds independently; the backend does not supply cached articles.

### What is shared

- **Sources:** title, feed and site URLs, category, enabled state, order and timestamps. Source additions, edits and deletions sync. For conflicting edits to the same source, the sync engine compares update timestamps; device clocks therefore matter. This includes deletions: a remote delete older than a local edit is ignored and the edit is pushed back. A source's ID is a hash of its feed URL and survives a later URL edit, so re-adding the old URL gets a random ID instead of overwriting the edited source. Feed fetch validators, errors and fetch times stay local.
- **Read marks:** an article key and read timestamp. The key is the existing SHA-1 hash of `source ID | feed GUID`; when the feed has no GUID, News uses its link instead. Article URLs, titles, summaries, images and bodies are not included in read-mark payloads. Matching depends on the devices seeing the same source ID and feed identity; a publisher changing its GUID or link can make an item appear new.
- Aging out after 48 hours is a local display and counting rule, not a read event sent to the backend. Explicitly opening an older article still records and syncs its read mark.
- **Local only:** cached article metadata, extracted bodies, images, and News display preferences. When a read mark arrives before its article is fetched, News stores the mark and applies it if the matching article is fetched within the retention window. Clearing cached articles keeps recent read marks and sources.

Read hashes are identifiers, not encryption or guaranteed anonymity: someone with the same feed data can calculate and compare them. Source records include URLs, and News sync payloads are not end-to-end encrypted by the app. Use a trusted backend and HTTPS as appropriate.

### Incremental sync and retention

Each installation has its own writer ID and groups read marks into eight rotating UTC-day slots. Multiple marks from the same day share a record. Reusing a slot replaces its previous contents, avoiding a separate backend record or tombstone per article. Separate writers prevent two devices reading different articles from overwriting each other's daily record. Restoring a database generates a new writer ID and carries over recent pending reads.

The first sync compares local and backend metadata. When the backend supports revision cursors, later runs request changes since the saved cursor and send locally pending records; if a cursor cannot be resumed or the backend does not provide one, the sync engine can use a full metadata pass. It pulls needed records, pushes local changes, and only marks a local record synced if it has not changed during the run. Re-enabling News sync or changing the backend URL clears the relevant saved cursors and triggers a full comparison next time.

Read-mark synchronization is limited to approximately **seven days from the read**, not the article's publication date. A device offline longer than that can miss marks or discard unsent marks; articles already marked read in its local cache remain read. The eight slots bound the **number of records per writer**, not the number of hashes in a busy day's record or the total number of writers. The generic backend is not instructed to physically delete expired slots: slots from abandoned installations or old restores can remain indefinitely, so total backend storage is not globally bounded by seven days. No backend-specific cleanup is assumed.

## Built-in catalog

On a fresh setup, **BBC Top Stories**, **NPR News**, **The Guardian World**, **The Verge**, **Hacker News**, **The Guardian Business**, **heise online**, **ScienceDaily**, **Caschys Blog**, **Managermagazin**, and **Danisch** are enabled. **Al Jazeera** is present but disabled by default. Existing source settings are not changed by the defaults; the catalog is available to all users.

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
- [Danisch](https://www.danisch.de/blog/feed/)

### Technology

- [Ars Technica](https://feeds.arstechnica.com/arstechnica/index)
- [The Verge](https://www.theverge.com/rss/index.xml)
- [Wired](https://www.wired.com/feed/rss)
- [TechCrunch](https://techcrunch.com/feed/)
- [Hacker News](https://hnrss.org/frontpage)
- [heise online](https://www.heise.de/rss/heise-atom.xml)
- [BBC Technology](https://feeds.bbci.co.uk/news/technology/rss.xml)
- [The Guardian Technology](https://www.theguardian.com/uk/technology/rss)
- [Caschys Blog](https://stadt-bremerhaven.de/feed/)
- [ComputerBase](https://www.computerbase.de/rss/news.xml)
- [Golem.de](https://rss.golem.de/rss.php?feed=RSS2.0)
- [SmartDroid](https://www.smartdroid.de/feed/)
- [mobiFlip](https://www.mobiflip.de/feed/)
- [Hackaday](https://hackaday.com/blog/feed/)
- [New York Times Technology](https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml)

### Business

- [BBC Business](https://feeds.bbci.co.uk/news/business/rss.xml)
- [The Guardian Business](https://www.theguardian.com/business/rss)
- [Financial Times](https://www.ft.com/rss/home)
- [CNBC](https://www.cnbc.com/id/100003114/device/rss/rss.html)
- [Managermagazin](https://www.manager-magazin.de/news/index.rss)

### Science

- [NASA](https://www.nasa.gov/rss/dyn/breaking_news.rss)
- [ScienceDaily](https://www.sciencedaily.com/rss/all.xml)
- [Nature](https://www.nature.com/nature.rss)
- [The Guardian Science](https://www.theguardian.com/science/rss)
- [scinexx](https://www.scinexx.de/feed/)

### Sport

- [BBC Sport](https://feeds.bbci.co.uk/sport/rss.xml)
- [The Guardian Sport](https://www.theguardian.com/sport/rss)
- [Sky Sports](https://www.skysports.com/rss/12040)

### Culture

- [The Guardian Culture](https://www.theguardian.com/culture/rss)
- [BBC Entertainment & Arts](https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml)
- [Variety](https://variety.com/feed/)
- [Rolling Stone](https://www.rollingstone.com/feed/)
- [LangweileDich.net](https://www.langweiledich.net/feed/)
- [Atlas Obscura](https://www.atlasobscura.com/feeds/latest)
- [xkcd](https://xkcd.com/rss.xml)

## Add a built-in catalog entry

Add a `NewsCatalogSource` with a publisher name, feed URL and site URL to the appropriate `byCategory` list in `news_catalog.dart`. Update this catalog list too. A new category also needs a category entry, localized labels in both ARB files, and a mapping in `news_l10n.dart`. Add entries to `seeds` only when they should be configured on first run; set `enabledByDefault: false` to seed a disabled source.
