//
//  main.m
//  VortexBrowser
//
//  Entry point for Vortex Browser iOS Application
//

#import <UIKit/UIKit.h>
#import "../include/vortex/VortexBrowserApp.h"

// For iOS 13+, use scene-based lifecycle
// For older iOS, use traditional app delegate

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        NSLog(@"[Vortex] Starting Vortex Browser...");
        
        // Use VortexAppDelegate for app lifecycle
        // Scene delegate (VortexSceneDelegate) is configured in Info.plist
        appDelegateClassName = NSStringFromClass([VortexAppDelegate class]);
        
        NSLog(@"[Vortex] App delegate class: %@", appDelegateClassName);
    }
    
    // UIApplicationMain will:
    // - Create the application object
    // - Instantiate the app delegate
    // - For iOS 13+, use scene delegate from Info.plist UIApplicationSceneManifest
    // - Set up the main run loop
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
