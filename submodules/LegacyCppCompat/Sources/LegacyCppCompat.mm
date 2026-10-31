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

// Network.framework fallback classes for iOS < 12 are implemented in Swift in //submodules/LegacyNetwork:LegacyNetwork

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

static NSData *compat_archivedDataWithRootObject(id self, SEL _cmd, id rootObject, BOOL requiringSecureCoding, NSError **error) {
    (void)self; (void)_cmd; (void)requiringSecureCoding;
    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rootObject];
#pragma clang diagnostic pop
        if (error) {
            *error = nil;
        }
        return data;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:exception.name code:-1 userInfo:exception.userInfo];
        }
        return nil;
    }
}

static id compat_unarchiveTopLevelObjectWithData(id self, SEL _cmd, NSData *data, NSError **error) {
    (void)self; (void)_cmd;
    if (data == nil) {
        return nil;
    }
    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
        if (error) {
            *error = nil;
        }
        return object;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:exception.name code:-1 userInfo:exception.userInfo];
        }
        return nil;
    }
}

static id compat_unarchivedObjectOfClass(id self, SEL _cmd, Class cls, NSData *data, NSError **error) {
    (void)cls;
    return compat_unarchiveTopLevelObjectWithData(self, _cmd, data, error);
}

static id compat_unarchivedObjectOfClasses(id self, SEL _cmd, NSSet *classes, NSData *data, NSError **error) {
    (void)classes;
    return compat_unarchiveTopLevelObjectWithData(self, _cmd, data, error);
}

static id compat_initForReadingFromData(id self, SEL _cmd, NSData *data, NSError **error) {
    (void)self; (void)_cmd;
    if (error) {
        *error = nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self initForReadingWithData:data];
#pragma clang diagnostic pop
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
    
    Class archiverMetaClass = object_getClass([NSKeyedArchiver class]);
    SEL archivedDataSel = sel_registerName("archivedDataWithRootObject:requiringSecureCoding:error:");
    if (![NSKeyedArchiver respondsToSelector:archivedDataSel]) {
        class_addMethod(archiverMetaClass,
                        archivedDataSel,
                        (IMP)compat_archivedDataWithRootObject,
                        "@@:@B^@");
    }
    
    Class unarchiverMetaClass = object_getClass([NSKeyedUnarchiver class]);
    SEL unarchiveTopLevelSel = sel_registerName("unarchiveTopLevelObjectWithData:error:");
    if (![NSKeyedUnarchiver respondsToSelector:unarchiveTopLevelSel]) {
        class_addMethod(unarchiverMetaClass,
                        unarchiveTopLevelSel,
                        (IMP)compat_unarchiveTopLevelObjectWithData,
                        "@@:@^@");
    }
    
    SEL unarchivedOfClassSel = sel_registerName("unarchivedObjectOfClass:fromData:error:");
    if (![NSKeyedUnarchiver respondsToSelector:unarchivedOfClassSel]) {
        class_addMethod(unarchiverMetaClass,
                        unarchivedOfClassSel,
                        (IMP)compat_unarchivedObjectOfClass,
                        "@@:@@^@");
    }
    
    SEL unarchivedOfClassesSel = sel_registerName("unarchivedObjectOfClasses:fromData:error:");
    if (![NSKeyedUnarchiver respondsToSelector:unarchivedOfClassesSel]) {
        class_addMethod(unarchiverMetaClass,
                        unarchivedOfClassesSel,
                        (IMP)compat_unarchivedObjectOfClasses,
                        "@@:@@^@");
    }
    
    SEL initForReadingSel = sel_registerName("initForReadingFromData:error:");
    if (![NSKeyedUnarchiver instancesRespondToSelector:initForReadingSel]) {
        class_addMethod([NSKeyedUnarchiver class],
                        initForReadingSel,
                        (IMP)compat_initForReadingFromData,
                        "@@:@^@");
    }
}
#endif
