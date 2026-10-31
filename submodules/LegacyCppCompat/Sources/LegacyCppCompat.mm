#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <optional>
#include <variant>
#include <any>

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
