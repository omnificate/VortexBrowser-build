// SceneDelegate.mm - MINIMAL VERSION
// The REAL SceneDelegate is defined in VortexCyberKitApp.mm or VortexBrowserApp.mm
// This file exists only to satisfy the build system from v2.0.8
// The actual implementation in the app file takes precedence at runtime

#import <UIKit/UIKit.h>

// Empty implementation - real SceneDelegate is in the main app file
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // This should never be called - the real SceneDelegate in VortexCyberKitApp.mm overrides this
    NSLog(@"[Vortex] WARNING: Empty SceneDelegate.mm was used! Real SceneDelegate should be in app file.");
}

@end
