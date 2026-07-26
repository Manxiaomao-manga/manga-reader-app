import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const _base = 'https://manga.come100.com';

const _tabs = [
  _Tab(Icons.home_rounded, '首页', '$_base/'),
  _Tab(Icons.search_rounded, '搜索', '$_base/search.php'),
  _Tab(Icons.favorite_rounded, '书库', '$_base/user/favorites.php'),
  _Tab(Icons.person_rounded, '我的', '$_base/user/settings.php'),
];

class _Tab {
  const _Tab(this.icon, this.label, this.url);
  final IconData icon;
  final String label;
  final String url;
}

// Injected at page start: spoof PWA standalone + push body down for bottom nav
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
  // Push body down so content isn't hidden behind bottom nav bar
  document.addEventListener('DOMContentLoaded', function() {
    var s = document.createElement('style');
    s.textContent = 'body{padding-bottom:72px!important}';
    document.head.appendChild(s);
  });
})();
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
  InAppWebViewController? _ctrl;
  PullToRefreshController? _ptr;
  double _progress = 1.0;

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
    _ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_tabs[i].url)));
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
                initialUrlRequest: URLRequest(url: WebUri(_tabs[0].url)),
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
                  setState(() => _progress = 1.0);
                },
                shouldOverrideUrlLoading: (c, action) async {
                  final url = action.request.url?.toString() ?? '';
                  // Keep these domains in-app
                  if (url.contains('come100.com') ||
                      url.contains('manxiaomao.com')) {
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: _switchTab,
          destinations: _tabs
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
