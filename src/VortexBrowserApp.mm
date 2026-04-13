// VortexBrowserApp.mm - Full Browser with WKWebView + Vortex Engine Integration
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <MetalKit/MetalKit.h>
#include "vortex/Engine.h"

// MARK: - VortexWebViewController
@interface VortexWebViewController : UIViewController <WKNavigationDelegate, UITextFieldDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UITextField *urlBar;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIBarButtonItem *backButton;
@property (nonatomic, strong) UIBarButtonItem *forwardButton;
@property (nonatomic, strong) UIBarButtonItem *reloadButton;
@end

@implementation VortexWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Setup URL bar at top
    [self setupURLBar];
    
    // Setup WKWebView
    [self setupWebView];
    
    // Setup toolbar at bottom
    [self setupToolbar];
    
    // Load initial page
    [self loadURL:@"https://www.google.com"];
}

- (void)setupURLBar {
    CGFloat topSafe = 0;
    if (@available(iOS 11.0, *)) {
        topSafe = self.view.safeAreaInsets.top;
    }
    
    UIView *urlBarContainer = [[UIView alloc] initWithFrame:CGRectMake(0, topSafe, self.view.bounds.size.width, 50)];
    urlBarContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    urlBarContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    urlBarContainer.tag = 100; // Tag for later reference
    
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
    CGFloat topSafe = 0;
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        topSafe = self.view.safeAreaInsets.top;
        bottomSafe = self.view.safeAreaInsets.bottom;
    }
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    
    // Enable JavaScript
    WKPreferences *prefs = [[WKPreferences alloc] init];
    prefs.javaScriptEnabled = YES;
    config.preferences = prefs;
    
    CGRect webViewFrame = CGRectMake(0, topSafe + 50, 
                                     self.view.bounds.size.width, 
                                     self.view.bounds.size.height - topSafe - 50 - 44 - bottomSafe);
    
    self.webView = [[WKWebView alloc] initWithFrame:webViewFrame configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor systemBackgroundColor];
    
    // Add progress observer
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"URL" options:NSKeyValueObservingOptionNew context:nil];
    
    [self.view addSubview:self.webView];
    
    // Setup progress bar
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.frame = CGRectMake(0, topSafe + 50, self.view.bounds.size.width, 2);
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

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat topSafe = 0;
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        topSafe = self.view.safeAreaInsets.top;
        bottomSafe = self.view.safeAreaInsets.bottom;
    }
    
    // Update frames for safe area changes
    UIView *urlBarContainer = [self.view viewWithTag:100];
    urlBarContainer.frame = CGRectMake(0, topSafe, self.view.bounds.size.width, 50);
    
    self.webView.frame = CGRectMake(0, topSafe + 50, 
                                    self.view.bounds.size.width, 
                                    self.view.bounds.size.height - topSafe - 50 - 44 - bottomSafe);
    
    self.progressBar.frame = CGRectMake(0, topSafe + 50, self.view.bounds.size.width, 2);
    
    CGFloat toolbarHeight = 44.0;
    self.toolbar.frame = CGRectMake(0, self.view.bounds.size.height - toolbarHeight - bottomSafe, 
                                    self.view.bounds.size.width, toolbarHeight);
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

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.progressBar.hidden = YES;
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

// MARK: - VortexAppDelegate
@interface VortexAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation VortexAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[Vortex] Launching Vortex Browser...");
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor systemBackgroundColor];
    
    VortexWebViewController *browserVC = [[VortexWebViewController alloc] init];
    self.window.rootViewController = browserVC;
    
    [self.window makeKeyAndVisible];
    
    NSLog(@"[Vortex] Browser ready");
    return YES;
}

@end

// MARK: - main()
int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSLog(@"[Vortex] Starting...");
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([VortexAppDelegate class]));
    }
}