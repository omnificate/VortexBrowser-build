#!/bin/bash
#
# Vortex Browser iOS Build Script
# Generates signed IPA for sideloading
#

set -e

# Configuration
PROJECT_NAME="VortexBrowser"
APP_NAME="Vortex"
BUNDLE_ID="com.vortex.browser"
SCHEME="VortexBrowser"
CONFIGURATION="Release"

# Build directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
ARCHIVE_PATH="$BUILD_DIR/VortexBrowser.xcarchive"
IPA_PATH="$BUILD_DIR/VortexBrowser.ipa"
TIPA_PATH="$BUILD_DIR/VortexBrowser.tipa"

# iOS SDK settings
DEPLOYMENT_TARGET="14.0"
DEVICE_ARCH="arm64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Vortex Browser iOS Build System"
echo "========================================"
echo ""

# Function to check dependencies
check_dependencies() {
    echo "Checking dependencies..."
    
    if ! command -v xcodebuild &> /dev/null; then
        echo "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
        exit 1
    fi
    
    if ! command -v plutil &> /dev/null; then
        echo "${RED}Error: plutil not found.${NC}"
        exit 1
    fi
    
    echo "${GREEN}✓ All dependencies found${NC}"
    echo ""
}

# Function to prepare build directory
prepare_build() {
    echo "Preparing build environment..."
    
    mkdir -p "$BUILD_DIR"
    mkdir -p "$BUILD_DIR/Payload"
    mkdir -p "$BUILD_DIR/Resources"
    
    echo "${GREEN}✓ Build directories created${NC}"
    echo ""
}

# Function to generate Xcode project
generate_xcode_project() {
    echo "Generating Xcode project..."
    
    # Create project.pbxproj content
    mkdir -p "$PROJECT_ROOT/platform/iOS/VortexBrowser.xcodeproj"
    
    cat > "$PROJECT_ROOT/platform/iOS/VortexBrowser.xcodeproj/project.pbxproj" << 'XCODEPROJ'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		000000001 /* main.m in Sources */ = {isa = PBXBuildFile; fileRef = 000000002 /* main.m */; };
		000000003 /* VortexBrowserApp.mm in Sources */ = {isa = PBXBuildFile; fileRef = 000000004 /* VortexBrowserApp.mm */; };
		000000005 /* Engine.cpp in Sources */ = {isa = PBXBuildFile; fileRef = 000000006 /* Engine.cpp */; };
		000000007 /* Renderer.mm in Sources */ = {isa = PBXBuildFile; fileRef = 000000008 /* Renderer.mm */; };
		000000009 /* Layout.cpp in Sources */ = {isa = PBXBuildFile; fileRef = 00000000A /* Layout.cpp */; };
		00000000B /* CSS.cpp in Sources */ = {isa = PBXBuildFile; fileRef = 00000000C /* CSS.cpp */; };
		00000000D /* VortexShaders.metal in Sources */ = {isa = PBXBuildFile; fileRef = 00000000E /* VortexShaders.metal */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		000000010 /* VortexBrowser.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = VortexBrowser.app; sourceTree = BUILT_PRODUCTS_DIR; };
		000000002 /* main.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = main.m; sourceTree = "<group>"; };
		000000004 /* VortexBrowserApp.mm */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.objcpp; path = VortexBrowserApp.mm; sourceTree = "<group>"; };
		000000006 /* Engine.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = Engine.cpp; sourceTree = "<group>"; };
		000000008 /* Renderer.mm */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.objcpp; path = Renderer.mm; sourceTree = "<group>"; };
		00000000A /* Layout.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = Layout.cpp; sourceTree = "<group>"; };
		00000000C /* CSS.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = CSS.cpp; sourceTree = "<group>"; };
		00000000E /* VortexShaders.metal */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.metal; path = VortexShaders.metal; sourceTree = "<group>"; };
		000000011 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		000000012 /* VortexBrowser.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = VortexBrowser.entitlements; sourceTree = "<group>"; };
		000000013 /* VortexBrowserApp.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = VortexBrowserApp.h; sourceTree = "<group>"; };
		000000014 /* Core.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = Core.h; sourceTree = "<group>"; };
		000000015 /* Renderer.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = Renderer.h; sourceTree = "<group>"; };
		000000016 /* Layout.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = Layout.h; sourceTree = "<group>"; };
		000000017 /* CSS.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = CSS.h; sourceTree = "<group>"; };
		000000018 /* HTMLParser.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = HTMLParser.h; sourceTree = "<group>"; };
		000000019 /* JavaScript.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = JavaScript.h; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		000000020 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		000000030 = {
			isa = PBXGroup;
			children = (
				000000031 /* VortexBrowser */,
				000000032 /* Products */,
			);
			sourceTree = "<group>";
		};
		000000032 /* Products */ = {
			isa = PBXGroup;
			children = (
				000000010 /* VortexBrowser.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		000000031 /* VortexBrowser */ = {
			isa = PBXGroup;
			children = (
				000000002 /* main.m */,
				000000004 /* VortexBrowserApp.mm */,
				000000013 /* VortexBrowserApp.h */,
				000000011 /* Info.plist */,
				000000012 /* VortexBrowser.entitlements */,
			);
			path = VortexBrowser;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		000000040 /* VortexBrowser */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 000000041 /* Build configuration list for PBXNativeTarget "VortexBrowser" */;
			buildPhases = (
				000000042 /* Sources */,
				000000020 /* Frameworks */,
				000000043 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = VortexBrowser;
			productName = VortexBrowser;
			productReference = 000000010 /* VortexBrowser.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		000000050 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					000000040 = {
						CreatedOnToolsVersion = 15.0;
						SystemCapabilities = {
							com.apple.ApplicationGroups.iOS = {enabled = 1; };
						};
					};
				};
			};
			buildConfigurationList = 000000051 /* Build configuration list for PBXProject "VortexBrowser" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 000000030;
			productRefGroup = 000000032 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				000000040 /* VortexBrowser */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		000000043 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		000000042 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				000000001 /* main.m in Sources */,
				000000003 /* VortexBrowserApp.mm in Sources */,
				000000005 /* Engine.cpp in Sources */,
				000000007 /* Renderer.mm in Sources */,
				000000009 /* Layout.cpp in Sources */,
				00000000B /* CSS.cpp in Sources */,
				00000000D /* VortexShaders.metal in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		000000060 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
			};
			name = Debug;
		};
		000000061 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		000000062 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = VortexBrowser.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchStoryboard_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.vortex.browser;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		000000063 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = VortexBrowser.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchStoryboard_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.vortex.browser;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		000000051 /* Build configuration list for PBXProject "VortexBrowser" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				000000060 /* Debug */,
				000000061 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		000000041 /* Build configuration list for PBXNativeTarget "VortexBrowser" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				000000062 /* Debug */,
				000000063 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 000000050 /* Project object */;
}
XCODEPROJ

    echo "${GREEN}✓ Xcode project generated${NC}"
    echo ""
}

# Function to compile source files
compile_sources() {
    echo "Compiling Vortex Engine..."
    
    # Use xcodebuild or manual clang compilation
    # For sideloading, we'll build manually with clang
    
    # Find SDK
    SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
    
    # Compile flags
    CFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-version-min=$DEPLOYMENT_TARGET \
            -O3 -fobjc-arc -fmodules -fcache-modules \
            -I$PROJECT_ROOT/include -I$PROJECT_ROOT/platform/iOS"
    
    CXXFLAGS="$CFLAGS -std=c++20 -stdlib=libc++"
    
    echo "SDK: $SDK_PATH"
    echo "Building for arm64..."
    
    # Create object files directory
    mkdir -p "$BUILD_DIR/Objects"
    
    # Compile C++ sources
    xcrun --sdk iphoneos clang++ $CXXFLAGS -c \
        "$PROJECT_ROOT/src/Engine.cpp" \
        -o "$BUILD_DIR/Objects/Engine.o"
    
    xcrun --sdk iphoneos clang++ $CXXFLAGS -c \
        "$PROJECT_ROOT/src/Layout.cpp" \
        -o "$BUILD_DIR/Objects/Layout.o"
    
    xcrun --sdk iphoneos clang++ $CXXFLAGS -c \
        "$PROJECT_ROOT/src/CSS.cpp" \
        -o "$BUILD_DIR/Objects/CSS.o"
    
    # Compile Objective-C++ sources
    xcrun --sdk iphoneos clang++ $CXXFLAGS -c \
        "$PROJECT_ROOT/src/VortexBrowserApp.mm" \
        -o "$BUILD_DIR/Objects/VortexBrowserApp.o"
    
    xcrun --sdk iphoneos clang++ $CXXFLAGS -c \
        "$PROJECT_ROOT/src/Renderer.mm" \
        -o "$BUILD_DIR/Objects/Renderer.o"
    
    # Compile Metal shaders
    xcrun --sdk iphoneos metal \
        -c "$PROJECT_ROOT/shaders/VortexShaders.metal" \
        -o "$BUILD_DIR/Objects/VortexShaders.air"
    
    xcrun --sdk iphoneos metal-ar \
        r "$BUILD_DIR/Objects/VortexShaders.metalar" \
        "$BUILD_DIR/Objects/VortexShaders.air"
    
    xcrun --sdk iphoneos metallib \
        "$BUILD_DIR/Objects/VortexShaders.metalar" \
        -o "$BUILD_DIR/VortexShaders.metallib"
    
    echo "${GREEN}✓ Compilation complete${NC}"
    echo ""
}

# Function to link and create app bundle
create_app_bundle() {
    echo "Creating app bundle..."
    
    # Link all object files
    LDFLAGS="-arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk_path) \
             -mios-version-min=$DEPLOYMENT_TARGET \
             -framework Foundation -framework UIKit -framework Metal -framework MetalKit \
             -framework QuartzCore -framework CoreGraphics -framework CoreText \
             -stdlib=libc++ -fobjc-arc -fobjc-link-runtime"
    
    xcrun --sdk iphoneos clang++ $LDFLAGS \
        "$BUILD_DIR/Objects/Engine.o" \
        "$BUILD_DIR/Objects/Layout.o" \
        "$BUILD_DIR/Objects/CSS.o" \
        "$BUILD_DIR/Objects/VortexBrowserApp.o" \
        "$BUILD_DIR/Objects/Renderer.o" \
        -o "$BUILD_DIR/Payload/VortexBrowser.app/VortexBrowser"
    
    # Copy resources
    cp "$PROJECT_ROOT/platform/iOS/Info.plist" "$BUILD_DIR/Payload/VortexBrowser.app/"
    cp "$PROJECT_ROOT/platform/iOS/VortexBrowser.entitlements" "$BUILD_DIR/Payload/VortexBrowser.app/"
    cp "$BUILD_DIR/VortexShaders.metallib" "$BUILD_DIR/Payload/VortexBrowser.app/"
    
    # Create PkgInfo
    echo -n "APPL????" > "$BUILD_DIR/Payload/VortexBrowser.app/PkgInfo"
    
    echo "${GREEN}✓ App bundle created${NC}"
    echo ""
}

# Function to generate fake code signature for sideloading
fake_sign() {
    echo "Creating fake signature for sideloading..."
    
    # Use ldid or similar for fake signing
    # For TrollStore/altStore sideloading
    
    APP_PATH="$BUILD_DIR/Payload/VortexBrowser.app"
    
    # Create basic signature structure
    mkdir -p "$APP_PATH/_CodeSignature"
    
    # Generate simple signature file (placeholder)
    cat > "$APP_PATH/_CodeSignature/CodeResources" << 'RESOURCES'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>files</key>
    <dict>
    </dict>
    <key>files2</key>
    <dict>
    </dict>
    <key>rules</key>
    <dict>
        <key>^.*</key>
        <true/>
    </dict>
    <key>rules2</key>
    <dict>
        <key>^.*</key>
        <true/>
    </dict>
</dict>
</plist>
RESOURCES

    # Create embedded.mobileprovision (sideloadable)
    # In real scenario, this would come from Apple
    touch "$APP_PATH/embedded.mobileprovision"
    
    echo "${YELLOW}Note: This app uses fake signing for sideloading.${NC}"
    echo "${YELLOW}Install with TrollStore (.tipa), AltStore, or similar.${NC}"
    echo "${GREEN}✓ Fake signature created${NC}"
    echo ""
}

# Function to package IPA
package_ipa() {
    echo "Packaging IPA..."
    
    # Create IPA (zip file with .ipa extension)
    cd "$BUILD_DIR"
    zip -r "VortexBrowser.ipa" Payload/
    cd -
    
    echo "${GREEN}✓ IPA created: $BUILD_DIR/VortexBrowser.ipa${NC}"
    echo ""
}

# Function to package TIPA (TrollStore format - same as IPA but .tipa extension)
package_tipa() {
    echo "Packaging TIPA for TrollStore..."
    
    # TIPA is identical to IPA, just renamed for TrollStore/AirDrop compatibility
    # Copy IPA to TIPA
    cp "$BUILD_DIR/VortexBrowser.ipa" "$BUILD_DIR/VortexBrowser.tipa"
    
    echo "${GREEN}✓ TIPA created: $BUILD_DIR/VortexBrowser.tipa${NC}"
    echo "${YELLOW}Note: TIPA is same format as IPA, renamed for TrollStore${NC}"
    echo ""
}

# Function to generate installation instructions
generate_install_instructions() {
    cat > "$BUILD_DIR/INSTALL.md" << 'INSTALL'
# Vortex Browser Installation Guide

## IPA/TIPA Installation Methods

### Method 1: TrollStore (Recommended for iOS 14.0 - 16.6.1)
1. Install TrollStore from https://github.com/opa334/TrollStore
2. AirDrop `VortexBrowser.tipa` to your iOS device (it will auto-open in TrollStore)
   OR open TrollStore app and tap "Install from File"
3. Select `VortexBrowser.tipa`
4. Vortex will be installed permanently (no re-signing needed)

**Why .tipa?** It's the same format as .ipa but renamed for easier AirDrop sharing with TrollStore.

### Method 2: AltStore / SideStore
1. Install AltStore from https://altstore.io
2. Connect device to computer with AltServer running
3. Open AltStore on iOS device
4. Tap "+" in My Apps tab
5. Select `VortexBrowser.ipa`
6. App will install with 7-day certificate (refresh weekly)

### Method 3: Sideloadly (Free, requires weekly refresh)
1. Download Sideloadly from https://sideloadly.io
2. Connect iOS device to Mac/PC
3. Drag `VortexBrowser.ipa` to Sideloadly
4. Enter Apple ID (free account works)
5. Click "Start" to install
6. Trust developer in Settings → General → VPN & Device Management

### Method 4: Xcode (Developer build)
```bash
cd platform/iOS
xcodebuild -project VortexBrowser.xcodeproj -scheme VortexBrowser -destination 'platform=iOS,name=Your Device'
```

## Supported Devices
- iPhone: XS/XR and newer (A12+ chip)
- iPad: Pro 3rd gen+, Air 3rd gen+, mini 5th gen+, 8th gen+
- iOS: 14.0 or later
- Architecture: arm64 (no 32-bit support)

## Features
- GPU-accelerated rendering with Metal
- Zero-copy architecture for maximum performance
- SIMD-optimized layout engine
- Lock-free memory management
- CSS3 Flexbox and Grid support
- 120fps smooth scrolling
- Modern JavaScript ES2023 support

## Troubleshooting

### "Unable to install" error
- Ensure device has enough storage (500MB+)
- Restart device and try again

### Crashes on launch
- Check iOS version compatibility
- Ensure Metal is supported on device
- Check if using TrollStore (more reliable)

### Black screen
- This is expected if WebKit content fails to load
- Vortex uses its own rendering engine

## Performance Tips
- Use iOS 15+ for best Metal performance
- Close background apps for more memory
- Enable "Increase Memory Limit" in entitlements
INSTALL

    echo "${GREEN}✓ Installation guide created${NC}"
    echo ""
}

# Main build flow
main() {
    echo "Starting Vortex Browser build process..."
    echo "Target: arm64 iOS $DEPLOYMENT_TARGET+"
    echo ""
    
    check_dependencies
    prepare_build
    generate_xcode_project
    compile_sources
    create_app_bundle
    fake_sign
    package_ipa
    package_tipa
    generate_install_instructions
    
    echo "========================================"
    echo "${GREEN}Build Complete!${NC}"
    echo "========================================"
    echo ""
    echo "Output files:"
    echo "  IPA:    $BUILD_DIR/VortexBrowser.ipa     (Standard format)"
    echo "  TIPA:   $BUILD_DIR/VortexBrowser.tipa   (TrollStore/AirDrop)"
    echo "  App:    $BUILD_DIR/Payload/VortexBrowser.app/"
    echo "  Guide:  $BUILD_DIR/INSTALL.md"
    echo ""
    echo "Installation:"
    echo "  TrollStore:   AirDrop .tipa file or use 'Install from File'"
    echo "  AltStore:     Use .ipa file"
    echo "  Sideloadly:   Use .ipa file"
    echo ""
    echo "${GREEN}🌪️ Vortex Browser ready for sideloading!${NC}"
}

main "$@"
