import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/x_feed/api/x_web_config.dart';

const _base = 'https://abs.twimg.com/responsive-web/client-web/';

// The shape of x.com's logged-in page: named scripts plus webpack's chunk map.
const _html =
    '<script src="${_base}vendor.aaa.js"></script>'
    '<script src="${_base}i18n/de.bbb.js"></script>'
    '<script src="${_base}main.ccc.js"></script>'
    '<script>t.u=e=>(({11:"bundle.Explore",22:"bundle.HomeTimeline",'
    '33:"shared~bundle.BookmarkFolders~bundle.Bookmarks",44:"ondemand.s"})'
    '[e]||e)+"."+({11:"e1",22:"h2",33:"b3",44:"o4"})[e]+"a.js"</script>';

void main() {
  test('scans main first, then the chunks holding the timelines', () {
    expect(XWebConfig.scriptCandidates(_html), [
      '${_base}main.ccc.js',
      '${_base}bundle.HomeTimeline.h2a.js',
      '${_base}shared~bundle.BookmarkFolders~bundle.Bookmarks.b3a.js',
    ]);
  });

  test('a page without the old client yields nothing to scan', () {
    const loggedOut =
        '<script src="https://abs.twimg.com/x-web/x-web/entry-client-logged-out-x.js">';
    expect(XWebConfig.scriptCandidates(loggedOut), isEmpty);
  });
}
