//
//  LPUnsplashImageManager.m
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 31/01/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "LPUnsplashImageManager.h"
#import	<CommonCrypto/CommonDigest.h>
#import "AFNetworking.h"
#import "LPUnsplashWallpaper+Properties.h"
#import "CoreData+MagicalRecord.h"
#import "UnsplashConstants.h"

@import AppKit;

#define MAX_LOADED_IMAGES_PER_HOUR 30

static NSString *const kUnsplashBaseURL = @"https://unsplash.com";
static NSString *const kUnsplashFilePrefix = @"unsplash_";

static NSString *const kLastIndexUpdateKey = @"LastIndexUpdate";
static NSString *const kCollectionKey = @"Collection";
static NSString *const kUnsplashImageOrientationKey = @"UnsplashImageOrientation";
static NSString *const kNumberOfPagesInAllKey = @"NumberOfPagesInAllKey";
static NSString *const kItemsPerPageInAllKey = @"ItemsPerPageInAllKey";
static NSString *const kNumberOfPagesInFeaturedKey = @"NumberOfPagesInFeaturedKey";
static NSString *const kItemsPerPageInFeaturedKey = @"ItemsPerPageInFeaturedKey";

@implementation NSString (Hash)

- (NSString *)md5String {
    const char *data = [self UTF8String];
    unsigned char hashBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data, (CC_LONG)strlen(data), hashBuffer);
    NSMutableString *resultString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for (int i= 0;	i < CC_MD5_DIGEST_LENGTH; i++) {
        [resultString appendFormat:@"%02X", hashBuffer[i]];
    }
    return resultString;
}

@end

@implementation NSMutableArray (Shuffling)

- (void)shuffle {
    NSUInteger count = [self count];
    for (NSUInteger i = 0; i < count; ++i) {
        NSInteger remainingCount = count - i;
        NSInteger exchangeIndex = i + arc4random_uniform((u_int32_t )remainingCount);
        [self exchangeObjectAtIndex:i withObjectAtIndex:exchangeIndex];
    }
}

@end

@interface LPUnsplashImageManager()

@property (nonatomic) NSUInteger numberOfPagesInAll;
@property (nonatomic) NSUInteger itemsPerPageInAll;
@property (nonatomic) NSUInteger numberOfPagesInFeatured;
@property (nonatomic) NSUInteger itemsPerPageInFeatured;

@end

@implementation LPUnsplashImageManager {
    NSString *cacheFolder;
    NSString *applicationSupportFolder;
    
    NSURLSession *session;
    NSMutableDictionary *updateIndexTasks;
    AFHTTPRequestSerializer *serializer;
    dispatch_queue_t findImageQueue;
    
    NSTimer *limitsTimer;
}

+ (instancetype)sharedManager {
    static LPUnsplashImageManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[LPUnsplashImageManager alloc] init];
    });
    return manager;
}

- (id)init {
    self = [super init];
    if (self) {
        findImageQueue = dispatch_queue_create("findImageQueue", DISPATCH_QUEUE_CONCURRENT);
        
        serializer = [[AFHTTPRequestSerializer alloc] init];
        [serializer setValue:[NSString stringWithFormat:@"Client-ID %@", kUnsplashAppID] forHTTPHeaderField:@"Authorization"];
        [serializer setValue:@"v1" forHTTPHeaderField:@"Accept-Version"];
        
        session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        updateIndexTasks = [NSMutableDictionary dictionary];
        [self updatePaths];
        
        [self resetLimits];
        dispatch_async(dispatch_get_main_queue(), ^{
            limitsTimer = [NSTimer scheduledTimerWithTimeInterval:60.0*60.0f target:self selector:@selector(resetLimits) userInfo:nil repeats:YES];
        });
    }
    return self;
}

- (void)updatePaths {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    cacheFolder = [paths firstObject];
    paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    applicationSupportFolder = [[paths firstObject] stringByAppendingPathComponent:@"Unsplash Wallpaper"];
}

#pragma mark Limits

- (void)resetLimits {
    _imageLoadsPerHourAvailable = MAX_LOADED_IMAGES_PER_HOUR;
}

#pragma mark Getters and Setters

- (NSDate *)lastIndexUpdate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastIndexUpdateKey];
}

- (void)setLastIndexUpdate:(NSDate *)lastIndexUpdate {
    if (!lastIndexUpdate) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLastIndexUpdateKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:lastIndexUpdate forKey:kLastIndexUpdateKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (LPUnsplashImageManagerCollection)collection {
    NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:kCollectionKey];
    return (LPUnsplashImageManagerCollection)[number integerValue];
}

- (void)setCollection:(LPUnsplashImageManagerCollection)collection {
    [[NSUserDefaults standardUserDefaults] setObject:@(collection) forKey:kCollectionKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (LPUnsplashImageOrientation)preferredOrientation {
    NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:kUnsplashImageOrientationKey];
    if (!number) {
        return LPUnsplashImageLandscape;
    }
    return (LPUnsplashImageOrientation)[number integerValue];
}

- (void)setPreferredOrientation:(LPUnsplashImageOrientation)orientation {
    [[NSUserDefaults standardUserDefaults] setObject:@(orientation) forKey:kUnsplashImageOrientationKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSUInteger)numberOfPagesInAll {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kNumberOfPagesInAllKey] unsignedIntegerValue];
}

- (void)setNumberOfPagesInAll:(NSUInteger)numberOfPagesInAll {
    [[NSUserDefaults standardUserDefaults] setObject:@(numberOfPagesInAll) forKey:kNumberOfPagesInAllKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSUInteger)itemsPerPageInAll {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kItemsPerPageInAllKey] unsignedIntegerValue];
}

- (void)setItemsPerPageInAll:(NSUInteger)itemsPerPageInAll {
    [[NSUserDefaults standardUserDefaults] setObject:@(itemsPerPageInAll) forKey:kItemsPerPageInAllKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSUInteger)numberOfPagesInFeatured {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kNumberOfPagesInFeaturedKey] unsignedIntegerValue];
}

- (void)setNumberOfPagesInFeatured:(NSUInteger)numberOfPagesInFeatures {
    [[NSUserDefaults standardUserDefaults] setObject:@(numberOfPagesInFeatures) forKey:kNumberOfPagesInFeaturedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSUInteger)itemsPerPageInFeatured {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kItemsPerPageInFeaturedKey] unsignedIntegerValue];
}

- (void)setItemsPerPageInFeatured:(NSUInteger)itemsPerPageInFeatured {
    [[NSUserDefaults standardUserDefaults] setObject:@(itemsPerPageInFeatured) forKey:kItemsPerPageInFeaturedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark BlackList

- (void)addToBlackListImageWithName:(NSString *)name {
    if (![name hasPrefix:kUnsplashFilePrefix]) {
        return;
    }
    NSString *ID = [name stringByReplacingOccurrencesOfString:kUnsplashFilePrefix withString:@""];
    LPUnsplashWallpaper *wallpaper = [LPUnsplashWallpaper MR_findFirstByAttribute:@"id" withValue:ID];
    wallpaper.blacklisted = @YES;
    [wallpaper.managedObjectContext MR_saveToPersistentStoreAndWait];
}

- (NSInteger)clearBlackList {
    NSManagedObjectContext *context = [NSManagedObjectContext MR_contextForCurrentThread];
    NSArray *blackListedImages = [LPUnsplashWallpaper MR_findByAttribute:@"blacklisted" withValue:@YES];
    for (LPUnsplashWallpaper *wallpaper in blackListedImages) {
        wallpaper.blacklisted = @NO;
    }
    [context MR_saveToPersistentStoreAndWait];
    return blackListedImages.count;
}

#pragma mark Load Image

- (NSURL *)URLForProfileName:(NSString *)profileName {
    NSString *urlString = [kUnsplashBaseURL stringByAppendingPathComponent:profileName];
    return [NSURL URLWithString:urlString];
}

- (LPUnsplashWallpaper *)wallpaperForName:(NSString *)name {
    if (![name hasPrefix:kUnsplashFilePrefix]) {
        return nil;
    }
    NSString *wallpaperId = [name stringByReplacingOccurrencesOfString:kUnsplashFilePrefix withString:@""];
    LPUnsplashWallpaper *wallpaper = [LPUnsplashWallpaper MR_findFirstByAttribute:@"id" withValue:wallpaperId inContext:[NSManagedObjectContext MR_defaultContext]];
    return wallpaper;
}

- (NSString *)nameForWallpaper:(LPUnsplashWallpaper *)wallpaper {
    return [NSString stringWithFormat:@"%@%@", kUnsplashFilePrefix, wallpaper.id];
}

- (void)loadImage:(LPUnsplashWallpaper *)wallpaper
          success:(void (^)(NSString *imagePath, NSString *name))success
          failure:(void (^)(NSError *error))failure {
    [[session downloadTaskWithURL:[NSURL URLWithString:wallpaper.fullImageURL] completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSImage *image = [[NSImage alloc] initWithContentsOfURL:location];
            if (!image) {
                if (failure) {
                    failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message":@"No image"}]);
                }
            } else {
                if (_imageLoadsPerHourAvailable != 0) {
                    _imageLoadsPerHourAvailable--;
                }
                
                NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:[self nameForWallpaper:wallpaper]];
                [[NSFileManager defaultManager] moveItemAtPath:[location path] toPath:imagePath error:nil];
                if (success) {
                    success(imagePath, [self nameForWallpaper:wallpaper]);
                }
            }
        } else {
            if (failure) {
                failure(error);
            }
        }
    }] resume];
}

- (void)loadImageCurrentImageName:(NSString *)currentImageName
                             mode:(LPUnsplashLoadImageMode)mode
                          success:(void (^)(NSString *, NSString *))success
                          failure:(void (^)(NSError *))failure {
    
    if (_imageLoadsPerHourAvailable == 0) {
        if (failure) {
            failure([NSError errorWithDomain:NSStringFromClass(self.class) code:2 userInfo:@{@"message": @"Limits exceeded"}]);
        }
        return;
    }
    
    NSString *currentImageID = [currentImageName stringByReplacingOccurrencesOfString:kUnsplashFilePrefix withString:@""];
    
    dispatch_async(findImageQueue, ^{
        LPUnsplashWallpaper *wallpaper;
        switch (mode) {
            case LPUnsplashLoadImageModeRandom:
                wallpaper = [self findRandomImageCurrentImageID:currentImageID];
                break;
            case LPUnsplashLoadImageModeSuccessive:
                wallpaper = [self findNextImageCurrentImageID:currentImageID];
                break;
            case LPUnsplashLoadImageModeRecent:
                wallpaper = [self findRecentImage];
                break;
            default:
                break;
        }
        
        if (!wallpaper) {
            if (failure) {
                failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"Can not find next image"}]);
            }
        } else {
            NSString *imageName = [self nameForWallpaper:wallpaper];
            NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:imageName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
                if (success) {
                    success(imagePath, imageName);
                }
            } else {
                [self loadImage:wallpaper success:success failure:failure];
            }
        }
    });
}

- (LPUnsplashWallpaper *)parseWallpaper:(NSDictionary *)photoJSON batchesPage:(NSInteger)batchesPage allImagesPage:(NSInteger)allImagesPage {
    NSString *ID = [photoJSON objectForKey:@"id"];
    if (!ID) {
        return nil;
    }
    
    __block LPUnsplashWallpaper *photo;
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *context) {
        photo = [LPUnsplashWallpaper MR_findFirstByAttribute:@"id" withValue:ID inContext:context];
        if (photo && [photo.blacklisted boolValue]) {
            photo = nil;
            return;
        }
        
        if (!photo) {
            photo = [LPUnsplashWallpaper MR_createInContext:context];
        }
        
        photo.id = ID;
        if (batchesPage >= 0) {
            photo.pageInCuratedBatches = @(batchesPage);
        }
        if (allImagesPage >= 0) {
            photo.pageInAllImages = @(allImagesPage);
        }
        if ([photoJSON objectForKey:@"user"] && [[photoJSON objectForKey:@"user"] isKindOfClass:NSDictionary.class]) {
            NSDictionary *userInfo = [photoJSON objectForKey:@"user"];
            if ([userInfo objectForKey:@"username"] && [[userInfo objectForKey:@"username"] isKindOfClass:NSString.class]) {
                photo.authorProfileName = [userInfo objectForKey:@"username"];
            }
            if ([userInfo objectForKey:@"name"] && [[userInfo objectForKey:@"name"] isKindOfClass:NSString.class]) {
                photo.author = [userInfo objectForKey:@"name"];
            }
        }
        if ([photoJSON objectForKey:@"links"] && [[photoJSON objectForKey:@"links"] isKindOfClass:NSDictionary.class]) {
            NSDictionary *linksInfo = [photoJSON objectForKey:@"links"];
            if ([linksInfo objectForKey:@"download"] && [[linksInfo objectForKey:@"download"] isKindOfClass:NSString.class]) {
                photo.fullImageURL = [linksInfo objectForKey:@"download"];
            }
        }
        if ([photoJSON objectForKey:@"width"] && [[photoJSON objectForKey:@"width"] isKindOfClass:NSNumber.class]) {
            photo.width = [photoJSON objectForKey:@"width"];
        }
        if ([photoJSON objectForKey:@"height"] && [[photoJSON objectForKey:@"height"] isKindOfClass:NSNumber.class]) {
            photo.height = [photoJSON objectForKey:@"height"];
        }
        photo.source = @"Unsplash";
    }];
    
    if (photo) {
        LPUnsplashWallpaper *wallpaper = (LPUnsplashWallpaper *)[[NSManagedObjectContext MR_defaultContext] existingObjectWithID:photo.objectID error:nil];
        return wallpaper;
    } else {
        return nil;
    }
}

- (LPUnsplashWallpaper *)findRandomImageCurrentImageID:(NSString *)currentImageID {
    
    NSUInteger maxAttempts = 20;
    NSSize maxScreenSize = [self getMaximumScreenResolutionInPoints];
    
    if (self.collection == LPUnsplashImageManagerCollectionFeatured) {
        NSUInteger batchesPerPage = self.itemsPerPageInFeatured;
        NSUInteger totalBatchesPages = self.numberOfPagesInFeatured;
        
        if (batchesPerPage == 0 || totalBatchesPages == 0) {
            NSURLRequest *firstPageRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"curated_batches"] parameters:nil error:nil];
            NSHTTPURLResponse *response;
            NSError *error;
            [NSURLConnection sendSynchronousRequest:firstPageRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            
            if (!xTotal || !xPerPage) {
                return nil;
            }
            
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            
            NSUInteger totalBatches = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            batchesPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalBatches == 0 || batchesPerPage == 0) {
                return nil;
            }
            totalBatchesPages = totalBatches/batchesPerPage + (totalBatches%batchesPerPage != 0 ? 1 : 0);
            
            self.itemsPerPageInFeatured = batchesPerPage;
            self.numberOfPagesInFeatured = totalBatchesPages;
        }
        
        NSError *error;
        NSHTTPURLResponse *response;
        __block NSUInteger attempts = 0;
        while (true) {
            NSUInteger page = arc4random()%(totalBatchesPages)+1;
            
            NSURLRequest *batchesRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"curated_batches"] parameters:@{@"page": @(page)} error:nil];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:batchesRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            NSUInteger totalBatches = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            batchesPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalBatches == 0 || batchesPerPage == 0) {
                return nil;
            }
            totalBatchesPages = totalBatches/batchesPerPage + (totalBatches%batchesPerPage != 0 ? 1 : 0);
            self.itemsPerPageInFeatured = batchesPerPage;
            self.numberOfPagesInFeatured = totalBatchesPages;
            
            NSArray *batchesJSON = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                return nil;
            }
            
            if (batchesJSON.count == 0) {
                attempts++;
                if (attempts >= maxAttempts) {
                    return nil;
                }
                continue;
            }
            
            NSUInteger onPage = arc4random()%MIN(batchesPerPage, batchesJSON.count);
            
            NSDictionary *batchInfo = [batchesJSON objectAtIndex:onPage];
            NSNumber *batchID = [batchInfo objectForKey:@"id"];
            if (!batchID) {
                return nil;
            }
            
            NSURLRequest *batchRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@/%@/photos", kUnsplashAPIBaseURL, @"curated_batches", [batchID stringValue]] parameters:nil error:nil];
            responseData = [NSURLConnection sendSynchronousRequest:batchRequest returningResponse:nil error:&error];
            if (error) {
                return nil;
            }
            NSMutableArray *photosJSON = [[NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error] mutableCopy];
            if (error) {
                return nil;
            }
            
            [photosJSON shuffle];
            for (NSDictionary *photoJSON in photosJSON) {
                NSString *ID = [photoJSON objectForKey:@"id"];
                if (!ID || [ID isEqualToString:currentImageID]) {
                    continue;
                }
                
                LPUnsplashWallpaper *photo = [self parseWallpaper:photoJSON batchesPage:page allImagesPage:-1];
                if (photo.width.doubleValue >= maxScreenSize.width &&
                    photo.height.doubleValue >= maxScreenSize.height &&
                    [self suitableForPreferredOrientationWithSize:CGSizeMake(photo.width.doubleValue, photo.height.doubleValue)]) {
                    return photo;
                } else {
                    attempts++;
                    if (attempts >= maxAttempts) {
                        return nil;
                    }
                    continue;
                }
            }
        }
    } else {
        NSUInteger photosPerPage = self.itemsPerPageInAll;
        NSUInteger totalPhotosPages = self.numberOfPagesInAll;
        
        if (photosPerPage == 0 || totalPhotosPages == 0) {
            NSURLRequest *firstPageRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"photos"] parameters:@{@"per_page": @30} error:nil];
            NSHTTPURLResponse *response;
            NSError *error;
            [NSURLConnection sendSynchronousRequest:firstPageRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            
            if (!xTotal || !xPerPage) {
                return nil;
            }
            
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            NSUInteger totalPhotos = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            photosPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalPhotos == 0 || photosPerPage == 0) {
                return nil;
            }
            totalPhotosPages = totalPhotos/photosPerPage + (totalPhotos%photosPerPage != 0 ? 1 : 0);
            self.itemsPerPageInAll = photosPerPage;
            self.numberOfPagesInAll = totalPhotosPages;
        }
        
        NSError *error;
        NSHTTPURLResponse *response;
        __block NSUInteger attempts = 0;
        while (true) {
            NSUInteger page = arc4random()%(totalPhotosPages)+1;
            
            NSURLRequest *photosRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"photos"] parameters:@{@"page": @(page), @"per_page": @30} error:nil];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:photosRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            NSUInteger totalPhotos = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            photosPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalPhotos == 0 || photosPerPage == 0) {
                return nil;
            }
            totalPhotosPages = totalPhotos/photosPerPage + (totalPhotos%photosPerPage != 0 ? 1 : 0);
            self.itemsPerPageInAll = photosPerPage;
            self.numberOfPagesInAll = totalPhotosPages;
            
            NSMutableArray *photosJSON = [[NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error] mutableCopy];
            if (error) {
                return nil;
            }
            
            [photosJSON shuffle];
            for (NSDictionary *photoJSON in photosJSON) {
                NSString *ID = [photoJSON objectForKey:@"id"];
                if (!ID || [ID isEqualToString:currentImageID]) {
                    continue;
                }
                
                LPUnsplashWallpaper *photo = [self parseWallpaper:photoJSON batchesPage:-1 allImagesPage:page];
                if (photo.width.doubleValue >= maxScreenSize.width &&
                    photo.height.doubleValue >= maxScreenSize.height &&
                    [self suitableForPreferredOrientationWithSize:CGSizeMake(photo.width.doubleValue, photo.height.doubleValue)]) {
                    return photo;
                } else {
                    attempts++;
                    if (attempts >= maxAttempts) {
                        return nil;
                    }
                    continue;
                }
            }
        }
    }
    return nil;
}

- (LPUnsplashWallpaper *)findNextImageCurrentImageID:(NSString *)currentImageID {
    NSSize maxScreenSize = [self getMaximumScreenResolutionInPoints];
    
    if (self.collection == LPUnsplashImageManagerCollectionFeatured) {
        NSUInteger batchesPerPage = self.itemsPerPageInFeatured;
        NSUInteger totalBatchesPages = self.numberOfPagesInFeatured;
        
        if (batchesPerPage == 0 || totalBatchesPages == 0) {
            NSURLRequest *firstPageRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"curated_batches"] parameters:nil error:nil];
            NSHTTPURLResponse *response;
            NSError *error;
            [NSURLConnection sendSynchronousRequest:firstPageRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            
            if (!xTotal || !xPerPage) {
                return nil;
            }
            
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            
            NSUInteger totalBatches = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            batchesPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalBatches == 0 || batchesPerPage == 0) {
                return nil;
            }
            totalBatchesPages = totalBatches/batchesPerPage + (totalBatches%batchesPerPage != 0 ? 1 : 0);
            
            self.itemsPerPageInFeatured = batchesPerPage;
            self.numberOfPagesInFeatured = totalBatchesPages;
        }
        
        NSUInteger firstPage = 1;
        LPUnsplashWallpaper *currentWallpaper = [LPUnsplashWallpaper MR_findFirstByAttribute:@"id" withValue:currentImageID];
        if (currentWallpaper && currentWallpaper.pageInCuratedBatches) {
            firstPage = [currentWallpaper.pageInCuratedBatches unsignedIntegerValue];
        }
        
        NSError *error;
        NSHTTPURLResponse *response;
        BOOL found = (currentImageID == nil);
        for (NSUInteger page = firstPage; page <= totalBatchesPages; page++) {
            NSURLRequest *batchesRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"curated_batches"] parameters:@{@"page": @(page)} error:nil];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:batchesRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            NSUInteger totalBatches = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            batchesPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalBatches == 0 || batchesPerPage == 0) {
                return nil;
            }
            totalBatchesPages = totalBatches/batchesPerPage + (totalBatches%batchesPerPage != 0 ? 1 : 0);
            self.itemsPerPageInFeatured = batchesPerPage;
            self.numberOfPagesInFeatured = totalBatchesPages;
            
            NSArray *batchesJSON = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                return nil;
            }
            
            for (NSDictionary *batchInfo in batchesJSON) {
                NSNumber *batchID = [batchInfo objectForKey:@"id"];
                if (!batchID) {
                    continue;
                }
                
                NSURLRequest *batchRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@/%@/photos", kUnsplashAPIBaseURL, @"curated_batches", [batchID stringValue]] parameters:nil error:nil];
                responseData = [NSURLConnection sendSynchronousRequest:batchRequest returningResponse:nil error:&error];
                if (error) {
                    return nil;
                }
                NSArray *photosJSON = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
                if (error) {
                    return nil;
                }
                
                for (NSDictionary *photoJSON in photosJSON) {
                    NSString *ID = [photoJSON objectForKey:@"id"];
                    
                    if (ID && [ID isEqualToString:currentImageID]) {
                        found = YES;
                        continue;
                    }
                    
                    if (!ID || !found) {
                        continue;
                    }
                    
                    LPUnsplashWallpaper *photo = [self parseWallpaper:photoJSON batchesPage:page allImagesPage:-1];
                    if (photo.width.doubleValue >= maxScreenSize.width &&
                        photo.height.doubleValue >= maxScreenSize.height &&
                        [self suitableForPreferredOrientationWithSize:CGSizeMake(photo.width.doubleValue, photo.height.doubleValue)]) {
                        return photo;
                    } else {
                        continue;
                    }
                }
            }
        }
    } else {
        NSUInteger photosPerPage = self.itemsPerPageInAll;
        NSUInteger totalPhotosPages = self.numberOfPagesInAll;
        
        if (photosPerPage == 0 || totalPhotosPages == 0) {
            NSURLRequest *firstPageRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"photos"] parameters:@{@"per_page": @30} error:nil];
            NSHTTPURLResponse *response;
            NSError *error;
            [NSURLConnection sendSynchronousRequest:firstPageRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            
            if (!xTotal || !xPerPage) {
                return nil;
            }
            
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            
            NSUInteger totalPhotos = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            photosPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalPhotos == 0 || photosPerPage == 0) {
                return nil;
            }
            totalPhotosPages = totalPhotos/photosPerPage + (totalPhotos%photosPerPage != 0 ? 1 : 0);
            self.itemsPerPageInAll = photosPerPage;
            self.numberOfPagesInAll = totalPhotosPages;
        }
        
        NSError *error;
        NSHTTPURLResponse *response;
        
        NSUInteger firstPage = 1;
        LPUnsplashWallpaper *currentWallpaper = [LPUnsplashWallpaper MR_findFirstByAttribute:@"id" withValue:currentImageID];
        if (currentWallpaper && currentWallpaper.pageInAllImages) {
            firstPage = [currentWallpaper.pageInAllImages unsignedIntegerValue];
        }
        
        BOOL found = (currentImageID == nil);
        for (NSUInteger page = firstPage; page <= totalPhotosPages; page++) {
            NSURLRequest *photosRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"photos"] parameters:@{@"page": @(page), @"per_page": @30} error:nil];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:photosRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            NSUInteger totalPhotos = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            photosPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalPhotos == 0 || photosPerPage == 0) {
                return nil;
            }
            totalPhotosPages = totalPhotos/photosPerPage + (totalPhotos%photosPerPage != 0 ? 1 : 0);
            self.itemsPerPageInAll = photosPerPage;
            self.numberOfPagesInAll = totalPhotosPages;
            
            NSArray *photosJSON = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                return nil;
            }
            
            for (NSDictionary *photoJSON in photosJSON) {
                NSString *ID = [photoJSON objectForKey:@"id"];
                
                if (ID && [ID isEqualToString:currentImageID]) {
                    found = YES;
                    continue;
                }
                
                if (!ID || !found) {
                    continue;
                }
                
                LPUnsplashWallpaper *photo = [self parseWallpaper:photoJSON batchesPage:-1 allImagesPage:page];
                if (photo.width.doubleValue >= maxScreenSize.width &&
                    photo.height.doubleValue >= maxScreenSize.height &&
                    [self suitableForPreferredOrientationWithSize:CGSizeMake(photo.width.doubleValue, photo.height.doubleValue)]) {
                    return photo;
                } else {
                    continue;
                }
            }
        }
    }
    return nil;
}

- (NSSize)getMaximumScreenResolutionInPoints {
    CGFloat width = 0.0f;
    CGFloat height = 0.0f;
    
    for (NSScreen *screen in [NSScreen screens]) {
        if (screen.visibleFrame.size.width > width) {
            width = screen.visibleFrame.size.width;
        }
        if (screen.visibleFrame.size.height > height) {
            height = screen.visibleFrame.size.height;
        }
    }
    return NSMakeSize(width, height);
}

- (BOOL)suitableForPreferredOrientationWithSize:(CGSize)size {
    switch (self.preferredOrientation) {
        case LPUnsplashImageLandscape:
            return (size.width >= size.height);
        case LPUnsplashImagePortrait:
            return (size.height >= size.width);
        default:
            return YES;
    }
}

- (LPUnsplashWallpaper *)findRecentImage {
    NSSize maxScreenSize = [self getMaximumScreenResolutionInPoints];
    
    if (self.collection == LPUnsplashImageManagerCollectionFeatured) {
        NSUInteger batchesPerPage = self.itemsPerPageInFeatured;
        NSUInteger totalBatchesPages = self.numberOfPagesInFeatured;
        
        if (batchesPerPage == 0 || totalBatchesPages == 0) {
            NSURLRequest *firstPageRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"curated_batches"] parameters:nil error:nil];
            NSHTTPURLResponse *response;
            NSError *error;
            [NSURLConnection sendSynchronousRequest:firstPageRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            
            if (!xTotal || !xPerPage) {
                return nil;
            }
            
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            
            NSUInteger totalBatches = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            batchesPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalBatches == 0 || batchesPerPage == 0) {
                return nil;
            }
            totalBatchesPages = totalBatches/batchesPerPage + (totalBatches%batchesPerPage != 0 ? 1 : 0);
            
            self.itemsPerPageInFeatured = batchesPerPage;
            self.numberOfPagesInFeatured = totalBatchesPages;
        }
        
        NSError *error;
        NSHTTPURLResponse *response;
        for (NSUInteger page = 1; page <= totalBatchesPages; page++) {
            NSURLRequest *batchesRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"curated_batches"] parameters:@{@"page": @(page)} error:nil];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:batchesRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            NSUInteger totalBatches = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            batchesPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalBatches == 0 || batchesPerPage == 0) {
                return nil;
            }
            totalBatchesPages = totalBatches/batchesPerPage + (totalBatches%batchesPerPage != 0 ? 1 : 0);
            self.itemsPerPageInFeatured = batchesPerPage;
            self.numberOfPagesInFeatured = totalBatchesPages;
            
            NSArray *batchesJSON = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                return nil;
            }
            
            for (NSDictionary *batchInfo in batchesJSON) {
                NSNumber *batchID = [batchInfo objectForKey:@"id"];
                if (!batchID) {
                    continue;
                }
                
                NSURLRequest *batchRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@/%@/photos", kUnsplashAPIBaseURL, @"curated_batches", [batchID stringValue]] parameters:nil error:nil];
                responseData = [NSURLConnection sendSynchronousRequest:batchRequest returningResponse:nil error:&error];
                if (error) {
                    return nil;
                }
                NSArray *photosJSON = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
                if (error) {
                    return nil;
                }
                
                for (NSDictionary *photoJSON in photosJSON) {
                    NSString *ID = [photoJSON objectForKey:@"id"];
                    if (!ID) {
                        continue;
                    }
                    
                    LPUnsplashWallpaper *photo = [self parseWallpaper:photoJSON batchesPage:page allImagesPage:-1];
                    if (photo.width.doubleValue >= maxScreenSize.width &&
                        photo.height.doubleValue >= maxScreenSize.height &&
                        [self suitableForPreferredOrientationWithSize:CGSizeMake(photo.width.doubleValue, photo.height.doubleValue)]) {
                        return photo;
                    } else {
                        continue;
                    }
                }
            }
        }
    } else {
        NSUInteger photosPerPage = self.itemsPerPageInAll;
        NSUInteger totalPhotosPages = self.numberOfPagesInAll;
        
        if (photosPerPage == 0 || totalPhotosPages == 0) {
            NSURLRequest *firstPageRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"photos"] parameters:@{@"per_page": @30} error:nil];
            NSHTTPURLResponse *response;
            NSError *error;
            [NSURLConnection sendSynchronousRequest:firstPageRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            
            if (!xTotal || !xPerPage) {
                return nil;
            }
            
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            
            NSUInteger totalPhotos = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            photosPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalPhotos == 0 || photosPerPage == 0) {
                return nil;
            }
            totalPhotosPages = totalPhotos/photosPerPage + (totalPhotos%photosPerPage != 0 ? 1 : 0);
            self.itemsPerPageInAll = photosPerPage;
            self.numberOfPagesInAll = totalPhotosPages;
        }
        
        NSError *error;
        NSHTTPURLResponse *response;
        for (NSUInteger page = 1; page <= totalPhotosPages; page++) {
            NSURLRequest *photosRequest = [serializer requestWithMethod:@"GET" URLString:[NSString stringWithFormat:@"%@/%@", kUnsplashAPIBaseURL, @"photos"] parameters:@{@"page": @(page), @"per_page": @30} error:nil];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:photosRequest returningResponse:&response error:&error];
            if (error) {
                return nil;
            }
            
            NSString *xTotal = [response.allHeaderFields objectForKey:@"X-Total"];
            NSString *xPerPage = [response.allHeaderFields objectForKey:@"X-Per-Page"];
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            NSUInteger totalPhotos = [[formatter numberFromString:xTotal] unsignedIntegerValue];
            photosPerPage = [[formatter numberFromString:xPerPage] unsignedIntegerValue];
            if (totalPhotos == 0 || photosPerPage == 0) {
                return nil;
            }
            totalPhotosPages = totalPhotos/photosPerPage + (totalPhotos%photosPerPage != 0 ? 1 : 0);
            self.itemsPerPageInAll = photosPerPage;
            self.numberOfPagesInAll = totalPhotosPages;
            
            NSArray *photosJSON = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                return nil;
            }
            
            for (NSDictionary *photoJSON in photosJSON) {
                NSString *ID = [photoJSON objectForKey:@"id"];
                if (!ID) {
                    continue;
                }
                
                LPUnsplashWallpaper *photo = [self parseWallpaper:photoJSON batchesPage:-1 allImagesPage:page];
                if (photo.width.doubleValue >= maxScreenSize.width &&
                    photo.height.doubleValue >= maxScreenSize.height &&
                    [self suitableForPreferredOrientationWithSize:CGSizeMake(photo.width.doubleValue, photo.height.doubleValue)]) {
                    return photo;
                } else {
                    continue;
                }
            }
        }
    }
    return nil;
}

#pragma mark Public Wrappers

- (void)loadNextImageCurrentImageName:(NSString *)currentImageName
                              success:(void (^)(NSString *, NSString *))success
                              failure:(void (^)(NSError *))failure {
    [self loadImageCurrentImageName:currentImageName mode:LPUnsplashLoadImageModeSuccessive success:success failure:failure];
}

- (void)loadRandomImageCurrentImageName:(NSString *)currentImageName
                                success:(void (^)(NSString *, NSString *))success
                                failure:(void (^)(NSError *))failure {
    [self loadImageCurrentImageName:currentImageName mode:LPUnsplashLoadImageModeRandom success:success failure:failure];
}

- (void)loadRecentImage:(void (^)(NSString *, NSString *))success failure:(void (^)(NSError *))failure {
    [self loadImageCurrentImageName:nil mode:LPUnsplashLoadImageModeRecent success:success failure:failure];
}

@end
