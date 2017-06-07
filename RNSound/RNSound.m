#import "RNSound.h"

#if __has_include("RCTUtils.h")
    #import "RCTUtils.h"
#else
    #import <React/RCTUtils.h>
#endif

@implementation RNSound {
  RCTResponseSenderBlock loadCallback;
  AVPlayer* player;
  RCTResponseSenderBlock endCallback;
}

-(NSString *) getDirectory:(int)directory {
  return [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) firstObject];
}

-(void) audioPlayerDidFinishPlaying:(NSNotification *)notification {
  if (self->endCallback) {
    RCTResponseSenderBlock callback = self->endCallback;
    callback(@[@(YES)]);
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

        AVPlayer *player = (AVPlayer *) object;
        if ([keyPath isEqualToString:@"status"]) {
            if (player.status == AVPlayerStatusFailed) {
              RCTResponseSenderBlock callback = self->endCallback;
              if (callback) {
                callback(@[@(NO)]);
              }
              NSLog(@"AVPlayer Failed");

            } else if (player.status == AVPlayerStatusReadyToPlay) {
                NSLog(@"AVPlayerStatusReadyToPlay");
                RCTResponseSenderBlock callback = self->loadCallback;
                if (callback) {
                  callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration))}]);
                  self->loadCallback = nil;
                }


            } else if (player.status == AVPlayerItemStatusUnknown) {
                NSLog(@"AVPlayer Unknown");

            }
        } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
          NSArray *timeRanges = (NSArray*)[change objectForKey:NSKeyValueChangeNewKey];
          NSLog(@"Timeranges count: %d", [timeRanges count]);
          if (timeRanges && [timeRanges count]) {
              CMTimeRange timerange = [[timeRanges objectAtIndex:0] CMTimeRangeValue];
          }
        }
    }

RCT_EXPORT_MODULE();

-(NSDictionary *)constantsToExport {
  return @{@"IsAndroid": [NSNumber numberWithBool:NO],
           @"MainBundlePath": [[NSBundle mainBundle] bundlePath],
           @"NSDocumentDirectory": [self getDirectory:NSDocumentDirectory],
           @"NSLibraryDirectory": [self getDirectory:NSLibraryDirectory],
           @"NSCachesDirectory": [self getDirectory:NSCachesDirectory],
           };
}

RCT_EXPORT_METHOD(enable:(BOOL)enabled) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory: AVAudioSessionCategoryAmbient error: nil];
  [session setActive: enabled error: nil];
}

RCT_EXPORT_METHOD(setCategory:(NSString *)categoryName
    mixWithOthers:(BOOL)mixWithOthers) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  NSString *category = nil;

  if ([categoryName isEqual: @"Ambient"]) {
    category = AVAudioSessionCategoryAmbient;
  } else if ([categoryName isEqual: @"SoloAmbient"]) {
    category = AVAudioSessionCategorySoloAmbient;
  } else if ([categoryName isEqual: @"Playback"]) {
    category = AVAudioSessionCategoryPlayback;
  } else if ([categoryName isEqual: @"Record"]) {
    category = AVAudioSessionCategoryRecord;
  } else if ([categoryName isEqual: @"PlayAndRecord"]) {
    category = AVAudioSessionCategoryPlayAndRecord;
  }
  #if TARGET_OS_IOS
  else if ([categoryName isEqual: @"AudioProcessing"]) {
      category = AVAudioSessionCategoryAudioProcessing;
  }
  #endif
    else if ([categoryName isEqual: @"MultiRoute"]) {
    category = AVAudioSessionCategoryMultiRoute;
  }

  if (category) {
    if (mixWithOthers) {
        [session setCategory: category withOptions:AVAudioSessionCategoryOptionMixWithOthers error: nil];
    } else {
      [session setCategory: category error: nil];
    }
  }
}

RCT_EXPORT_METHOD(enableInSilenceMode:(BOOL)enabled) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory: AVAudioSessionCategoryPlayback error: nil];
  [session setActive: enabled error: nil];
}

RCT_EXPORT_METHOD(prepare:(NSString*)fileName withKey:(nonnull NSNumber*)key
                  withCallback:(RCTResponseSenderBlock)callback) {
  NSError* error;
  NSURL* fileNameUrl;
  AVPlayer* player;
  AVPlayerItem* playerItem;

  if ([fileName hasPrefix:@"http"]) {
    fileNameUrl = [NSURL URLWithString:[fileName stringByRemovingPercentEncoding]];
    playerItem = [AVPlayerItem playerItemWithURL:fileNameUrl];
  }
  else {
    fileNameUrl = [NSURL fileURLWithPath:[fileName stringByRemovingPercentEncoding]];
    AVAsset *asset = [AVURLAsset URLAssetWithURL:fileNameUrl options:nil];
    playerItem = [AVPlayerItem playerItemWithAsset:asset];
  }

  if (playerItem) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
    player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
  }

  if (player) {
    if (self->player) {
      [self->player removeObserver:self forKeyPath:@"status" context:nil];
      [self->player removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    }
    [player addObserver:self forKeyPath:@"status" options:0 context:nil];
    [player addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    self->player = player;
    self->loadCallback = [callback copy];
  } else {
    callback(@[RCTJSErrorFromNSError(error)]);
  }
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
  AVPlayer* player = self->player;
  if (player) {
    self->endCallback = [callback copy];
    [player play];
  }
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)key) {
  AVPlayer* player = self->player;
  if (player) {
    [player pause];
  }
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)key) {
  AVPlayer* player = self->player;
  if (player) {
    [player pause];
    [player seekToTime: CMTimeMake(0, 1)];
  }
}

RCT_EXPORT_METHOD(release:(nonnull NSNumber*)key) {
  AVPlayer* player = self->player;
  if (player) {
    [player pause];
    [player removeObserver:self forKeyPath:@"status" context:nil];
    [player removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    self->player = nil;
    self->loadCallback = nil;
    self->endCallback = nil;
  }
}

RCT_EXPORT_METHOD(setVolume:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = self->player;
  if (player) {
    player.volume = [value floatValue];
  }
}

RCT_EXPORT_METHOD(setPan:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = self->player;
  if (player) {
    // Doesn't work for AVPlayer
    //player.pan = [value floatValue];
  }
}

RCT_EXPORT_METHOD(setNumberOfLoops:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = self->player;
  if (player) {
    //player.numberOfLoops = [value intValue];
  }
}

RCT_EXPORT_METHOD(setSpeed:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = self->player;
  if (player) {
    player.rate = [value floatValue];
  }
}


RCT_EXPORT_METHOD(setCurrentTime:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = self->player;
  if (player) {
    [player seekToTime: CMTimeMake([value doubleValue], 1)];
  }
}

RCT_EXPORT_METHOD(getCurrentTime:(nonnull NSNumber*)key
                  withCallback:(RCTResponseSenderBlock)callback) {
  AVPlayer* player = self->player;
  if (player) {
    callback(@[@(CMTimeGetSeconds([player currentTime]))]);
  } else {
    callback(@[@(-1)]);
  }
}

@end
