// VortexBrowserApp.mm - Minimal working version
#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>

// Minimal AppDelegate
@interface VortexAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation VortexAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[Vortex] Launching...");
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Add a label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 50)];
    label.text = @"Vortex Browser";
    label.font = [UIFont boldSystemFontOfSize:24];
    label.textColor = [UIColor labelColor];
    [rootVC.view addSubview:label];
    
    self.window.rootViewController = rootVC;
    [self.window makeKeyAndVisible];
    
    NSLog(@"[Vortex] Window visible");
    return YES;
}

@end

// main()
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([VortexAppDelegate class]));
    }
}