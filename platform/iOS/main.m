//
//  main.m
//  VortexBrowser
//
//  Entry point for Vortex Browser iOS Application
//

#import <UIKit/UIKit.h>
#import "vortex/VortexBrowserApp.h"

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Initialize Vortex Engine
        NSLog(@"[Vortex] Initializing browser engine...");
        
        // Setup any engine-wide configuration
        // The engine is initialized when VortexView is created
        
        appDelegateClassName = NSStringFromClass([VortexAppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
