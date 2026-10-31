#include <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#else
#import <Foundation/Foundation.h>
#endif
#import <objc/runtime.h>
#include <optional>
#include <variant>
#include <any>
#include <dlfcn.h>

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
// Compatibility definitions for QuartzCore & UIKit constants missing in iOS 10.
// Under Whole Module Optimization (-O), the Swift compiler can hoist dereferences
// of weakly-imported constants before #available guards, leading to SIGSEGV on NULL.
CALayerCornerCurve const kCACornerCurveContinuous = @"continuous";
CALayerCornerCurve const kCACornerCurveCircular = @"circular";
UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignDefault = @"UIFontDescriptorSystemDesignDefault";
UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignMonospaced = @"UIFontDescriptorSystemDesignMonospaced";
UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignRounded = @"UIFontDescriptorSystemDesignRounded";
UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignSerif = @"UIFontDescriptorSystemDesignSerif";
UITextContentType const UITextContentTypeOneTimeCode = @"one-time-code";
#endif

// On iOS 10 arm64, libobjc does NOT export _objc_debug_isa_class_mask.
// Swift 5 runtime (libswiftCore.dylib) has a weak import for _objc_debug_isa_class_mask.
// If not found, Swift defaults _swift_isaMask to -1 (0xffffffffffffffffULL), which breaks
// all dynamic method lookups on Swift classes that inherit from Objective-C classes
// (like ImmediateTextNode, ASDisplayNode, etc.) because the Objective-C runtime on iOS 10 arm64
// uses non-pointer isas with magic bits in bits 33..63 (ISA_MASK = 0x00000001fffffff8ULL).
//
// By exporting _objc_debug_isa_class_mask here with default visibility, dyld satisfies
// libswiftCore's weak import at launch.
// In addition, an early constructor explicitly sets _swift_isaMask via dlsym to guarantee
// correct initialization.
extern "C" {
#if TARGET_OS_SIMULATOR
#if __x86_64__
__attribute__((visibility("default"))) uintptr_t _objc_debug_isa_class_mask = 0x00007ffffffffff8ULL;
#else
__attribute__((visibility("default"))) uintptr_t _objc_debug_isa_class_mask = 0x00000001fffffff8ULL;
#endif
#else
#if __arm64__
__attribute__((visibility("default"))) uintptr_t _objc_debug_isa_class_mask = 0x00000001fffffff8ULL;
#else
__attribute__((visibility("default"))) uintptr_t _objc_debug_isa_class_mask = (uintptr_t)-1;
#endif
#endif
}

__attribute__((constructor(101)))
static void fixup_swift_isa_mask() {
#if !TARGET_OS_SIMULATOR && defined(__arm64__)
    uintptr_t *maskPtr = (uintptr_t *)dlsym(RTLD_DEFAULT, "_swift_isaMask");
    if (maskPtr) {
        NSLog(@"[LegacyCppCompat] _swift_isaMask at %p was 0x%lx, setting to 0x1fffffff8",
              maskPtr, (unsigned long)*maskPtr);
        *maskPtr = 0x00000001fffffff8ULL;
    }
#endif
}

// Compatibility definitions for C++17 exception types that are not present
// in the iOS 10.3 /usr/lib/libc++.1.dylib runtime.
// Without these symbols defined in the binary, dyld will abort startup with:
// "DYLD, Symbol not found: __ZNSt19bad_optional_accessD1Ev | Expected in: /usr/lib/libc++.1.dylib"

namespace std {

bad_optional_access::~bad_optional_access() noexcept {}

const char* bad_optional_access::what() const noexcept {
    return "bad_optional_access";
}

const char* bad_variant_access::what() const noexcept {
    return "bad_variant_access";
}

const char* bad_any_cast::what() const noexcept {
    return "bad_any_cast";
}

}

// Fallback symbols for Network.framework on iOS < 12
// to prevent dyld abort if referenced by binary frameworks (e.g. RecaptchaEnterprise).
extern "C" {
void* $s7Network13NWPathMonitorCMa(long long) { return nullptr; }
void* $s7Network13NWPathMonitorCMn = nullptr;
void* $s7Network13NWPathMonitorCACycfc(void* self) { return self; }
void $s7Network13NWPathMonitorC5start5queueySo012OS_dispatch_E0C_tF(void*, void*) {}
void $s7Network13NWPathMonitorC6cancelyyF(void*) {}
void* $s7Network12NWConnectionCMa(long long) { return nullptr; }
void* $s7Network12NWConnectionCMn = nullptr;
void* $s7Network12NWParametersCMa(long long) { return nullptr; }
void* $s7Network12NWParametersC3tcpACvgZ() { return nullptr; }
void* $s7Network10NWEndpointOMa(long long) { return nullptr; }
void* $s7Network6NWPathVMa(long long) { return nullptr; }
}

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
static void dummy_setContentInsetAdjustmentBehavior(id self, SEL _cmd, NSInteger behavior) {
    (void)self; (void)_cmd; (void)behavior;
}

static NSInteger dummy_contentInsetAdjustmentBehavior(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    return 0;
}

static UIEdgeInsets dummy_safeAreaInsets(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    return UIEdgeInsetsZero;
}

static void dummy_setWaitsForConnectivity(id self, SEL _cmd, BOOL wait) {
    (void)self; (void)_cmd; (void)wait;
}

static BOOL dummy_waitsForConnectivity(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    return NO;
}

static void dummy_setMultipathServiceType(id self, SEL _cmd, NSInteger type) {
    (void)self; (void)_cmd; (void)type;
}

static NSInteger dummy_multipathServiceType(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    return 0;
}

__attribute__((constructor))
static void install_ios10_runtime_fallbacks() {
    if (![UIScrollView instancesRespondToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
        class_addMethod([UIScrollView class],
                        @selector(setContentInsetAdjustmentBehavior:),
                        (IMP)dummy_setContentInsetAdjustmentBehavior,
                        "v@:q");
        class_addMethod([UIScrollView class],
                        @selector(contentInsetAdjustmentBehavior),
                        (IMP)dummy_contentInsetAdjustmentBehavior,
                        "q@:");
    }
    if (![UIView instancesRespondToSelector:@selector(safeAreaInsets)]) {
        class_addMethod([UIView class],
                        @selector(safeAreaInsets),
                        (IMP)dummy_safeAreaInsets,
                        "{UIEdgeInsets=dddd}@:");
    }
    Class urlConfigClass = [NSURLSessionConfiguration class];
    if (![urlConfigClass instancesRespondToSelector:@selector(setWaitsForConnectivity:)]) {
        class_addMethod(urlConfigClass, @selector(setWaitsForConnectivity:), (IMP)dummy_setWaitsForConnectivity, "v@:B");
        class_addMethod(urlConfigClass, @selector(waitsForConnectivity), (IMP)dummy_waitsForConnectivity, "B@:");
    }
    if (![urlConfigClass instancesRespondToSelector:@selector(setMultipathServiceType:)]) {
        class_addMethod(urlConfigClass, @selector(setMultipathServiceType:), (IMP)dummy_setMultipathServiceType, "v@:q");
        class_addMethod(urlConfigClass, @selector(multipathServiceType), (IMP)dummy_multipathServiceType, "q@:");
    }
    Class nscfConfigClass = objc_getClass("__NSCFURLSessionConfiguration");
    if (nscfConfigClass) {
        if (![nscfConfigClass instancesRespondToSelector:@selector(setWaitsForConnectivity:)]) {
            class_addMethod(nscfConfigClass, @selector(setWaitsForConnectivity:), (IMP)dummy_setWaitsForConnectivity, "v@:B");
            class_addMethod(nscfConfigClass, @selector(waitsForConnectivity), (IMP)dummy_waitsForConnectivity, "B@:");
        }
        if (![nscfConfigClass instancesRespondToSelector:@selector(setMultipathServiceType:)]) {
            class_addMethod(nscfConfigClass, @selector(setMultipathServiceType:), (IMP)dummy_setMultipathServiceType, "v@:q");
            class_addMethod(nscfConfigClass, @selector(multipathServiceType), (IMP)dummy_multipathServiceType, "q@:");
        }
    }
}
#endif
