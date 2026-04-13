// VortexCyberKitApp.mm - CyberKit WebKit Port Integration
// Uses custom WebKit engine instead of Apple's WKWebView

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// Try to import CyberKit headers if available
#if __has_include(<CyberKit/WKWebView.h>)
  #import <CyberKit/WKWebView.h>
  #define USE_CYBERKIT 1
  #define VORTEX_WEBVIEW CyberWebView
  typedef CyberWebView VortexWebViewClass;
#else
  #define USE_CYBERKIT 0
  #define VORTEX_WEBVIEW WKWebView
  typedef WKWebView VortexWebViewClass;
#endif

#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

@interface VortexBrowserViewController : UIViewController <WKNavigationDelegate, UITextFieldDelegate>
@property (nonatomic, strong) VortexWebViewClass *webView;
@property (nonatomic, strong) UITextField *urlBar;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIBarButtonItem *backButton;
@property (nonatomic, strong) UIBarButtonItem *forwardButton;
@property (nonatomic, strong) UIBarButtonItem *reloadButton;
@property (nonatomic, strong) UILabel *engineLabel;
@end

@implementation VortexBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Show which engine is active
    [self setupEngineIndicator];
    
    // Setup URL bar
    [self setupURLBar];
    
    // Setup WebView (CyberKit or WKWebView)
    [self setupWebView];
    
    // Setup toolbar
    [self setupToolbar];
    
    // Load initial page
    [self loadURL:@"https://www.google.com"];
}

- (void)setupEngineIndicator {
    self.engineLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];
    self.engineLabel.center = CGPointMake(self.view.bounds.size.width / 2, 30);
    self.engineLabel.textAlignment = NSTextAlignmentCenter;
    self.engineLabel.font = [UIFont boldSystemFontOfSize:12];
    self.engineLabel.alpha = 0.7;
    
#if USE_CYBERKIT
    self.engineLabel.text = @"⚡ CyberKit WebKit Engine";
    self.engineLabel.textColor = [UIColor systemGreenColor];
#else
    self.engineLabel.text = @"⚠ Fallback WKWebView";
    self.engineLabel.textColor = [UIColor systemOrangeColor];
#endif
    
    [self.view addSubview:self.engineLabel];
}

- (void)setupURLBar {
    CGFloat topSafe = 44;
    if (@available(iOS 11.0, *)) {
        topSafe = self.view.safeAreaInsets.top + 30;
    }
    
    UIView *urlBarContainer = [[UIView alloc] initWithFrame:CGRectMake(0, topSafe, self.view.bounds.size.width, 50)];
    urlBarContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    urlBarContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    self.urlBar = [[UITextField alloc] initWithFrame:CGRectMake(8, 8, self.view.bounds.size.width - 16, 34)];
    self.urlBar.borderStyle = UITextBorderStyleRoundedRect;
    self.urlBar.placeholder = @"Search or enter address";
    self.urlBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlBar.keyboardType = UIKeyboardTypeURL;
    self.urlBar.returnKeyType = UIReturnKeyGo;
    self.urlBar.delegate = self;
    self.urlBar.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.urlBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    [urlBarContainer addSubview:self.urlBar];
    [self.view addSubview:urlBarContainer];
}

- (void)setupWebView {
    CGFloat topSafe = 44;
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        topSafe = self.view.safeAreaInsets.top + 80;
        bottomSafe = self.view.safeAreaInsets.bottom;
    }
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    
    // Use CyberKit preferences if available
#if USE_CYBERKIT
    // CyberKit-specific configuration
    config.preferences.javaScriptEnabled = YES;
    // Additional CyberKit optimizations
#else
    WKPreferences *prefs = [[WKPreferences alloc] init];
    prefs.javaScriptEnabled = YES;
    config.preferences = prefs;
#endif

    CGRect webViewFrame = CGRectMake(0, topSafe, 
                                     self.view.bounds.size.width, 
                                     self.view.bounds.size.height - topSafe - 44 - bottomSafe);
    
    // Create the appropriate WebView class
    self.webView = [[VortexWebViewClass alloc] initWithFrame:webViewFrame configuration:config];
    
    // Configure navigation delegate
    self.webView.navigationDelegate = self;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor systemBackgroundColor];
    
    // Add progress observer
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"URL" options:NSKeyValueObservingOptionNew context:nil];
    
    [self.view addSubview:self.webView];
    
    // Progress bar
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.frame = CGRectMake(0, topSafe, self.view.bounds.size.width, 2);
    self.progressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.progressBar.progressTintColor = [UIColor systemBlueColor];
    self.progressBar.trackTintColor = [UIColor clearColor];
    [self.view addSubview:self.progressBar];
}

- (void)setupToolbar {
    CGFloat toolbarHeight = 44.0;
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        bottomSafe = self.view.safeAreaInsets.bottom;
    }
    CGFloat yPosition = self.view.bounds.size.height - toolbarHeight - bottomSafe;
    
    self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, yPosition, self.view.bounds.size.width, toolbarHeight)];
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    // Back button
    self.backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.backward"] 
                                                       style:UIBarButtonItemStylePlain 
                                                      target:self 
                                                      action:@selector(goBack)];
    self.backButton.enabled = NO;
    
    // Forward button
    self.forwardButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"] 
                                                          style:UIBarButtonItemStylePlain 
                                                         target:self 
                                                         action:@selector(goForward)];
    self.forwardButton.enabled = NO;
    
    // Reload button
    self.reloadButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"] 
                                                         style:UIBarButtonItemStylePlain 
                                                        target:self 
                                                        action:@selector(reload)];
    
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace 
                                                                                   target:nil 
                                                                                   action:nil];
    
    [self.toolbar setItems:@[self.backButton, flexibleSpace, self.forwardButton, flexibleSpace, self.reloadButton]];
    [self.view addSubview:self.toolbar];
}

- (void)loadURL:(NSString *)urlString {
    NSString *processedURL = urlString;
    if (![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
        if ([urlString containsString:@"."]) {
            processedURL = [NSString stringWithFormat:@"https://%@", urlString];
        } else {
            processedURL = [NSString stringWithFormat:@"https://www.google.com/search?q=%@", 
                           [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        }
    }
    
    NSURL *url = [NSURL URLWithString:processedURL];
    if (url) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
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

- (void)reload {
    [self.webView reload];
}

// MARK: - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if (textField.text.length > 0) {
        [self loadURL:textField.text];
    }
    return YES;
}

// MARK: - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.progressBar.hidden = NO;
    [self updateToolbarState];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.progressBar.hidden = YES;
    self.urlBar.text = webView.URL.absoluteString;
    [self updateToolbarState];
}

- (void)updateToolbarState {
    self.backButton.enabled = [self.webView canGoBack];
    self.forwardButton.enabled = [self.webView canGoForward];
}

// MARK: - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.progressBar.progress = self.webView.estimatedProgress;
        self.progressBar.hidden = self.webView.estimatedProgress >= 1.0;
    } else if ([keyPath isEqualToString:@"URL"]) {
        self.urlBar.text = self.webView.URL.absoluteString;
    }
}

- (void)dealloc {
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [self.webView removeObserver:self forKeyPath:@"URL"];
}

@end

// MARK: - App Delegate
@interface VortexAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation VortexAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[Vortex] Launching with CyberKit integration...");
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    VortexBrowserViewController *browserVC = [[VortexBrowserViewController alloc] init];
    self.window.rootViewController = browserVC;
    
    [self.window makeKeyAndVisible];
    
    NSLog(@"[Vortex] Browser ready");
    return YES;
}

@end

// MARK: - main()
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([VortexAppDelegate class]));
    }
}