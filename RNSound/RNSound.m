#import "RNSound.h"

#if __has_include("RCTUtils.h")
    #import "RCTUtils.h"
#else
    #import <React/RCTUtils.h>
#endif

@implementation RNSound {
  NSMutableDictionary* _playerPool;
  NSMutableDictionary* _callbackPool;
  RCTResponseSenderBlock _loadCallback;
}

-(NSMutableDictionary*) playerPool {
  if (!_playerPool) {
    _playerPool = [NSMutableDictionary new];
  }
  return _playerPool;
}

-(NSMutableDictionary*) callbackPool {
  if (!_callbackPool) {
    _callbackPool = [NSMutableDictionary new];
  }
  return _callbackPool;
}

-(AVPlayer*) playerForKey:(nonnull NSNumber*)key {
  return [[self playerPool] objectForKey:key];
}

-(NSNumber*) keyForPlayer:(nonnull AVPlayer*)player {
  return [[[self playerPool] allKeysForObject:player] firstObject];
}

-(RCTResponseSenderBlock) callbackForKey:(nonnull NSNumber*)key {
  return [[self callbackPool] objectForKey:key];
}

-(NSString *) getDirectory:(int)directory {
  return [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) firstObject];
}

-(void) audioPlayerDidFinishPlaying:(AVPlayer*)player {
  NSNumber* key = [self keyForPlayer:player];
  if (key != nil) {
    RCTResponseSenderBlock callback = [self callbackForKey:key];
    if (callback) {
      callback(@[@(YES)]);
    }
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

        AVPlayer *player = (AVPlayer *) object;
        if ([keyPath isEqualToString:@"status"]) {
            if (player.status == AVPlayerStatusFailed) {
              NSNumber* key = [self keyForPlayer:player];
              if (key != nil) {
                RCTResponseSenderBlock callback = [self callbackForKey:key];
                if (callback) {
                  callback(@[@(NO)]);
                }
              }
              NSLog(@"AVPlayer Failed");

            } else if (player.status == AVPlayerStatusReadyToPlay) {
                NSLog(@"AVPlayerStatusReadyToPlay");
                RCTResponseSenderBlock callback = self->_loadCallback;
                callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration))}]);

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

  if ([fileName hasPrefix:@"http"]) {
    fileNameUrl = [NSURL URLWithString:[fileName stringByRemovingPercentEncoding]];
  }
  else {
    fileNameUrl = [NSURL fileURLWithPath:[fileName stringByRemovingPercentEncoding]];
  }

  if (fileNameUrl) {
    AVPlayerItem* playerItem = [AVPlayerItem playerItemWithURL:fileNameUrl];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
    player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
  }

  if (player) {
    //player.delegate = self;
    //player.enableRate = YES;
    //[player prepareToPlay];
    [player addObserver:self forKeyPath:@"status" options:0 context:nil];
    [player addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [[self playerPool] setObject:player forKey:key];
    self->_loadCallback = [callback copy];
  } else {
    callback(@[RCTJSErrorFromNSError(error)]);
  }
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    [[self callbackPool] setObject:[callback copy] forKey:key];
    [player play];
  }
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)key) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    [player pause];
  }
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)key) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    [player pause];
    [player seekToTime: CMTimeMake(0, 1)];
  }
}

RCT_EXPORT_METHOD(release:(nonnull NSNumber*)key) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    [player pause];
    [player removeObserver:self forKeyPath:@"status" context:nil];
    [player removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    [[self callbackPool] removeObjectForKey:player];
    [[self playerPool] removeObjectForKey:key];
  }
}

RCT_EXPORT_METHOD(setVolume:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    player.volume = [value floatValue];
  }
}

RCT_EXPORT_METHOD(setPan:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    // Doesn't work for AVPlayer
    //player.pan = [value floatValue];
  }
}

RCT_EXPORT_METHOD(setNumberOfLoops:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    //player.numberOfLoops = [value intValue];
  }
}

RCT_EXPORT_METHOD(setSpeed:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    player.rate = [value floatValue];
  }
}


RCT_EXPORT_METHOD(setCurrentTime:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    [player seekToTime: CMTimeMake([value doubleValue], 1)];
  }
}

RCT_EXPORT_METHOD(getCurrentTime:(nonnull NSNumber*)key
                  withCallback:(RCTResponseSenderBlock)callback) {
  AVPlayer* player = [self playerForKey:key];
  if (player) {
    callback(@[@(CMTimeGetSeconds([player currentTime]))]);
  } else {
    callback(@[@(-1)]);
  }
}

@end
