#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Use CYBERKIT_ENABLED macro from compiler (-DCYBERKIT_ENABLED=1)
// __has_include doesn't work reliably with -F framework paths
#if CYBERKIT_ENABLED
    #import <CyberKit/CyberKit.h>
    #define USE_CYBERKIT 1
    #define WEBVIEW_CLASS CyberWebView
    #define WEBVIEW_CONFIGURATION CyberWebViewConfiguration
    #define WEBVIEW_UIDELEGATE CyberWebUIDelegate
    #define WEBVIEW_NAVIGATIONDELEGATE CyberWebNavigationDelegate
    #define WEBVIEW_NAVIGATION CyberWebNavigation
#else
    #import <WebKit/WebKit.h>
    #define USE_CYBERKIT 0
    #define WEBVIEW_CLASS WKWebView
    #define WEBVIEW_CONFIGURATION WKWebViewConfiguration
    #define WEBVIEW_UIDELEGATE WKUIDelegate
    #define WEBVIEW_NAVIGATIONDELEGATE WKNavigationDelegate
    #define WEBVIEW_NAVIGATION WKNavigation
#endif

// MARK: - VortexWebViewController
@interface VortexWebViewController : UIViewController <UITextFieldDelegate, WEBVIEW_UIDELEGATE, WEBVIEW_NAVIGATIONDELEGATE>
@property (nonatomic, strong) WEBVIEW_CLASS *webView;
@property (nonatomic, strong) UITextField *urlBar;
@property (nonatomic, strong) UIView *toolbar;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *forwardButton;
@property (nonatomic, strong) UIButton *reloadButton;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation VortexWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"[Vortex] viewDidLoad");
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupURLBar];
    [self setupToolbar];
    [self setupWebView];
    [self setupProgressBar];
    [self setupStatusLabel];
    
    [self layoutSubviews];
    
    // Load initial page
    [self navigateToURL:@"https://www.google.com"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"[Vortex] viewDidAppear");
}

- (void)setupURLBar {
    self.urlBar = [[UITextField alloc] init];
    self.urlBar.borderStyle = UITextBorderStyleRoundedRect;
    self.urlBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.urlBar.keyboardType = UIKeyboardTypeURL;
    self.urlBar.returnKeyType = UIReturnKeyGo;
    self.urlBar.placeholder = @"Enter URL or search";
    self.urlBar.delegate = self;
    self.urlBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.urlBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.urlBar];
}

- (void)setupToolbar {
    self.toolbar = [[UIView alloc] init];
    self.toolbar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Back button
    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.backButton setTitle:@"<" forState:UIControlStateNormal];
    self.backButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [self.backButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    self.backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar addSubview:self.backButton];
    
    // Forward button
    self.forwardButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.forwardButton setTitle:@">" forState:UIControlStateNormal];
    self.forwardButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [self.forwardButton addTarget:self action:@selector(goForward) forControlEvents:UIControlEventTouchUpInside];
    self.forwardButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar addSubview:self.forwardButton];
    
    // Reload button
    self.reloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.reloadButton setTitle:@"↻" forState:UIControlStateNormal];
    self.reloadButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [self.reloadButton addTarget:self action:@selector(reloadPage) forControlEvents:UIControlEventTouchUpInside];
    self.reloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar addSubview:self.reloadButton];
    
    [self.view addSubview:self.toolbar];
}

- (void)setupWebView {
    NSLog(@"[Vortex] Setting up WebView...");
    
    WEBVIEW_CONFIGURATION *config = [[WEBVIEW_CONFIGURATION alloc] init];
    
#if USE_CYBERKIT
    NSLog(@"[Vortex] Using REAL CyberKit WebKit");
#else
    NSLog(@"[Vortex] Using system WebKit (CyberKit not available)");
#endif
    
    self.webView = [[WEBVIEW_CLASS alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.webView];
    
    // Add observers
    @try {
        [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
        [self.webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
    } @catch (NSException *exception) {
        NSLog(@"[Vortex] Warning: Could not add observer: %@", exception);
    }
}

- (void)setupProgressBar {
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressBar.progress = 0.0;
    self.progressBar.progressTintColor = [UIColor systemBlueColor];
    [self.view addSubview:self.progressBar];
}

- (void)setupStatusLabel {
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:10];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
#if USE_CYBERKIT
    self.statusLabel.text = @"CyberKit WebKit | iOS 16+";
#else
    self.statusLabel.text = @"System WebKit | iOS 16+";
#endif
    
    [self.view addSubview:self.statusLabel];
}

- (void)layoutSubviews {
    CGFloat statusBarHeight = 44.0;
    CGFloat toolbarHeight = 50.0;
    CGFloat urlBarHeight = 36.0;
    CGFloat progressBarHeight = 2.0;
    CGFloat statusLabelHeight = 16.0;
    
    [NSLayoutConstraint activateConstraints:@[
        // URL Bar
        [self.urlBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.urlBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.urlBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [self.urlBar.heightAnchor constraintEqualToConstant:urlBarHeight],
        
        // Toolbar
        [self.toolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.toolbar.heightAnchor constraintEqualToConstant:toolbarHeight],
        
        // Toolbar buttons
        [self.backButton.leadingAnchor constraintEqualToAnchor:self.toolbar.leadingAnchor constant:30],
        [self.backButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.forwardButton.leadingAnchor constraintEqualToAnchor:self.backButton.trailingAnchor constant:50],
        [self.forwardButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.reloadButton.leadingAnchor constraintEqualToAnchor:self.forwardButton.trailingAnchor constant:50],
        [self.reloadButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        
        // Progress bar under URL bar
        [self.progressBar.topAnchor constraintEqualToAnchor:self.urlBar.bottomAnchor constant:4],
        [self.progressBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.progressBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.progressBar.heightAnchor constraintEqualToConstant:progressBarHeight],
        
        // Status label
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.progressBar.bottomAnchor constant:2],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.statusLabel.heightAnchor constraintEqualToConstant:statusLabelHeight],
        
        // WebView
        [self.webView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:4],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.toolbar.topAnchor]
    ]];
}

- (void)navigateToURL:(NSString *)urlString {
    NSString *trimmed = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([trimmed length] == 0) {
        return;
    }
    
    NSURL *url;
    if ([trimmed hasPrefix:@"http://"] || [trimmed hasPrefix:@"https://"]) {
        url = [NSURL URLWithString:trimmed];
    } else if ([trimmed containsString:@" "] || ![trimmed containsString:@"."]) {
        NSString *searchQuery = [trimmed stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *googleURL = [NSString stringWithFormat:@"https://www.google.com/search?q=%@", searchQuery];
        url = [NSURL URLWithString:googleURL];
    } else {
        NSString *fullURL = [NSString stringWithFormat:@"https://%@", trimmed];
        url = [NSURL URLWithString:fullURL];
    }
    
    if (url) {
        NSLog(@"[Vortex] Loading: %@", url.absoluteString);
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
        self.urlBar.text = trimmed;
    }
}

- (void)goBack {
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    }
}

- (void)goForward {
    if ([self.webView canGoForward]) {
        [self.webView goForward];
    }
}

- (void)reloadPage {
    [self.webView reload];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self navigateToURL:textField.text];
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressBar.progress = self.webView.estimatedProgress;
            self.progressBar.hidden = (self.webView.estimatedProgress >= 1.0);
        });
    } else if ([keyPath isEqualToString:@"title"]) {
        self.title = self.webView.title;
    }
}

#pragma mark - WebView Delegates

#if USE_CYBERKIT
- (void)cyberWebView:(CyberWebView *)webView didStartProvisionalNavigation:(CyberWebNavigation *)navigation {
    NSLog(@"[Vortex] CyberKit: Started loading");
    self.progressBar.hidden = NO;
    self.progressBar.progress = 0.1;
}

- (void)cyberWebView:(CyberWebView *)webView didFinishNavigation:(CyberWebNavigation *)navigation {
    NSLog(@"[Vortex] CyberKit: Finished loading");
    self.progressBar.hidden = YES;
    self.urlBar.text = webView.URL.absoluteString;
}

- (void)cyberWebView:(CyberWebView *)webView didFailNavigation:(CyberWebNavigation *)navigation withError:(NSError *)error {
    NSLog(@"[Vortex] CyberKit: Failed - %@", error.localizedDescription);
    self.progressBar.hidden = YES;
}
#else
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"[Vortex] WebKit: Started loading");
    self.progressBar.hidden = NO;
    self.progressBar.progress = 0.1;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"[Vortex] WebKit: Finished loading");
    self.progressBar.hidden = YES;
    self.urlBar.text = webView.URL.absoluteString;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"[Vortex] WebKit: Failed - %@", error.localizedDescription);
    self.progressBar.hidden = YES;
}
#endif

- (void)dealloc {
    @try {
        [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
        [self.webView removeObserver:self forKeyPath:@"title"];
    } @catch (NSException *exception) {
        // Ignore
    }
}

@end