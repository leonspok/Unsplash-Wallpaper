//
//  LPUnsplashImageManager.h
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 31/01/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPUnsplashWallpaper.h"

typedef enum {
    LPUnsplashImageManagerCollectionFeatured = 0,
    LPUnsplashImageManagerCollectionAll = 1
} LPUnsplashImageManagerCollection;

typedef enum {
    LPUnsplashLoadImageModeRandom,
    LPUnsplashLoadImageModeSuccessive,
    LPUnsplashLoadImageModeRecent
} LPUnsplashLoadImageMode;

typedef enum {
    LPUnsplashImageLandscape,
    LPUnsplashImagePortrait,
    LPUnsplashImageLandscapeOrPortrait
} LPUnsplashImageOrientation;

@interface LPUnsplashImageManager : NSObject

@property (nonatomic, readonly) NSDate *lastIndexUpdate;
@property (nonatomic, assign) LPUnsplashImageManagerCollection collection;
@property (nonatomic, assign) LPUnsplashImageOrientation preferredOrientation;
@property (nonatomic, assign, readonly) NSUInteger imageLoadsPerHourAvailable;

+ (instancetype)sharedManager;

- (void)loadImageCurrentImageName:(NSString *)currentImageName
                             mode:(LPUnsplashLoadImageMode)mode
                          success:(void (^)(NSString *pathToImage, NSString *name))success
                          failure:(void (^)(NSError *))failure;

- (void)loadNextImageCurrentImageName:(NSString *)currentImageName
                              success:(void (^)(NSString *pathToImage, NSString *name))success
                              failure:(void (^)(NSError *error))failure;

- (void)loadRandomImageCurrentImageName:(NSString *)currentImageName
                                success:(void (^)(NSString *pathToImage, NSString *name))success
                                failure:(void (^)(NSError *error))failure;

- (void)loadRecentImage:(void (^)(NSString *pathToImage, NSString *name))success
                failure:(void (^)(NSError *error))failure;

- (void)addToBlackListImageWithName:(NSString *)name;
- (NSInteger)clearBlackList;

- (LPUnsplashWallpaper *)wallpaperForName:(NSString *)name;
- (NSURL *)URLForProfileName:(NSString *)profileName;

@end
