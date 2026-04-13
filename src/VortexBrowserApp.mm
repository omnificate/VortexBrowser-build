#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "vortex/Engine.h"
#include <memory>
#include <string>

@interface VortexViewController : UIViewController <MTKViewDelegate>
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation VortexViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Setup Metal device
    self.device = MTLCreateSystemDefaultDevice();
    
    // Setup MTKView
    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:self.device];
    self.metalView.delegate = self;
    self.metalView.clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0);
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    self.metalView.framebufferOnly = YES;
    self.metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.metalView];
    
    // Initialize Vortex Engine
    [self initializeEngine];
}

- (void)initializeEngine {
    // Engine initialization happens in drawInMTKView
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle viewport resize
}

- (void)drawInMTKView:(MTKView *)view {
    // Render frame
    @autoreleasepool {
        // Basic clear - would integrate with VortexEngine
    }
}

@end

@interface VortexAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation VortexAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    VortexViewController *rootViewController = [[VortexViewController alloc] init];
    self.window.rootViewController = rootViewController;
    
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([VortexAppDelegate class]));
    }
}
