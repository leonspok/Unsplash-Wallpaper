//
//  LPNSImageAnimator.h
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 27/03/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface LPNSImageAnimator : NSObject

@property (nonatomic, weak) NSImageView *imageView;
@property (nonatomic, weak) NSArray *frames;
@property (nonatomic, assign) NSTimeInterval frameDuration;

- (id)initWithImageView:(NSImageView *)imageView
                 frames:(NSArray *)frames
          frameDuration:(NSTimeInterval)frameDuration;

- (void)startAnimating;
- (void)stopAnimating;

@end
