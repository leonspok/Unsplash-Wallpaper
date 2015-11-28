//
//  LPMenubarIconAnimator.m
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 27/03/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "LPNSStatusItemIconAnimator.h"

@implementation LPNSStatusItemIconAnimator {
    NSTimer *frameTimer;
    NSInteger currentFrame;
}

- (id)initWithStatusItem:(NSStatusItem *)statusItem
                  frames:(NSArray *)frames
           frameDuration:(NSTimeInterval)frameDuration {
    self = [super init];
    if (self) {
        self.statusItem = statusItem;
        self.frames = frames;
        self.frameDuration = frameDuration;
    }
    return self;
}

- (BOOL)animating {
    return (frameTimer != nil);
}

- (void)startAnimating {
    [self stopAnimating];
    currentFrame = 0;
    frameTimer = [NSTimer scheduledTimerWithTimeInterval:self.frameDuration target:self selector:@selector(changeFrame) userInfo:self repeats:YES];
    [self changeFrame];
}

- (void)changeFrame {
    currentFrame %= self.frames.count;
    NSImage *frame = [self.frames objectAtIndex:currentFrame];
    [self.statusItem setImage:frame];
    currentFrame++;
}

- (void)stopAnimating {
    if (frameTimer) {
        [frameTimer invalidate];
        frameTimer = nil;
    }
}

@end
