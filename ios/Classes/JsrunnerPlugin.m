#import "JsrunnerPlugin.h"
#if __has_include(<jsrunner/jsrunner-Swift.h>)
#import <jsrunner/jsrunner-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "jsrunner-Swift.h"
#endif

@implementation JsrunnerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftJsrunnerPlugin registerWithRegistrar:registrar];
}
@end
