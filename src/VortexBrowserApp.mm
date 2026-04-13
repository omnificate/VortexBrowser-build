#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "vortex/Engine.h"
#include "vortex/VortexBrowserApp.h"
#include <memory>
#include <string>

// MARK: - VortexView Implementation

@implementation VortexView

- (instancetype)initWithFrame:(CGRect)frame device:(id<MTLDevice>)device {
    self = [super initWithFrame:frame device:device];
    if (self) {
        self.scrollOffsetX = 0.0f;
        self.scrollOffsetY = 0.0f;
        self.zoomScale = 1.0f;
        self.clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0);
        self.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
        self.framebufferOnly = YES;
        self.enableSetNeedsDisplay = NO;
        self.paused = NO;
    }
    return self;
}

- (void)loadURL:(NSString*)url {
    NSLog(@"[Vortex] Loading URL: %@", url);
    // TODO: Implement URL loading with engine
}

- (void)loadHTML:(NSString*)html baseURL:(NSString*)baseURL {
    NSLog(@"[Vortex] Loading HTML content");
    // TODO: Implement HTML loading with engine
}

- (void)reload {
    NSLog(@"[Vortex] Reloading");
}

- (void)goBack {
    NSLog(@"[Vortex] Go back");
}

- (void)goForward {
    NSLog(@"[Vortex] Go forward");
}

@end

// MARK: - VortexBrowserViewController Implementation

@interface VortexBrowserViewController () <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> metalDevice;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) BOOL engineInitialized;
@end

@implementation VortexBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Setup Metal
    self.metalDevice = MTLCreateSystemDefaultDevice();
    if (!self.metalDevice) {
        NSLog(@"[Vortex] ERROR: Metal not supported on this device");
        return;
    }
    
    self.commandQueue = [self.metalDevice newCommandQueue];
    
    // Create VortexView
    self.vortexView = [[VortexView alloc] initWithFrame:self.view.bounds device:self.metalDevice];
    self.vortexView.delegate = self;
    self.vortexView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.vortexView];
    
    // Setup URL bar
    [self setupURLBar];
    
    // Setup toolbar
    [self setupToolbar];
    
    // Setup progress bar
    [self setupProgressBar];
    
    // Initialize Vortex Engine
    [self initializeEngine];
    
    NSLog(@"[Vortex] ViewDidLoad completed");
}

- (void)setupURLBar {
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, 50)];
    topBar.backgroundColor = [UIColor systemBackgroundColor];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    self.urlBar = [[UITextField alloc] initWithFrame:CGRectMake(8, 8, self.view.bounds.size.width - 16, 34)];
    self.urlBar.borderStyle = UITextBorderStyleRoundedRect;
    self.urlBar.placeholder = @"Search or enter address";
    self.urlBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlBar.keyboardType = UIKeyboardTypeURL;
    self.urlBar.returnKeyType = UIReturnKeyGo;
    self.urlBar.delegate = self;
    self.urlBar.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.urlBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    [topBar addSubview:self.urlBar];
    [self.view addSubview:topBar];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
}

- (void)setupToolbar {
    CGFloat toolbarHeight = 44.0;
    CGFloat yPosition = self.view.bounds.size.height - toolbarHeight;
    
    self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, yPosition, self.view.bounds.size.width, toolbarHeight)];
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.backward"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    UIBarButtonItem *forwardButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"] style:UIBarButtonItemStylePlain target:self action:@selector(reload)];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.toolbar setItems:@[backButton, flexibleSpace, forwardButton, flexibleSpace, refreshButton]];
    [self.view addSubview:self.toolbar];
}

- (void)setupProgressBar {
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.frame = CGRectMake(0, 94, self.view.bounds.size.width, 2);
    self.progressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.progressBar.progress = 0.0;
    [self.view addSubview:self.progressBar];
}

- (void)initializeEngine {
    if (self.engineInitialized) return;
    
    NSLog(@"[Vortex] Initializing browser engine...");
    
    // Initialize Vortex Engine
    try {
        Vortex::Engine::initialize();
        self.engineInitialized = YES;
        NSLog(@"[Vortex] Engine initialized successfully");
    } catch (const std::exception& e) {
        NSLog(@"[Vortex] Engine initialization failed: %s", e.what());
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat topSafe = 0;
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        topSafe = self.view.safeAreaInsets.top;
        bottomSafe = self.view.safeAreaInsets.bottom;
    }
    
    // Adjust vortex view to account for URL bar
    self.vortexView.frame = CGRectMake(0, 94, self.view.bounds.size.width, self.view.bounds.size.height - 94 - 44 - bottomSafe);
}

// MARK: - Navigation Actions

- (void)navigateToURL:(NSString*)url {
    [self.vortexView loadURL:url];
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

- (void)updateProgress:(CGFloat)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressBar.progress = progress;
    });
}

// MARK: - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle resize
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.commandQueue) return;
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *descriptor = view.currentRenderPassDescriptor;
    
    if (descriptor) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
        
        // Clear to white
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

// MARK: - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    NSString *text = textField.text;
    if (text.length > 0) {
        // Simple URL handling
        if ([text hasPrefix:@"http://"] || [text hasPrefix:@"https://"]) {
            [self navigateToURL:text];
        } else if ([text containsString:@"."]) {
            [self navigateToURL:[@"https://" stringByAppendingString:text]];
        } else {
            NSString *searchURL = [NSString stringWithFormat:@"https://www.google.com/search?q=%@", text];
            [self navigateToURL:searchURL];
        }
    }
    return YES;
}

@end

// MARK: - VortexAppDelegate Implementation

@implementation VortexAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[Vortex] Application launching...");
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"[Vortex] Application active");
}

- (void)applicationWillResignActive:(UIApplication *)application {
    NSLog(@"[Vortex] Application resigning active");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    NSLog(@"[Vortex] Application entering background");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    NSLog(@"[Vortex] Application entering foreground");
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"[Vortex] Application terminating");
    Vortex::Engine::shutdown();
}

@end