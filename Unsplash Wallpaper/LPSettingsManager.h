//
//  LPSettingsManager.h
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 24/07/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MASShortcut;

@interface LPSettingsManager : NSObject

@property (nonatomic, getter=isNextWallpaperShortcutEnabled) BOOL nextWallpaperShortcutEnabled;
@property (nonatomic, strong) MASShortcut *nextWallpaperShortcut;
@property (nonatomic, getter=isChangeAllWallpapersShortcutEnabled) BOOL changeAllWallpapersShortcutEnabled;
@property (nonatomic, strong) MASShortcut *changeAllWallpapersShortcut;
@property (nonatomic, getter=isAddWallpaperToBlacklistShortcutEnabled) BOOL addWallpaperToBlacklistShortcutEnabled;
@property (nonatomic, strong) MASShortcut *addWallpaperToBlacklistShortcut;
@property (nonatomic, getter=isRecentWallpaperShortcutEnabled) BOOL recentWallpaperShortcutEnabled;
@property (nonatomic, strong) MASShortcut *recentWallpaperShortcut;
@property (nonatomic, getter=isSaveCurrentWallpaperShortcutEnabled) BOOL saveCurrentWallpaperShortcutEnabled;
@property (nonatomic, strong) MASShortcut *saveCurrentWallpaperShortcut;

@property (nonatomic, getter=isNotificationsEnabled) BOOL notificationsEnabled;
@property (nonatomic, getter=isOpenSavedImageEnabled) BOOL openSavedImageEnabled;

+ (instancetype)sharedManager;

@end
