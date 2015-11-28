//
//  LPWallpaperManager.h
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 04/06/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *const kAnyWorkspace = @"ANY WORKSPACE";
static NSString *const kAnyDisplay = @"ANY DISPLAY";

typedef enum {
    LPImageUpdateDurationNever,
    LPImageUpdateDuration3Hours,
    LPImageUpdateDuration12Hours,
    LPImageUpdateDuration24Hours,
    LPImageUpdateDurationWeek,
    LPImageUpdateDuration2Weeks,
    LPImageUpdateDurationMonth
} LPImageUpdateDuration;

typedef enum {
    LPImageUpdateScopeAll,
    LPImageUpdateScopeDisplay,
    LPImageUpdateScopeWorkspace
} LPImageUpdateScope;

@interface LPWallpaperManager : NSObject

@property (nonatomic, readonly) NSDate *nextRefreshDate;
@property (nonatomic, readonly) NSDate *lastRefreshDate;
@property (nonatomic, assign) LPImageUpdateDuration duration;
@property (nonatomic, assign) LPImageUpdateScope scope;
@property (nonatomic, assign) BOOL changeAllImagesAtOnce;
@property (nonatomic, assign) BOOL randomize;
@property (nonatomic, assign) BOOL autoSwithOSXTheme;

+ (instancetype)sharedManager;

- (void)setWallpaper;
- (void)setSuitableThemeIfNeeded;
- (BOOL)isDarkModeEnabledInPreferencePanel;
- (void)resetTheme;

- (NSString *)activeSpaceIdentifier;
- (NSArray *)spaceIdentifiers;
- (NSString *)activeDisplayIdentifier;
- (NSArray *)displayIdentifiers;

- (NSString *)currentImageNameForDisplay:(NSString *)display;
- (NSImage *)currentImageForDisplay:(NSString *)display;

- (NSString *)currentImageNameForWorkspace:(NSString *)workspace;
- (NSImage *)currentImageForWorkspace:(NSString *)workspace;

- (void)setCurrentImage:(NSImage *)image
               withName:(NSString *)name
           forWorkspace:(NSString *)workspace;

- (void)setCurrentImageAtPath:(NSString *)imagePath
                     withName:(NSString *)name
                 forWorkspace:(NSString *)workspace;

- (void)setCurrentImage:(NSImage *)image
               withName:(NSString *)name
             forDisplay:(NSString *)display;

- (void)setCurrentImageAtPath:(NSString *)imagePath
                     withName:(NSString *)name
                   forDisplay:(NSString *)display;

@end