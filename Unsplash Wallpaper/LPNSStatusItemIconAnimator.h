//
//  LPMenubarIconAnimator.h
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 27/03/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface LPNSStatusItemIconAnimator : NSObject

@property (nonatomic, weak) NSStatusItem *statusItem;
@property (nonatomic, weak) NSArray *frames;
@property (nonatomic, assign) NSTimeInterval frameDuration;

@property (nonatomic, readonly) BOOL animating;

- (id)initWithStatusItem:(NSStatusItem *)statusItem
                  frames:(NSArray *)frames
           frameDuration:(NSTimeInterval)frameDuration;

- (void)startAnimating;
- (void)stopAnimating;

@end
