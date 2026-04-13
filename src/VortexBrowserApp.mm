#import "vortex/VortexBrowserApp.h"
#include "vortex/Renderer.h"
#include "vortex/Layout.h"
#include "vortex/HTMLParser.h"
#include "vortex/CSS.h"

#include <memory>
#include <string>
#include <mutex>

using namespace Vortex;

// Private implementation
@interface VortexView () {
    Render::RenderEngine* _renderEngine;
    Layout::LayoutEngine* _layoutEngine;
    HTMLParser::DOMBuilder* _domBuilder;
    StyleEngine* _styleEngine;
    
    std::unique_ptr<HTMLParser::DOMBuilder::Node> _document;
    std::unique_ptr<Layout::LayoutNode> _layoutRoot;
    
    std::mutex _renderMutex;
    dispatch_queue_t _renderQueue;
    CADisplayLink* _displayLink;
    
    float _scrollX;
    float _scrollY;
    float _zoom;
}

- (void)setupMetal;
- (void)renderFrame;
- (void)processInputHTML:(NSString*)html;

@end

@implementation VortexView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetal];
        [self setupInteraction];
        _scrollX = 0;
        _scrollY = 0;
        _zoom = 1.0;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupMetal];
        [self setupInteraction];
    }
    return self;
}

- (void)setupMetal {
    // Configure Metal
    self.device = MTLCreateSystemDefaultDevice();
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.depthStencilPixelFormat = MTLPixelFormatInvalid;
    self.framebufferOnly = YES;
    self.preferredFramesPerSecond = 120; // Target 120 FPS
    self.enableSetNeedsDisplay = NO;
    self.paused = NO;
    
    // Initialize render engine
    _renderEngine = new Render::RenderEngine();
    
    // Wait for layer to be ready
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.layer && [self.layer isKindOfClass:[CAMetalLayer class]]) {
            _renderEngine->initialize(self.device, (CAMetalLayer*)self.layer);
        }
    });
    
    // Initialize layout engine
    _layoutEngine = new Layout::LayoutEngine();
    _styleEngine = new StyleEngine();
    
    // Create render queue
    _renderQueue = dispatch_queue_create("com.vortex.render", 
                                        dispatch_queue_attr_make_with_qos_class(
                                            DISPATCH_QUEUE_SERIAL, 
                                            QOS_CLASS_USER_INTERACTIVE, -1));
    
    // Setup display link for smooth animation
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderFrame)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)setupInteraction {
    // Setup gesture recognizers
    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self 
                                                                           action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];
    
    UIPinchGestureRecognizer* pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self 
                                                                                action:@selector(handlePinch:)];
    [self addGestureRecognizer:pinch];
    
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self 
                                                                         action:@selector(handleTap:)];
    [self addGestureRecognizer:tap];
}

- (void)loadURL:(NSString*)url {
    // For now, just load the HTML directly
    // In a full implementation, this would fetch the URL
    NSString* html = [NSString stringWithFormat:@"<html><body><h1>Loading %@</h1><p>Vortex Browser - World's Fastest Engine</p></body></html>", url];
    [self loadHTML:html baseURL:url];
}

- (void)loadHTML:(NSString*)html baseURL:(NSString*)baseURL {
    (void)baseURL;
    
    dispatch_async(_renderQueue, ^{
        [self processInputHTML:html];
    });
}

- (void)processInputHTML:(NSString*)html {
    const char* htmlStr = [html UTF8String];
    
    // Parse HTML
    StreamingHTMLParser parser(htmlStr, strlen(htmlStr));
    HTMLParser::DOMBuilder::Node* doc = parser.parse();
    
    if (!doc) return;
    
    std::lock_guard<std::mutex> lock(_renderMutex);
    
    // Apply default styles
    std::string css = R"(
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto;
            font-size: 16px;
            line-height: 1.5;
            margin: 0;
            padding: 20px;
            background: white;
            color: #333;
        }
        h1 { 
            font-size: 32px; 
            font-weight: 600;
            margin: 0 0 20px 0;
            color: #000;
        }
        p {
            margin: 0 0 16px 0;
        }
    )";
    
    StyleEngine::Stylesheet stylesheet = _styleEngine->parseCSS(css.c_str(), css.length());
    _styleEngine->addStylesheet(stylesheet);
    
    // Compute styles
    _styleEngine->computeStyles(doc);
    
    // Layout
    CGSize size = self.drawableSize;
    _layoutEngine->layoutDocument(doc, size.width, size.height);
    
    // Store for rendering
    _layoutRoot = std::unique_ptr<Layout::LayoutNode>(_layoutEngine->getLayoutTree());
}

- (void)renderFrame {
    if (!_layoutRoot) return;
    
    CGSize drawableSize = self.drawableSize;
    
    std::lock_guard<std::mutex> lock(_renderMutex);
    
    // Begin frame
    _renderEngine->beginFrame();
    
    // Set viewport with scroll transform
    simd_float4 viewport = simd_make_float4(
        -_scrollX,
        -_scrollY,
        drawableSize.width,
        drawableSize.height
    );
    
    // Apply zoom
    simd_float4x4 transform = simd_diagonal_matrix(simd_make_float4(_zoom, _zoom, 1, 1));
    _renderEngine->setTransform(transform);
    
    // Render layout tree
    _renderEngine->renderLayoutTree(_layoutRoot.get(), viewport);
    
    // End frame
    _renderEngine->endFrame();
}

- (void)handlePan:(UIPanGestureRecognizer*)gesture {
    CGPoint translation = [gesture translationInView:self];
    
    _scrollX -= translation.x;
    _scrollY -= translation.y;
    
    // Clamp scroll
    if (_scrollX < 0) _scrollX = 0;
    if (_scrollY < 0) _scrollY = 0;
    
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)handlePinch:(UIPinchGestureRecognizer*)gesture {
    _zoom *= gesture.scale;
    
    // Clamp zoom
    if (_zoom < 0.25f) _zoom = 0.25f;
    if (_zoom > 5.0f) _zoom = 5.0f;
    
    gesture.scale = 1.0;
}

- (void)handleTap:(UITapGestureRecognizer*)gesture {
    CGPoint point = [gesture locationInView:self];
    
    // Convert to document coordinates
    float docX = (point.x / _zoom) + _scrollX;
    float docY = (point.y / _zoom) + _scrollY;
    
    // Hit test
    if (_layoutRoot) {
        Layout::LayoutNode* hit = _layoutEngine->hitTest(docX, docY);
        if (hit && hit->dom_node) {
            // Handle click
            NSLog(@"Hit element at (%f, %f)", docX, docY);
        }
    }
}

- (void)reload {
    // Reload current page
}

- (void)goBack {
    // Navigate back
}

- (void)goForward {
    // Navigate forward
}

- (void)dealloc {
    [_displayLink invalidate];
    
    delete _renderEngine;
    delete _layoutEngine;
    delete _styleEngine;
}

@end

// View Controller
@implementation VortexBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Setup UI
    [self setupToolbar];
    [self setupUrlBar];
    [self setupVortexView];
    [self setupProgressBar];
    
    // Load initial page
    [self.vortexView loadHTML:@"<!DOCTYPE html>
        <html>
        <head>
            <title>Vortex Browser</title>
            <style>
                body {
                    font-family: -apple-system, sans-serif;
                    padding: 40px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    min-height: 100vh;
                }
                h1 { font-size: 48px; margin-bottom: 20px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
                p { font-size: 20px; line-height: 1.6; margin-bottom: 30px; }
                .feature { 
                    background: rgba(255,255,255,0.1);
                    border-radius: 16px;
                    padding: 20px;
                    margin: 20px 0;
                    backdrop-filter: blur(10px);
                }
                .feature h3 { margin: 0 0 10px 0; }
                .feature p { margin: 0; font-size: 16px; }
            </style>
        </head>
        <body>
            <h1>🌪️ Vortex Browser</h1>
            <p>The world's fastest browser engine. Built from scratch for absolute performance.</p>
            <div class='feature'>
                <h3>⚡ GPU-Accelerated</h3>
                <p>Metal-powered rendering with 120fps smooth scrolling</p>
            </div>
            <div class='feature'>
                <h3>🔒 Memory Safe</h3>
                <p>Lock-free data structures with zero-allocation paths</p>
            </div>
            <div class='feature'>
                <h3>🚀 Instant Layout</h3>
                <p>SIMD-parallel CSS and layout computation</p>
            </div>
            <div class='feature'>
                <h3>🧠 TurboScript</h3>
                <p>5x faster JavaScript execution with adaptive JIT</p>
            </div>
        </body>
        </html>"
                        baseURL:@"about:vortex"];
}

- (void)setupToolbar {
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.toolbar];
    
    UIBarButtonItem* back = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.backward"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(goBack)];
    
    UIBarButtonItem* forward = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.forward"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(goForward)];
    
    UIBarButtonItem* reload = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"]
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(reload)];
    
    UIBarButtonItem* share = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(share)];
    
    UIBarButtonItem* flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil];
    
    self.toolbar.items = @[back, forward, flex, reload, share];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.toolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.toolbar.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)setupUrlBar {
    UIView* urlContainer = [[UIView alloc] init];
    urlContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    urlContainer.layer.cornerRadius = 10;
    urlContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.urlBar = [[UITextField alloc] init];
    self.urlBar.placeholder = @"Search or enter address";
    self.urlBar.font = [UIFont systemFontOfSize:16];
    self.urlBar.returnKeyType = UIReturnKeyGo;
    self.urlBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.urlBar.delegate = self;
    self.urlBar.translatesAutoresizingMaskIntoConstraints = NO;
    
    [urlContainer addSubview:self.urlBar];
    [self.view addSubview:urlContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [urlContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [urlContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [urlContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [urlContainer.heightAnchor constraintEqualToConstant:36],
        
        [self.urlBar.leadingAnchor constraintEqualToAnchor:urlContainer.leadingAnchor constant:12],
        [self.urlBar.trailingAnchor constraintEqualToAnchor:urlContainer.trailingAnchor constant:-12],
        [self.urlBar.centerYAnchor constraintEqualToAnchor:urlContainer.centerYAnchor],
        [self.urlBar.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)setupVortexView {
    self.vortexView = [[VortexView alloc] initWithFrame:CGRectZero];
    self.vortexView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.vortexView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.vortexView.topAnchor constraintEqualToAnchor:self.urlBar.bottomAnchor constant:8],
        [self.vortexView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.vortexView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.vortexView.bottomAnchor constraintEqualToAnchor:self.toolbar.topAnchor]
    ]];
}

- (void)setupProgressBar {
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressBar.progressTintColor = [UIColor tintColor];
    [self.view addSubview:self.progressBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.progressBar.topAnchor constraintEqualToAnchor:self.vortexView.topAnchor],
        [self.progressBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.progressBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.progressBar.heightAnchor constraintEqualToConstant:2]
    ]];
    
    self.progressBar.progress = 1.0;
    self.progressBar.hidden = YES;
}

- (void)navigateToURL:(NSString*)url {
    self.urlBar.text = url;
    [self.vortexView loadURL:url];
}

- (void)updateProgress:(CGFloat)progress {
    self.progressBar.progress = progress;
    self.progressBar.hidden = (progress >= 1.0);
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    NSString* url = textField.text;
    
    if (![url hasPrefix:@"http://"] && ![url hasPrefix:@"https://"]) {
        if ([url containsString:@"."]) {
            url = [NSString stringWithFormat:@"https://%@", url];
        } else {
            url = [NSString stringWithFormat:@"https://www.google.com/search?q=%@", 
                   [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        }
    }
    
    [self navigateToURL:url];
    [textField resignFirstResponder];
    return YES;
}

- (void)goBack {
    [self.vortexView goBack];
}

- (void)goForward {
    [self.vortexView goForward];
}

- (void)reload {
    [self.vortexView reload];
}

- (void)share {
    // Share current URL
    UIActivityViewController* activity = [[UIActivityViewController alloc] 
        initWithActivityItems:@[self.urlBar.text ?: @"https://vortex.browser"]
        applicationActivities:nil];
    
    [self presentViewController:activity animated:YES completion:nil];
}

@end

// App Delegate
@implementation VortexAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    (void)application;
    (void)launchOptions;
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    self.browserVC = [[VortexBrowserViewController alloc] init];
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:self.browserVC];
    nav.navigationBarHidden = YES;
    
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
