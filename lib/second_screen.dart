import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'constants.dart';

class SecondScreen extends StatelessWidget {
  final String firebaseToken;
  const SecondScreen(this.firebaseToken, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
          title: 'Teco Guiding students through community college',
          firebase: firebaseToken),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.firebase});

  final String title;
  final String firebase;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isLoading = true;
  double loadingProgress = 0;
  bool isOffline = false;
  bool hasError = false;
  String errorMessage = '';
  bool isRetrying = false;
  bool showDebugInfo = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late final WebViewController _controller;

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  void initState() {
    super.initState();
    
    _checkConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        isOffline = results.contains(ConnectivityResult.none);
      });
    });

    String webUrl = _getWebUrl();

    // #docregion platform_features
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller
      ..setUserAgent(AppConstants.userAgent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              loadingProgress = progress / 100;
              isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              hasError = false;
              isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            if (!hasError) {
              setState(() {
                isLoading = false;
                loadingProgress = 1.0;
                isRetrying = false;
              });

              // Inject JavaScript to automatically convert PDF object/embed/iframe tags to Google Docs Viewer
              try {
                await _controller.runJavaScript('''
                  (function() {
                    function convertPDFs() {
                      // 1. Target <object> tags pointing to PDFs or S3 documents
                      var objects = document.querySelectorAll('object[type="application/pdf"], object[data*=".pdf"], object[data*="amazonaws.com"]');
                      objects.forEach(function(obj) {
                        var pdfUrl = obj.getAttribute('data');
                        if (pdfUrl && !pdfUrl.includes('docs.google.com')) {
                          console.log('TECO_PDF: Converting object tag to iframe. URL:', pdfUrl);
                          var iframe = document.createElement('iframe');
                          iframe.src = 'https://docs.google.com/gview?embedded=true&url=' + encodeURIComponent(pdfUrl);
                          iframe.style.width = '100%';
                          iframe.style.height = '100%';
                          iframe.style.border = 'none';
                          iframe.className = obj.className;
                          if (obj.id) iframe.id = obj.id;
                          obj.parentNode.replaceChild(iframe, obj);
                        }
                      });

                      // 2. Target <embed> tags pointing to PDFs or S3 documents
                      var embeds = document.querySelectorAll('embed[type="application/pdf"], embed[src*=".pdf"], embed[src*="amazonaws.com"]');
                      embeds.forEach(function(emb) {
                        var pdfUrl = emb.getAttribute('src');
                        if (pdfUrl && !pdfUrl.includes('docs.google.com')) {
                          console.log('TECO_PDF: Converting embed tag to iframe. URL:', pdfUrl);
                          var iframe = document.createElement('iframe');
                          iframe.src = 'https://docs.google.com/gview?embedded=true&url=' + encodeURIComponent(pdfUrl);
                          iframe.style.width = '100%';
                          iframe.style.height = '100%';
                          iframe.style.border = 'none';
                          iframe.className = emb.className;
                          if (emb.id) iframe.id = emb.id;
                          emb.parentNode.replaceChild(iframe, emb);
                        }
                      });

                      // 3. Target <iframe> tags pointing directly to PDFs or S3 documents
                      var iframes = document.querySelectorAll('iframe');
                      iframes.forEach(function(ifr) {
                        var src = ifr.getAttribute('src');
                        if (src && (src.toLowerCase().includes('.pdf') || src.includes('amazonaws.com')) && !src.includes('docs.google.com')) {
                          console.log('TECO_PDF: Converting iframe source. URL:', src);
                          ifr.src = 'https://docs.google.com/gview?embedded=true&url=' + encodeURIComponent(src);
                        }
                      });
                    }

                    // Run immediately
                    convertPDFs();

                    // Run periodically to catch dynamic updates in SPAs
                    if (!window.tecoPdfIntervalRegistered) {
                      window.tecoPdfIntervalRegistered = true;
                      setInterval(convertPDFs, 1000);
                    }
                  })();
                ''');
              } catch (e) {
                // Ignore JavaScript execution errors during load transition
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                hasError = true;
                errorMessage = error.description;
                isLoading = false;
                isRetrying = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final fUrl = Uri.parse(request.url);
            
            bool isInternal = AppConstants.internalDomains.any(
              (domain) => request.url.contains(domain)
            );

            if (isInternal) {
              return NavigationDecision.navigate;
            }

            // Handle external links and protocols
            _launchInBrowser(fUrl);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse(webUrl));

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);


      (controller.platform as AndroidWebViewController).setOnShowFileSelector(
        (FileSelectorParams params) async {
          try {
            final FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: AppConstants.allowedExtensions,
            );

            if (result != null && result.files.single.path != null) {
              return [Uri.file(result.files.single.path!).toString()];
            }
          } catch (e) {
            // Log or handle error
          }
          return [];
        },
      );
    }
    // #enddocregion platform_features

    _controller = controller;
  }

  String _getWebUrl() {
    String webUrl = "${AppConstants.webUrl}?device_type=mobile&firebaseToken=";
    if (widget.firebase.isNotEmpty) {
      webUrl = "${AppConstants.webUrl}?device_type=mobile&firebaseToken=${widget.firebase}";
    }
    return webUrl;
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    setState(() {
      isOffline = results.contains(ConnectivityResult.none);
    });
  }

  Future<void> _handleReload() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    await _checkConnectivity();
    if (!isOffline) {
      await _controller.reload();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _handleRetry() async {
    if (isRetrying) return;
    
    setState(() {
      isRetrying = true;
      isLoading = true;
      hasError = false;
    });

    // 1. Check physical connection status
    await _checkConnectivity();

    // 2. Perform a real active socket verification to bypass connection transitions/lags
    bool hasRealInternet = false;
    String statusMessage = '';
    
    try {
      final lookupResults = await InternetAddress.lookup('stage.tecoguide.com')
          .timeout(const Duration(seconds: 3));
      if (lookupResults.isNotEmpty && lookupResults[0].rawAddress.isNotEmpty) {
        hasRealInternet = true;
      }
    } on SocketException catch (_) {
      hasRealInternet = false;
      statusMessage = 'Internet unreachable. Please verify your connection.';
    } on ArgumentError catch (_) {
      hasRealInternet = false;
    } catch (_) {
      hasRealInternet = false;
      statusMessage = 'Connection timed out. Please try again.';
    }

    // 3. Fallback: Check google.com to distinguish between overall offline vs. only staging server issues
    if (!hasRealInternet) {
      try {
        final lookupResults = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        if (lookupResults.isNotEmpty && lookupResults[0].rawAddress.isNotEmpty) {
          hasRealInternet = true;
          statusMessage = 'Staging server is unreachable. Please try again later.';
        }
      } catch (_) {}
    }

    if (!hasRealInternet) {
      // Device is genuinely offline or DNS is not ready yet
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        isOffline = true;
        isRetrying = false;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusMessage.isNotEmpty 
                        ? statusMessage 
                        : 'Connection failed. Internet access is not ready yet.',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 4. Internet is fully working! Reset flags, clear cache, and reload request
    setState(() {
      isOffline = false;
      hasError = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text(
                'Internet restored! Connecting...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      await _controller.clearCache();
    } catch (_) {}

    await _controller.loadRequest(Uri.parse(_getWebUrl()));
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: (isOffline || hasError)
              ? _buildErrorOrOfflineScreen()
              : Stack(
                  children: <Widget>[
                    RefreshIndicator(
                      onRefresh: () => _handleReload(),
                      child: WebViewWidget(controller: _controller),
                    ),
                    if (isLoading)
                      Container(
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/ic_logo_border.png',
                                width: 120,
                                height: 120,
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 48),
                                child: LinearProgressIndicator(
                                  value: loadingProgress,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildErrorOrOfflineScreen() {
    final bool offline = isOffline;
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Branded Logo Circle with soft pulse glow effect
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.asset(
                    'assets/ic_logo_border.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Premium Card Containing Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.04),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Visual Indicator Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: offline 
                            ? const Color(0xFFEFF6FF) 
                            : const Color(0xFFFFF1F2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        offline 
                            ? Icons.wifi_off_rounded 
                            : Icons.cloud_off_rounded,
                        size: 40,
                        color: offline 
                            ? const Color(0xFF2563EB) 
                            : const Color(0xFFE11D48),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Headline
                    Text(
                      offline ? 'No Internet Connection' : 'Connection Failed',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Description
                    Text(
                      offline
                          ? 'Please check your connection and try again. We will be waiting right here.'
                          : 'We are having trouble connecting to Teco Guide. Our servers might be undergoing maintenance.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    
                    // Debug info container if error occurs
                    if (!offline && hasError && errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          onExpansionChanged: (expanded) {
                            setState(() {
                              showDebugInfo = expanded;
                            });
                          },
                          title: Text(
                            showDebugInfo ? 'Hide Technical Details' : 'Show Technical Details',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          iconColor: const Color(0xFF94A3B8),
                          collapsedIconColor: const Color(0xFF94A3B8),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                errorMessage,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFFF1F5F9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Animated / Micro-interactive primary button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isRetrying
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: isRetrying ? Colors.blue[300] : null,
                    boxShadow: isRetrying
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.24),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: isRetrying ? null : _handleRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isRetrying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Retry Connection',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtle Footer Brand/Version Note
              const Text(
                'Teco Guide v6.9.5',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
