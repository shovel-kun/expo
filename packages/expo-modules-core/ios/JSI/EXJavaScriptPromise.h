// Copyright 2024-present 650 Industries. All rights reserved.

#import <Foundation/Foundation.h>

#import <ExpoModulesCore/EXJavaScriptValue.h>
#import <ExpoModulesCore/EXJavaScriptRuntime.h>

#ifdef __cplusplus
#import <jsi/jsi.h>

namespace jsi = facebook::jsi;
namespace react = facebook::react;
#endif // __cplusplus

NS_SWIFT_NAME(JavaScriptPromise)
@interface EXJavaScriptPromise : EXJavaScriptObject

#ifdef __cplusplus
- (nonnull instancetype)initWithRuntime:(nonnull EXJavaScriptRuntime *)runtime
                            callInvoker:(std::shared_ptr<react::CallInvoker>)callInvoker;

- (void)awaitResult:(void(^_Nonnull)(const jsi::Value result))callback;
#endif // __cplusplus

- (void)resolve:(nonnull EXJavaScriptValue *)value;

@end
