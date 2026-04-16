#import <UIKit/UIKit.h>

// Forward declarations
@class VortexCyberKitWebViewController;

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
        // The browser VC is defined in VortexCyberKitApp.mm
        Class browserVCClass = NSClassFromString(@"VortexCyberKitWebViewController");
        if (!browserVCClass) {
            browserVCClass = NSClassFromString(@"VortexWebViewController");
        }
        
        if (browserVCClass) {
            self.browserVC = [[browserVCClass alloc] init];
            [(UIViewController *)self.browserVC setTitle:@"Vortex CyberKit"];
            
            // Create navigation controller
            Class navControllerClass = NSClassFromString(@"UINavigationController");
            id navController = [[navControllerClass alloc] initWithRootViewController:self.browserVC];
            
            self.window.rootViewController = navController;
        } else {
            NSLog(@"[Vortex] ERROR: Browser VC class not found!");
            // Create a fallback alert
            UIViewController *alertVC = [[UIViewController alloc] init];
            alertVC.view.backgroundColor = [UIColor systemBackgroundColor];
            
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 100)];
            label.text = @"Vortex Browser\niOS 16+ Build\nCyberKit Engine";
            label.numberOfLines = 0;
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont boldSystemFontOfSize:20];
            [alertVC.view addSubview:label];
            
            self.window.rootViewController = alertVC;
        }
        
        [self.window makeKeyAndVisible];
        NSLog(@"[Vortex] Window created and visible with scene");
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
