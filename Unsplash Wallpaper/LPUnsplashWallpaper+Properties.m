//
//  LPUnsplashWallpaper+Properties.m
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 25/03/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "LPUnsplashWallpaper+Properties.h"

@implementation LPUnsplashWallpaper (Properties)

- (void)setUnsplashCollection:(LPUnsplashImageManagerCollection)unsplashCollection {
    switch (unsplashCollection) {
        case LPUnsplashImageManagerCollectionAll:
            self.collection = @"all";
            break;
        case LPUnsplashImageManagerCollectionFeatured:
            self.collection = @"featured";
            
        default:
            break;
    }
}

- (LPUnsplashImageManagerCollection)unsplashCollection {
    if ([self.collection isEqualToString:@"all"]) {
        return LPUnsplashImageManagerCollectionAll;
    } else if ([self.collection isEqualToString:@"featured"]) {
        return LPUnsplashImageManagerCollectionFeatured;
    } else {
        return LPUnsplashImageManagerCollectionAll;
    }
}

@end
