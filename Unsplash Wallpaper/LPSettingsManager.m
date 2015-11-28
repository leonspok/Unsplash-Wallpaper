//
//  LPSettingsManager.m
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 24/07/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "LPSettingsManager.h"
#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>

@import AppKit;

static NSString *const kNextWallpaperShortcutEnabled = @"NextWallpaperShortcutEnabled";
static NSString *const kChangeAllWallpapersShortcutEnabled = @"ChangeAllWallpapersShortcutEnabled";
static NSString *const kAddWallpaperToBlacklistShortcutEnabled = @"AddWallpaperToBlacklistShortcutEnabled";
static NSString *const kRecentWallpaperShortcutEnabled = @"RecentWallpaperShortcutEnabled";
static NSString *const kSaveCurrentWallpaperShortcutEnabled = @"SaveCurrentWallpaperShortcutEnabled";

static NSString *const kNextWallpaperShortcutKeyCode = @"NextWallpaperShortcutKeyCode";
static NSString *const kNextWallpaperShortcutModifierFlags = @"NextWallpaperShortcutModifierFlags";
static NSString *const kChangeAllWallpapersShortcutKeyCode = @"ChangeAllWallpapersShortcutKeyCode";
static NSString *const kChangeAllWallpapersShortcutModifierFlags = @"ChangeAllWallpapersShortcutModifierFlags";
static NSString *const kAddWallpaperToBlacklistShortcutKeyCode = @"AddWallpaperToBlacklistShortcutKeyCode";
static NSString *const kAddWallpaperToBlacklistShortcutModifierFlags = @"AddWallpaperToBlacklistShortcutModifierFlags";
static NSString *const kRecentWallpaperShortcutKeyCode = @"RecentWallpaperShortcutKeyCode";
static NSString *const kRecentWallpaperShortcutModifierFlags = @"RecentWallpaperShortcutModifierFlags";
static NSString *const kSaveCurrentWallpaperShortcutKeyCode = @"SaveCurrentWallpaperShortcutKeyCode";
static NSString *const kSaveCurrentWallpaperShortcutModifierFlags = @"SaveCurrentWallpaperShortcutModifierFlags";

static NSString *const kNotificationsEnabled = @"kNotificationsEnabled";
static NSString *const kOpenSavedImageEnabled = @"OpenSavedImageEnabled";

@implementation LPSettingsManager {
    NSUserDefaults *userDefaults;
}

+ (instancetype)sharedManager {
    static LPSettingsManager *__sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedManager = [[LPSettingsManager alloc] init];
    });
    return __sharedManager;
}

- (id)init {
    self = [super init];
    if (self) {
        userDefaults = [NSUserDefaults standardUserDefaults];
    }
    return self;
}

#pragma mark Getters and Setters

- (BOOL)isNextWallpaperShortcutEnabled {
    NSNumber *value = [userDefaults objectForKey:kNextWallpaperShortcutEnabled];
    if (!value) {
        [self setNextWallpaperShortcutEnabled:YES];
        return YES;
    } else {
        return [value boolValue];
    }
}

- (void)setNextWallpaperShortcutEnabled:(BOOL)nextWallpaperShortcutEnabled {
    [userDefaults setBool:nextWallpaperShortcutEnabled forKey:kNextWallpaperShortcutEnabled];
    [userDefaults synchronize];
}

- (BOOL)isChangeAllWallpapersShortcutEnabled {
    NSNumber *value = [userDefaults objectForKey:kChangeAllWallpapersShortcutEnabled];
    if (!value) {
        [self setChangeAllWallpapersShortcutEnabled:YES];
        return YES;
    } else {
        return [value boolValue];
    }
}

- (void)setChangeAllWallpapersShortcutEnabled:(BOOL)changeAllWallpapersShortcutEnabled {
    [userDefaults setBool:changeAllWallpapersShortcutEnabled forKey:kChangeAllWallpapersShortcutEnabled];
    [userDefaults synchronize];
}

- (BOOL)isAddWallpaperToBlacklistShortcutEnabled {
    NSNumber *value = [userDefaults objectForKey:kAddWallpaperToBlacklistShortcutEnabled];
    if (!value) {
        [self setAddWallpaperToBlacklistShortcutEnabled:YES];
        return YES;
    } else {
        return [value boolValue];
    }
}

- (void)setAddWallpaperToBlacklistShortcutEnabled:(BOOL)addWallpaperToBlacklistShortcutEnabled {
    [userDefaults setBool:addWallpaperToBlacklistShortcutEnabled forKey:kAddWallpaperToBlacklistShortcutEnabled];
    [userDefaults synchronize];
}

- (BOOL)isRecentWallpaperShortcutEnabled {
    NSNumber *value = [userDefaults objectForKey:kRecentWallpaperShortcutEnabled];
    if (!value) {
        [self setRecentWallpaperShortcutEnabled:YES];
        return YES;
    } else {
        return [value boolValue];
    }
}

- (void)setRecentWallpaperShortcutEnabled:(BOOL)recentWallpaperShortcutEnabled {
    [userDefaults setBool:recentWallpaperShortcutEnabled forKey:kRecentWallpaperShortcutEnabled];
    [userDefaults synchronize];
}

- (BOOL)isSaveCurrentWallpaperShortcutEnabled {
    NSNumber *value = [userDefaults objectForKey:kSaveCurrentWallpaperShortcutEnabled];
    if (!value) {
        [self setSaveCurrentWallpaperShortcutEnabled:YES];
        return YES;
    } else {
        return [value boolValue];
    }
}

- (void)setSaveCurrentWallpaperShortcutEnabled:(BOOL)saveCurrentWallpaperShortcutEnabled {
    [userDefaults setBool:saveCurrentWallpaperShortcutEnabled forKey:kSaveCurrentWallpaperShortcutEnabled];
    [userDefaults synchronize];
}

- (MASShortcut *)nextWallpaperShortcut {
    NSNumber *keyCode = [userDefaults objectForKey:kNextWallpaperShortcutKeyCode];
    NSNumber *modifierFlags = [userDefaults objectForKey:kNextWallpaperShortcutModifierFlags];
    
    if ([keyCode integerValue] == -1 || [modifierFlags integerValue] == -1) {
        return nil;
    } else if (!keyCode || !modifierFlags) {
        MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_N modifierFlags:NSCommandKeyMask|NSAlternateKeyMask];
        [self setNextWallpaperShortcut:shortcut];
        return shortcut;
    } else {
        return [MASShortcut shortcutWithKeyCode:[keyCode unsignedIntegerValue] modifierFlags:[modifierFlags unsignedIntegerValue]];
    }
}

- (void)setNextWallpaperShortcut:(MASShortcut *)nextWallpaperShortcut {
    if (!nextWallpaperShortcut) {
        [userDefaults setObject:@(-1) forKey:kNextWallpaperShortcutKeyCode];
        [userDefaults setObject:@(-1) forKey:kNextWallpaperShortcutModifierFlags];
    } else {
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:nextWallpaperShortcut.keyCode] forKey:kNextWallpaperShortcutKeyCode];
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:nextWallpaperShortcut.modifierFlags] forKey:kNextWallpaperShortcutModifierFlags];
    }
    [userDefaults synchronize];
}

- (MASShortcut *)changeAllWallpapersShortcut {
    NSNumber *keyCode = [userDefaults objectForKey:kChangeAllWallpapersShortcutKeyCode];
    NSNumber *modifierFlags = [userDefaults objectForKey:kChangeAllWallpapersShortcutModifierFlags];
    
    if ([keyCode integerValue] == -1 || [modifierFlags integerValue] == -1) {
        return nil;
    } else if (!keyCode || !modifierFlags) {
        MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_M modifierFlags:NSCommandKeyMask|NSAlternateKeyMask];
        [self setChangeAllWallpapersShortcut:shortcut];
        return shortcut;
    } else {
        return [MASShortcut shortcutWithKeyCode:[keyCode unsignedIntegerValue] modifierFlags:[modifierFlags unsignedIntegerValue]];
    }
}

- (void)setChangeAllWallpapersShortcut:(MASShortcut *)changeAllWallpapersShortcut {
    if (!changeAllWallpapersShortcut) {
        [userDefaults setObject:@(-1) forKey:kChangeAllWallpapersShortcutKeyCode];
        [userDefaults setObject:@(-1) forKey:kChangeAllWallpapersShortcutModifierFlags];
    } else {
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:changeAllWallpapersShortcut.keyCode] forKey:kChangeAllWallpapersShortcutKeyCode];
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:changeAllWallpapersShortcut.modifierFlags] forKey:kChangeAllWallpapersShortcutModifierFlags];
    }
    [userDefaults synchronize];
}

- (MASShortcut *)addWallpaperToBlacklistShortcut {
    NSNumber *keyCode = [userDefaults objectForKey:kAddWallpaperToBlacklistShortcutKeyCode];
    NSNumber *modifierFlags = [userDefaults objectForKey:kAddWallpaperToBlacklistShortcutModifierFlags];
    
    if ([keyCode integerValue] == -1 || [modifierFlags integerValue] == -1) {
        return nil;
    } else if (!keyCode || !modifierFlags) {
        MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_B modifierFlags:NSCommandKeyMask|NSAlternateKeyMask];
        [self setAddWallpaperToBlacklistShortcut:shortcut];
        return shortcut;
    } else {
        return [MASShortcut shortcutWithKeyCode:[keyCode unsignedIntegerValue] modifierFlags:[modifierFlags unsignedIntegerValue]];
    }
}

- (void)setAddWallpaperToBlacklistShortcut:(MASShortcut *)addWallpaperToBlacklistShortcut {
    if (!addWallpaperToBlacklistShortcut) {
        [userDefaults setObject:@(-1) forKey:kAddWallpaperToBlacklistShortcutKeyCode];
        [userDefaults setObject:@(-1) forKey:kAddWallpaperToBlacklistShortcutModifierFlags];
    } else {
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:addWallpaperToBlacklistShortcut.keyCode] forKey:kAddWallpaperToBlacklistShortcutKeyCode];
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:addWallpaperToBlacklistShortcut.modifierFlags] forKey:kAddWallpaperToBlacklistShortcutModifierFlags];
    }
    [userDefaults synchronize];
}

- (MASShortcut *)recentWallpaperShortcut {
    NSNumber *keyCode = [userDefaults objectForKey:kRecentWallpaperShortcutKeyCode];
    NSNumber *modifierFlags = [userDefaults objectForKey:kRecentWallpaperShortcutModifierFlags];
    
    if ([keyCode integerValue] == -1 || [modifierFlags integerValue] == -1) {
        return nil;
    } else if (!keyCode || !modifierFlags) {
        MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_R modifierFlags:NSCommandKeyMask|NSAlternateKeyMask];
        [self setRecentWallpaperShortcut:shortcut];
        return shortcut;
    } else {
        return [MASShortcut shortcutWithKeyCode:[keyCode unsignedIntegerValue] modifierFlags:[modifierFlags unsignedIntegerValue]];
    }
}

- (void)setRecentWallpaperShortcut:(MASShortcut *)recentWallpaperShortcut {
    if (!recentWallpaperShortcut) {
        [userDefaults setObject:@(-1) forKey:kRecentWallpaperShortcutKeyCode];
        [userDefaults setObject:@(-1) forKey:kRecentWallpaperShortcutModifierFlags];
    } else {
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:recentWallpaperShortcut.keyCode] forKey:kRecentWallpaperShortcutKeyCode];
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:recentWallpaperShortcut.modifierFlags] forKey:kRecentWallpaperShortcutModifierFlags];
    }
    [userDefaults synchronize];
}

- (MASShortcut *)saveCurrentWallpaperShortcut {
    NSNumber *keyCode = [userDefaults objectForKey:kSaveCurrentWallpaperShortcutKeyCode];
    NSNumber *modifierFlags = [userDefaults objectForKey:kSaveCurrentWallpaperShortcutModifierFlags];
    
    if ([keyCode integerValue] == -1 || [modifierFlags integerValue] == -1) {
        return nil;
    } else if (!keyCode || !modifierFlags) {
        MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_S modifierFlags:NSCommandKeyMask|NSAlternateKeyMask];
        [self setSaveCurrentWallpaperShortcut:shortcut];
        return shortcut;
    } else {
        return [MASShortcut shortcutWithKeyCode:[keyCode unsignedIntegerValue] modifierFlags:[modifierFlags unsignedIntegerValue]];
    }
}

- (void)setSaveCurrentWallpaperShortcut:(MASShortcut *)saveCurrentWallpaperShortcut {
    if (!saveCurrentWallpaperShortcut) {
        [userDefaults setObject:@(-1) forKey:kSaveCurrentWallpaperShortcutKeyCode];
        [userDefaults setObject:@(-1) forKey:kSaveCurrentWallpaperShortcutModifierFlags];
    } else {
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:saveCurrentWallpaperShortcut.keyCode] forKey:kSaveCurrentWallpaperShortcutKeyCode];
        [userDefaults setObject:[NSNumber numberWithUnsignedInteger:saveCurrentWallpaperShortcut.modifierFlags] forKey:kSaveCurrentWallpaperShortcutModifierFlags];
    }
    [userDefaults synchronize];
}

- (BOOL)isNotificationsEnabled {
    NSNumber *value = [userDefaults objectForKey:kNotificationsEnabled];
    if (!value) {
        [self setNotificationsEnabled:YES];
        return YES;
    } else {
        return [value boolValue];
    }
}

- (void)setNotificationsEnabled:(BOOL)notificationsEnabled {
    [userDefaults setBool:notificationsEnabled forKey:kNotificationsEnabled];
    [userDefaults synchronize];
}

- (BOOL)isOpenSavedImageEnabled {
    NSNumber *value = [userDefaults objectForKey:kOpenSavedImageEnabled];
    if (!value) {
        [self setOpenSavedImageEnabled:YES];
        return YES;
    } else {
        return [value boolValue];
    }
}

- (void)setOpenSavedImageEnabled:(BOOL)openSavedImageEnabled {
    [userDefaults setBool:openSavedImageEnabled forKey:kOpenSavedImageEnabled];
    [userDefaults synchronize];
}

@end
