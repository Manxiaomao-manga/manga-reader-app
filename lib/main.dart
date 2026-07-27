import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// Domain failover list (in priority order). If the primary domain becomes
// unreachable (DNS block, DDoS, outage), the app automatically retries the
// same page on the next domain instead of leaving the user stuck on a
// browser error page — all 3 domains serve the identical site.
const _domains = ['go-now.uk', 'come100.com', 'manxiaomao.com'];

const _tabPaths = [
  _TabDef(Icons.home_rounded, '首页', '/'),
  _TabDef(Icons.category_rounded, '分类', '/category.php'),
  _TabDef(Icons.collections_bookmark_rounded, '书架', '/user/library.php'),
  _TabDef(Icons.person_rounded, '我的', '/user/settings.php'),
];

class _TabDef {
  const _TabDef(this.icon, this.label, this.path);
  final IconData icon;
  final String label;
  final String path;
}

// Reader page URL shape: /manga/{slug}/{chapter} (two path segments).
// Detail page is /manga/{slug} (one segment) — used to tell them apart.
final _readerPathRe = RegExp(r'^/manga/[^/]+/[^/]+/?$');

// Injected at page start: spoof PWA standalone, hide login/register + footer
// (redundant in-app: bottom nav has 我的 tab; footer is unnecessary chrome),
// and pad body for the bottom nav bar only on non-reader pages.
const _initJs = r'''
(function() {
  // Spoof matchMedia so offline download UI shows in App
  var _om = window.matchMedia ? window.matchMedia.bind(window) : null;
  window.matchMedia = function(q) {
    if (q === '(display-mode: standalone)') {
      return { matches: true, media: q, onchange: null,
        addListener: function(){}, removeListener: function(){},
        addEventListener: function(){}, removeEventListener: function(){},
        dispatchEvent: function(){ return false; } };
    }
    return _om ? _om(q) : { matches: false };
  };
  document.addEventListener('DOMContentLoaded', function() {
    var isReader = /^\/manga\/[^\/]+\/[^\/]+\/?$/.test(location.pathname);
    var isHome = location.pathname === '/' || location.pathname === '/index.php';
    var s = document.createElement('style');
    // Scoped to .site-header so in-page links (e.g. login.php's own
    // "没有账号？注册" link) aren't affected — only the top nav bar buttons.
    s.textContent =
      '.site-header a[href="/user/login.php"],' +
      '.site-header a[href="/user/register.php"],' +
      '.site-footer{display:none!important}' +
      (isReader ? '' : 'body{padding-bottom:72px!important}') +
      (isHome ? '' : '.site-header{display:none!important}');
    document.head.appendChild(s);
  });
})();
''';

// Shown locally (no network needed) when every domain in the failover list
// has failed — i.e. the device has no connectivity at all, not just a
// single domain being blocked. The retry link is intercepted in
// shouldOverrideUrlLoading rather than doing a real network navigation.
const _offlineHtml = '''
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body{background:#0f0f23;color:#f0eef8;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
  display:flex;align-items:center;justify-content:center;min-height:100vh;text-align:center;padding:2rem;margin:0}
.icon{font-size:3.2rem;margin-bottom:1rem}
h2{font-size:1.1rem;margin-bottom:.6rem}
p{color:#8888aa;font-size:.85rem;line-height:1.7;margin-bottom:1.5rem}
a.btn{display:inline-block;background:linear-gradient(135deg,#e8645a,#7c6af7);color:#fff;border:none;
  border-radius:8px;padding:.65rem 1.8rem;font-size:.9rem;font-weight:600;text-decoration:none;font-family:inherit}
</style></head>
<body><div>
<div class="icon">📴</div>
<h2>目前没有网络连接</h2>
<p>请检查手机网络或 Wi-Fi 后重试。<br>已下载的离线章节仍可在「书架」中阅读。</p>
<a class="btn" href="app://retry">🔄 重试</a>
</div></body></html>
''';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF141428),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MangaApp());
}

class MangaApp extends StatelessWidget {
  const MangaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '漫小猫',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0f0f23),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7c6af7),
          surface: Color(0xFF141428),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF141428),
          indicatorColor: const Color(0xFF7c6af7).withOpacity(0.2),
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          height: 64,
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _idx = 0;
  int _domainIdx = 0;
  InAppWebViewController? _ctrl;
  PullToRefreshController? _ptr;
  double _progress = 1.0;
  bool _isReaderPage = false;
  bool _failoverBusy = false;

  String get _currentBase => 'https://manga.${_domains[_domainIdx]}';
  String _tabUrl(int i) => _currentBase + _tabPaths[i].path;

  void _updateReaderState(Uri? url) {
    final isReader = url != null && _readerPathRe.hasMatch(url.path);
    if (isReader != _isReaderPage) {
      setState(() => _isReaderPage = isReader);
    }
  }

  @override
  void initState() {
    super.initState();
    _ptr = PullToRefreshController(
      settings: PullToRefreshSettings(color: const Color(0xFF7c6af7)),
      onRefresh: () async => await _ctrl?.reload(),
    );
  }

  @override
  void dispose() {
    _ptr?.dispose();
    super.dispose();
  }

  void _switchTab(int i) {
    setState(() => _idx = i);
    _ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_tabUrl(i))));
  }

  // Retry the same path on the next domain in the failover list. Keeps the
  // user on whatever page they were trying to reach instead of bouncing
  // them back to the home tab. Once every domain has failed, that means
  // there's no connectivity at all — show a local (no-network-needed) page
  // instead of leaving Android's native "web page not available" screen up.
  void _failoverTo(Uri failedUrl) {
    if (_failoverBusy) return;
    if (_domainIdx >= _domains.length - 1) {
      _ctrl?.loadData(data: _offlineHtml, mimeType: 'text/html', encoding: 'utf8');
      return;
    }
    _failoverBusy = true;
    _domainIdx++;
    final retryUri = failedUrl.replace(host: 'manga.${_domains[_domainIdx]}');
    _ctrl
        ?.loadUrl(urlRequest: URLRequest(url: WebUri(retryUri.toString())))
        .whenComplete(() => _failoverBusy = false);
  }

  // User tapped "retry" on the local offline page: start over from the
  // primary domain rather than staying stuck on whichever domain failed last.
  void _retryFromScratch() {
    _domainIdx = 0;
    _ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_tabUrl(_idx))));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _ctrl?.canGoBack() ?? false) {
          await _ctrl?.goBack();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_tabUrl(0))),
                pullToRefreshController: _ptr,
                initialUserScripts: UnmodifiableListView([
                  UserScript(
                    source: _initJs,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                  builtInZoomControls: false,
                  supportZoom: true,
                  mixedContentMode:
                      MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                  mediaPlaybackRequiresUserGesture: false,
                  allowFileAccess: true,
                  cacheMode: CacheMode.LOAD_DEFAULT,
                  userAgent:
                      'Mozilla/5.0 (Linux; Android 12; Mobile) '
                      'AppleWebKit/537.36 (KHTML, like Gecko) '
                      'Chrome/120.0.0.0 Mobile Safari/537.36 '
                      'MangaXiaomaoApp/2.0',
                ),
                onWebViewCreated: (c) => _ctrl = c,
                onLoadStart: (c, url) => setState(() => _progress = 0.05),
                onProgressChanged: (c, p) {
                  setState(() => _progress = p / 100);
                  if (p == 100) _ptr?.endRefreshing();
                },
                onLoadStop: (c, url) {
                  _ptr?.endRefreshing();
                  _updateReaderState(url);
                  setState(() => _progress = 1.0);
                },
                onReceivedError: (c, request, error) {
                  // Only fail over on the main page request, not a broken
                  // sub-resource (image/script) — and only for genuine
                  // connectivity errors (DNS/timeout/unreachable), which is
                  // exactly what onReceivedError represents (HTTP status
                  // errors like 404/500 go through onReceivedHttpError).
                  if (request.isForMainFrame ?? true) {
                    _failoverTo(request.url);
                  }
                },
                onUpdateVisitedHistory: (c, url, reload) =>
                    _updateReaderState(url),
                shouldOverrideUrlLoading: (c, action) async {
                  final url = action.request.url?.toString() ?? '';
                  if (url == 'app://retry') {
                    _retryFromScratch();
                    return NavigationActionPolicy.CANCEL;
                  }
                  // Keep known site domains in-app
                  if (_domains.any((d) => url.contains(d))) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  // Everything else: allow (system handles tel: mailto: etc.)
                  return NavigationActionPolicy.ALLOW;
                },
              ),
              if (_progress < 1.0)
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  color: const Color(0xFF7c6af7),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _isReaderPage
            ? null
            : NavigationBar(
                selectedIndex: _idx,
                onDestinationSelected: _switchTab,
                destinations: _tabPaths
                    .map((t) => NavigationDestination(
                          icon: Icon(t.icon, size: 22),
                          label: t.label,
                        ))
                    .toList(),
              ),
      ),
    );
  }
}
