import glob
import os
import sys

FALLBACK_SOURCE = """#import "./include/agora_rtc_engine/AgoraSurfaceViewFactory.h"

@interface AgoraSurfaceView : NSObject <FlutterPlatformView>

@property(nonatomic, strong) VideoViewController *controller;

@property(nonatomic, strong) UIView *surfaceView;

@property(nonatomic, strong) FlutterMethodChannel *methodChannel;

@property(nonatomic) NSString *viewType;

@property(nonatomic) int64_t platformViewId;

- (instancetype)initWith:(NSObject<FlutterBinaryMessenger> *)messenger
              controller:(VideoViewController *)controller
                   frame:(CGRect)frame
                  viewId:(int64_t)viewId
                    args:(NSDictionary *)args;

@end

@implementation AgoraSurfaceView

- (instancetype)initWith:(NSObject<FlutterBinaryMessenger> *)messenger
              controller:(VideoViewController *)controller
                   frame:(CGRect)frame
                  viewId:(int64_t)viewId
                    args:(NSDictionary *)args {
  if (self = [super init]) {
    self.controller = controller;
    self.viewType = [args objectForKey:@"viewType"];
    self.surfaceView = (UIView *)[self.controller createPlatformRender:viewId frame:frame];
    self.platformViewId = viewId;
    self.methodChannel = [FlutterMethodChannel
        methodChannelWithName:
            [NSString
                stringWithFormat:@"agora_rtc_ng/AgoraSurfaceView_%lld",
              viewId]
              binaryMessenger:messenger];
    
    __weak __typeof__(self) weakSelf = self;
    [self.methodChannel setMethodCallHandler:^(FlutterMethodCall *_Nonnull call,
                                               FlutterResult _Nonnull result) {
      if (weakSelf != nil) {
        [weakSelf onMethodCall:call result:result];
      }
    }];
  }
  return self;
}

- (void)dealloc {
    [self.controller dePlatformRenderRef:self.platformViewId];
    self.surfaceView = NULL;
}

- (nonnull UIView *)view {
  return self.surfaceView;
}

- (void)onMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([@"getNativeViewPtr" isEqualToString:call.method]) {
      if (self.surfaceView) {
          [self.controller addPlatformRenderRef:self.platformViewId];
          uint64_t viewId = (uint64_t)self.surfaceView;
          result(@(viewId));
      } else {
          result(@(0));
      }
  } else if ([@"deleteNativeViewPtr" isEqualToString:call.method]) {
      result(@(0));
  }
}

@end

@interface AgoraSurfaceViewFactory ()

@property(nonatomic, strong) NSObject<FlutterBinaryMessenger> *messenger;
@property(nonatomic, strong) VideoViewController *controller;

@end

@implementation AgoraSurfaceViewFactory

- (instancetype)initWith:(NSObject<FlutterBinaryMessenger> *)messenger
              controller:(VideoViewController *)controller {
  if (self = [super init]) {
    self.messenger = messenger;
    self.controller = controller;
  }
  return self;
}

- (nonnull NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame
                                            viewIdentifier:(int64_t)viewId
                                                 arguments:(id _Nullable)args {
  return [[AgoraSurfaceView alloc] initWith:self.messenger
                                 controller:self.controller
                                      frame:frame
                                     viewId:viewId
                                       args:args];
}

- (NSObject<FlutterMessageCodec> *)createArgsCodec {
  return [FlutterStandardMessageCodec sharedInstance];
}

@end
"""

def patch_agora():
    search_patterns = [
        os.path.expanduser('~/.pub-cache/hosted/pub.dev/agora_rtc_engine-*/ios/agora_rtc_engine/Sources/agora_rtc_engine/AgoraSurfaceViewFactory.mm'),
    ]
    if 'LOCALAPPDATA' in os.environ:
        search_patterns.append(
            os.path.join(os.environ['LOCALAPPDATA'], 'Pub', 'Cache', 'hosted', 'pub.dev', 'agora_rtc_engine-*', 'ios', 'agora_rtc_engine', 'Sources', 'agora_rtc_engine', 'AgoraSurfaceViewFactory.mm')
        )

    matches = []
    for pat in search_patterns:
        matches.extend(glob.glob(pat))

    if not matches:
        print("[Agora Patch] No AgoraSurfaceViewFactory.mm found in pub-cache. Skipping.")
        return

    for path in matches:
        print(f"[Agora Patch] Inspecting {path}...")
        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()

            if len(content.strip()) == 0:
                print(f"[Agora Patch] File is empty! Writing full fallback source...")
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(FALLBACK_SOURCE)
                print(f"[Agora Patch] Fallback written successfully (size: {len(FALLBACK_SOURCE)} bytes)")
            elif 'typeof(self)' in content:
                new_content = content.replace('typeof(self)', '__typeof__(self)')
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"[Agora Patch] Replaced 'typeof(self)' with '__typeof__(self)' (size: {len(new_content)} bytes)")
            else:
                print(f"[Agora Patch] File is already valid and does not contain raw 'typeof(self)' (size: {len(content)} bytes)")
        except Exception as e:
            print(f"[Agora Patch] Error processing {path}: {e}")

if __name__ == '__main__':
    patch_agora()
