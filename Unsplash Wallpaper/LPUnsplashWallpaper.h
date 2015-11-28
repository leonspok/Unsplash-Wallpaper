//
//  LPUnsplashWallpaper.h
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 13/08/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "LPWallpaper.h"


@interface LPUnsplashWallpaper : LPWallpaper

@property (nonatomic, retain) NSString * author;
@property (nonatomic, retain) NSString * authorProfileName;
@property (nonatomic, retain) NSString * collection;
@property (nonatomic, retain) NSNumber * pageInAllImages;
@property (nonatomic, retain) NSNumber * pageInCuratedBatches;

@end
