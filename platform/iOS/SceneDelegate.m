//
//  SceneDelegate.m
//  VortexBrowser
//
//  Scene delegate for iOS 16+ scene-based lifecycle
//

#import <UIKit/UIKit.h>
#import "vortex/VortexBrowserApp.h"

@interface VortexSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) VortexBrowserViewController *browserVC;
@end

@implementation VortexSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    
    self.browserVC = [[VortexBrowserViewController alloc] init];
    self.window.rootViewController = self.browserVC;
    
    [self.window makeKeyAndVisible];
    
    // Handle any URL that launched the app
    NSURL *url = connectionOptions.userActivities.anyObject.webpageURL;
    if (url) {
        [self.browserVC navigateToURL:url.absoluteString];
    }
}

- (void)sceneDidDisconnect:(UIScene *)scene {
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
}

- (void)sceneWillResignActive:(UIScene *)scene {
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
}

@end
