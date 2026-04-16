#import <UIKit/UIKit.h>

// Forward declarations
@class VortexWebViewController;

// MARK: - SceneDelegate for iOS 16+ scene-based lifecycle
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) id browserVC;
@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    NSLog(@"[Vortex] Scene connecting - iOS 16+ mode");
    
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        
        // Create window with window scene
        self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
        
        // Get the browser view controller class from the app compilation
        // The browser VC is defined in VortexCyberKitApp.mm or VortexBrowserApp.mm
        Class browserVCClass = NSClassFromString(@"VortexWebViewController");
        
        if (browserVCClass) {
            self.browserVC = [[browserVCClass alloc] init];
            [(UIViewController *)self.browserVC setTitle:@"Vortex Browser"];
            
            // Create navigation controller
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.browserVC];
            
            self.window.rootViewController = navController;
            [self.window makeKeyAndVisible];
            NSLog(@"[Vortex] Browser VC created and window visible");
        } else {
            NSLog(@"[Vortex] ERROR: VortexWebViewController class not found!");
            // Create a fallback
            UIViewController *fallbackVC = [[UIViewController alloc] init];
            fallbackVC.view.backgroundColor = [UIColor systemBackgroundColor];
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 100)];
            label.text = @"Vortex Browser\nLoading...";
            label.numberOfLines = 0;
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont boldSystemFontOfSize:20];
            [fallbackVC.view addSubview:label];
            
            self.window.rootViewController = fallbackVC;
            [self.window makeKeyAndVisible];
        }
    }
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    NSLog(@"[Vortex] Scene disconnected");
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    NSLog(@"[Vortex] Scene became active");
}

- (void)sceneWillResignActive:(UIScene *)scene {
    NSLog(@"[Vortex] Scene will resign active");
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    NSLog(@"[Vortex] Scene entering foreground");
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    NSLog(@"[Vortex] Scene entered background");
}

@end