#pragma once

#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>

// Vortex Browser iOS App
// High-performance browser with Metal-accelerated rendering

@interface VortexView : MTKView

@property (nonatomic, assign) CGFloat scrollOffsetX;
@property (nonatomic, assign) CGFloat scrollOffsetY;
@property (nonatomic, assign) CGFloat zoomScale;

- (void)loadURL:(NSString*)url;
- (void)loadHTML:(NSString*)html baseURL:(NSString*)baseURL;
- (void)reload;
- (void)goBack;
- (void)goForward;

@end

@interface VortexBrowserViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) VortexView* vortexView;
@property (nonatomic, strong) UITextField* urlBar;
@property (nonatomic, strong) UIProgressView* progressBar;
@property (nonatomic, strong) UIToolbar* toolbar;

- (void)navigateToURL:(NSString*)url;
- (void)updateProgress:(CGFloat)progress;

@end

@interface VortexAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow* window;
@property (nonatomic, strong) VortexBrowserViewController* browserVC;

@end

// Scene Delegate for iOS 13+ scene-based lifecycle
API_AVAILABLE(ios(13.0))
@interface VortexSceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (nonatomic, strong) UIWindow* window;
@property (nonatomic, strong) VortexBrowserViewController* browserVC;

@end
