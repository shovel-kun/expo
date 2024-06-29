// Copyright 2024-present 650 Industries. All rights reserved.

#import <React/bridging/Promise.h>
#import <ExpoModulesCore/EXJavaScriptPromise.h>

@implementation EXJavaScriptPromise {
  __weak EXJavaScriptRuntime *_runtime;

  std::shared_ptr<react::AsyncPromise<jsi::Value>> _promise;
}

- (nonnull instancetype)initWithRuntime:(nonnull EXJavaScriptRuntime *)runtime
                            callInvoker:(std::shared_ptr<react::CallInvoker>)callInvoker
{
  auto promise = std::make_shared<react::AsyncPromise<jsi::Value>>(*[runtime get], callInvoker);
  jsi::Runtime *rt = [runtime get];
  auto jsObjectPtr = std::make_shared<jsi::Object>(promise->get(*rt));

  if (self = [super initWith:jsObjectPtr runtime:runtime]) {
    _runtime = runtime;
    _promise = std::make_shared<react::AsyncPromise<jsi::Value>>(*[runtime get], callInvoker);
  }
  return self;
}

- (nonnull jsi::Object *)get
{
  jsi::Runtime *runtime = [_runtime get];
  jsi::Value value(*runtime, _promise->get(*runtime));
  return value.asObject(*runtime);
}

- (void)resolve:(nonnull EXJavaScriptValue *)value
{
  _promise->resolve(value);
}

//- (void)reject:(nonnull EXJavaScriptValue *)value
//{
//  jsi::JSError error(*[_runtime get], [value get]);
//  _promise->reject(error);
//}

- (void)awaitResult:(void(^_Nonnull)(const jsi::Value result))callback
{
  jsi::Runtime *runtime = [_runtime get];
  jsi::Object object = _promise->get(*runtime);

  jsi::HostFunctionType callbackHost = [callback](jsi::Runtime &runtime, const jsi::Value &thisValue, const jsi::Value *args, size_t count) -> jsi::Value {
    callback(jsi::Value(runtime, args[0]));
    return jsi::Value(runtime, args[0]);
  };

  jsi::PropNameID callbackFunctionProp = jsi::PropNameID::forAscii(*runtime, "fn", 2);

  object
    .getPropertyAsFunction(*runtime, "then")
    .callWithThis(*runtime, object, {
      jsi::Function::createFromHostFunction(*runtime, callbackFunctionProp, 1, callbackHost)
    });
}

@end
