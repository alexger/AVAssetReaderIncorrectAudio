//
//  ViewController.m
//  AVAssetReaderIncorrectAudio
//
//  Created by Alex Gershovich on 5/6/18.
//  Copyright © 2018 Lightricks. All rights reserved.
//

#import "ViewController.h"

@import AVFoundation;
@import CoreMedia;
@import Foundation;

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Sample video, recorded on iPhone 6s.
  NSURL *videoURL = [[NSBundle mainBundle] URLForResource:@"IMG_5579" withExtension:@"MOV"];
  AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];

  // Create composition mapping the original video, one to one.
  CMTimeRange originalTimeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
  AVMutableComposition *composition = [AVMutableComposition composition];
  [composition insertTimeRange:originalTimeRange ofAsset:asset atTime:kCMTimeZero error:nil];

  // Scale the duration of the tracks by 2.
  CMTime scaledDuration = CMTimeMultiply(originalTimeRange.duration, 2);
  [composition scaleTimeRange:originalTimeRange toDuration:scaledDuration];

  // Create reader with audio track output.
  AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:composition error:nil];
  AVAssetTrack *audioTrack = [composition tracksWithMediaType:AVMediaTypeAudio].firstObject;
  NSDictionary *audioSettings = @{
    AVFormatIDKey: @(kAudioFormatLinearPCM),
    AVLinearPCMIsFloatKey: @YES,
    AVLinearPCMBitDepthKey: @32,
    AVLinearPCMIsNonInterleaved: @NO,
  };
  AVAssetReaderTrackOutput *audioOutput = [AVAssetReaderTrackOutput
                                           assetReaderTrackOutputWithTrack:audioTrack
                                           outputSettings:audioSettings];
  audioOutput.supportsRandomAccess = YES;
  audioOutput.alwaysCopiesSampleData = NO;
  // This does not affect the bug - it will also occur without this line.
  audioOutput.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmVarispeed;

  [reader addOutput:audioOutput];

  reader.timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
  [reader startReading];

  // First, read the whole composition and sum all buffers' durations.
  int readBuffersInFirstPass = 0;
  CMTime readBuffersInFirstPassTotalDuration = kCMTimeZero;
  while (1) {
    CMSampleBufferRef sampleBuffer = [audioOutput copyNextSampleBuffer];
    if (!sampleBuffer) {
      break;
    }

    CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
    readBuffersInFirstPassTotalDuration = CMTimeAdd(readBuffersInFirstPassTotalDuration, duration);
    ++readBuffersInFirstPass;

    CFRelease(sampleBuffer);
  }

  // This triggers the bug by resetting the time ranges.
  [audioOutput resetForReadingTimeRanges:@[[NSValue valueWithCMTimeRange:CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)]]];

  // Read the audio again. This time it comes "unedited", that is without scaled duration.
  int readBuffersInSecondPass = 0;
  CMTime readBuffersInSecondPassTotalDuration = kCMTimeZero;
  while (1) {
    CMSampleBufferRef sampleBuffer = [audioOutput copyNextSampleBuffer];
    if (!sampleBuffer) {
      break;
    }

    CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
    readBuffersInSecondPassTotalDuration = CMTimeAdd(readBuffersInSecondPassTotalDuration, duration);
    ++readBuffersInSecondPass;

    CFRelease(sampleBuffer);
  }

  // The total durations will be incorrect: there is no scaling of the original audio.
  // Duration will be twice shorter than expected. Also, the number of read buffers will be half
  // the amount in the 1st pass.
  assert(CMTimeCompare(readBuffersInFirstPassTotalDuration, readBuffersInSecondPassTotalDuration) == 0);

  // Further passes will keep returning incorrect (un-edited) results.
}

@end
