// Copyright 2022-present 650 Industries. All rights reserved.

#import <sstream>

#import <React/RCTUtils.h>
#import <react/bridging/Function.h>
#import <ExpoModulesCore/EXJSIConversions.h>
#import <ExpoModulesCore/EXJSIUtils.h>
#import <ExpoModulesCore/JSIUtils.h>
#import <ExpoModulesCore/NativeModule.h>
#import <ExpoModulesCore/EventEmitter.h>

namespace expo {

jsi::Value createPromise(jsi::Runtime &runtime, std::string methodName, PromiseInvocationBlock invoke) {
  if (!invoke) {
    return jsi::Value::undefined();
  }

  jsi::Function Promise = runtime.global().getPropertyAsFunction(runtime, "Promise");

  // Note: the passed invoke() block is not retained by default, so let's retain it here to help keep it longer.
  // Otherwise, there's a risk of it getting released before the promise function below executes.
  PromiseInvocationBlock invokeCopy = [invoke copy];
  return Promise.callAsConstructor(
    runtime,
    jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "fn"),
      2,
      [invokeCopy, jsInvoker = jsInvoker_, moduleName = name_, methodName](jsi::Runtime &rt, const jsi::Value &thisVal, const jsi::Value *args, size_t count) {
        std::string moduleMethod = moduleName + "." + methodName + "()";

        if (count != 2) {
          throw std::invalid_argument(moduleMethod + ": Promise must pass constructor function two args. Passed " + std::to_string(count) + " args.");
        }
        if (!invokeCopy) {
          return jsi::Value::undefined();
        }

        __block BOOL resolveWasCalled = NO;
        __block std::optional<AsyncCallback<>> resolve({rt, args[0].getObject(rt).getFunction(rt), std::move(jsInvoker)});
        __block std::optional<AsyncCallback<>> reject({rt, args[1].getObject(rt).getFunction(rt), std::move(jsInvoker)});

        RCTPromiseResolveBlock resolveBlock = ^(id result) {
          if (!resolve || !reject) {
            if (resolveWasCalled) {
              RCTLogError(@"%s: Tried to resolve a promise more than once.", moduleMethod.c_str());
            } else {
              RCTLogError(@"%s: Tried to resolve a promise after it's already been rejected.", moduleMethod.c_str());
            }
            return;
          }

          resolve->call([result](jsi::Runtime &rt, jsi::Function &jsFunction) {
            jsFunction.call(rt, convertObjCObjectToJSIValue(rt, result));
          });

          resolveWasCalled = YES;
          resolve = std::nullopt;
          reject = std::nullopt;
        };

        RCTPromiseRejectBlock rejectBlock = ^(NSString *code, NSString *message, NSError *error) {
          if (!resolve || !reject) {
            if (resolveWasCalled) {
              RCTLogError(@"%s: Tried to reject a promise after it's already been resolved.", moduleMethod.c_str());
            } else {
              RCTLogError(@"%s: Tried to reject a promise more than once.", moduleMethod.c_str());
            }
            return;
          }

          NSDictionary *jsErrorDetails = RCTJSErrorFromCodeMessageAndNSError(code, message, error);
          reject->call([jsErrorDetails](jsi::Runtime &rt, jsi::Function &jsFunction) {
            jsFunction.call(rt, convertJSErrorDetailsToJSRuntimeError(rt, jsErrorDetails));
          });
          resolveWasCalled = NO;
          resolve = std::nullopt;
          reject = std::nullopt;
        };

        invokeCopy(resolveBlock, rejectBlock);
        return jsi::Value::undefined();
      }
    )
  );
}

void callPromiseSetupWithBlock(jsi::Runtime &runtime, std::shared_ptr<CallInvoker> jsInvoker, std::shared_ptr<Promise> promise, PromiseInvocationBlock setupBlock)
{
  auto weakResolveWrapper = react::CallbackWrapper::createWeak(promise->resolve_.getFunction(runtime), runtime, jsInvoker);
  auto weakRejectWrapper = react::CallbackWrapper::createWeak(promise->reject_.getFunction(runtime), runtime, jsInvoker);

  __block BOOL isSettled = NO;

  RCTPromiseResolveBlock resolveBlock = ^(id result) {
    if (isSettled) {
      // The promise is already either resolved or rejected.
      return;
    }

    auto strongResolveWrapper = weakResolveWrapper.lock();
    auto strongRejectWrapper = weakRejectWrapper.lock();
    if (!strongResolveWrapper || !strongRejectWrapper) {
      return;
    }

    strongResolveWrapper->jsInvoker().invokeAsync([weakResolveWrapper, weakRejectWrapper, result]() {
      auto strongResolveWrapper2 = weakResolveWrapper.lock();
      auto strongRejectWrapper2 = weakRejectWrapper.lock();
      if (!strongResolveWrapper2 || !strongRejectWrapper2) {
        return;
      }

      jsi::Runtime &rt = strongResolveWrapper2->runtime();
      jsi::Value arg = convertObjCObjectToJSIValue(rt, result);
      strongResolveWrapper2->callback().call(rt, arg);

      strongResolveWrapper2->destroy();
      strongRejectWrapper2->destroy();
    });

    isSettled = YES;
  };

  RCTPromiseRejectBlock rejectBlock = ^(NSString *code, NSString *message, NSError *error) {
    if (isSettled) {
      // The promise is already either resolved or rejected.
      return;
    }

    auto strongResolveWrapper = weakResolveWrapper.lock();
    auto strongRejectWrapper = weakRejectWrapper.lock();
    if (!strongResolveWrapper || !strongRejectWrapper) {
      return;
    }

    strongRejectWrapper->jsInvoker().invokeAsync([weakResolveWrapper, weakRejectWrapper, code, message]() {
      auto strongResolveWrapper2 = weakResolveWrapper.lock();
      auto strongRejectWrapper2 = weakRejectWrapper.lock();
      if (!strongResolveWrapper2 || !strongRejectWrapper2) {
        return;
      }

      jsi::Runtime &rt = strongRejectWrapper2->runtime();
      jsi::Value jsError = makeCodedError(rt, code, message);

      strongRejectWrapper2->callback().call(rt, jsError);

      strongResolveWrapper2->destroy();
      strongRejectWrapper2->destroy();
    });

    isSettled = YES;
  };

  setupBlock(resolveBlock, rejectBlock);
}

#pragma mark - Weak objects

bool isWeakRefSupported(jsi::Runtime &runtime) {
  return runtime.global().hasProperty(runtime, "WeakRef");
}

std::shared_ptr<jsi::Object> createWeakRef(jsi::Runtime &runtime, std::shared_ptr<jsi::Object> object) {
  jsi::Object weakRef = runtime
    .global()
    .getProperty(runtime, "WeakRef")
    .asObject(runtime)
    .asFunction(runtime)
    .callAsConstructor(runtime, jsi::Value(runtime, *object))
    .asObject(runtime);
  return std::make_shared<jsi::Object>(std::move(weakRef));
}

std::shared_ptr<jsi::Object> derefWeakRef(jsi::Runtime &runtime, std::shared_ptr<jsi::Object> object) {
  jsi::Value ref = object->getProperty(runtime, "deref")
    .asObject(runtime)
    .asFunction(runtime)
    .callWithThis(runtime, *object);

  if (ref.isUndefined()) {
    return nullptr;
  }
  return std::make_shared<jsi::Object>(ref.asObject(runtime));
}

#pragma mark - Errors

jsi::Value makeCodedError(jsi::Runtime &runtime, NSString *code, NSString *message) {
  jsi::String jsCode = convertNSStringToJSIString(runtime, code);
  jsi::String jsMessage = convertNSStringToJSIString(runtime, message);

  return runtime
    .global()
    .getProperty(runtime, "ExpoModulesCore_CodedError")
    .asObject(runtime)
    .asFunction(runtime)
    .callAsConstructor(runtime, {
      jsi::Value(runtime, jsCode),
      jsi::Value(runtime, jsMessage)
    });
}

} // namespace expo

@implementation EXJSIUtils

+ (nonnull EXJavaScriptObject *)createNativeModuleObject:(nonnull EXJavaScriptRuntime *)runtime
{
  std::shared_ptr<jsi::Object> nativeModule = std::make_shared<jsi::Object>(expo::NativeModule::createInstance(*[runtime get]));
  return [[EXJavaScriptObject alloc] initWith:nativeModule runtime:runtime];
}

+ (void)emitEvent:(nonnull NSString *)eventName
         toObject:(nonnull EXJavaScriptObject *)object
    withArguments:(nonnull NSArray<id> *)arguments
        inRuntime:(nonnull EXJavaScriptRuntime *)runtime
{
  const std::vector<jsi::Value> argumentsVector(expo::convertNSArrayToStdVector(*[runtime get], arguments));
  expo::EventEmitter::emitEvent(*[runtime get], *[object get], [eventName UTF8String], std::move(argumentsVector));
}

@end
