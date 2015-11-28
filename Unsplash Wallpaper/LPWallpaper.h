//
//  LPWallpaper.h
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 25/03/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface LPWallpaper : NSManagedObject

@property (nonatomic, retain) NSNumber * blacklisted;
@property (nonatomic, retain) NSDate * dateAdded;
@property (nonatomic, retain) NSString * fullImageURL;
@property (nonatomic, retain) NSNumber * height;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * mediumImageURL;
@property (nonatomic, retain) NSString * source;
@property (nonatomic, retain) NSNumber * width;

@end
