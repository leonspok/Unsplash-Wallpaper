//
//  LPSettingsWindowController.m
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 15/07/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "LPSettingsWindowController.h"
#import <MASShortcut/Shortcut.h>
#import "LPSettingsManager.h"
#import "LPWallpaperManager.h"
#import "LPUnsplashImageManager.h"
#import "EnumsToStrings.h"
#import "AppDelegate.h"

@interface LPSettingsWindowController ()
@property (weak) IBOutlet MASShortcutView *nextWallpaperShortcut;
@property (weak) IBOutlet NSButton *nextWallpaperShortcutEnabled;
@property (weak) IBOutlet MASShortcutView *changeAllWallpapersShortcut;
@property (weak) IBOutlet NSButton *changeAllWallpapersShortcutEnabled;
@property (weak) IBOutlet MASShortcutView *addToBlacklistShortcut;
@property (weak) IBOutlet NSButton *addToBlacklistShortcutEnabled;
@property (weak) IBOutlet MASShortcutView *recentWallpaperShortcut;
@property (weak) IBOutlet NSButton *recentWallpaperShortcutEnabled;
@property (weak) IBOutlet MASShortcutView *saveCurrentWallpaperShortcut;
@property (weak) IBOutlet NSButton *saveCurrentWallpaperShortcutEnabled;
@property (weak) IBOutlet NSPopUpButton *preferredOrientation;
@property (weak) IBOutlet NSPopUpButton *updateScope;
@property (weak) IBOutlet NSButton *notificationsEnabled;
@property (weak) IBOutlet NSButton *autoOSXThemeEnabled;
@property (weak) IBOutlet NSButton *openSavedImageEnabled;

@end

@implementation LPSettingsWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self.nextWallpaperShortcut setShortcutValue:[LPSettingsManager sharedManager].nextWallpaperShortcut];
    [self.changeAllWallpapersShortcut setShortcutValue:[LPSettingsManager sharedManager].changeAllWallpapersShortcut];
    [self.addToBlacklistShortcut setShortcutValue:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut];
    [self.recentWallpaperShortcut setShortcutValue:[LPSettingsManager sharedManager].recentWallpaperShortcut];
    [self.saveCurrentWallpaperShortcut setShortcutValue:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcut];

    [self.nextWallpaperShortcutEnabled setState:[LPSettingsManager sharedManager].nextWallpaperShortcutEnabled? NSOnState : NSOffState];
    [self.changeAllWallpapersShortcutEnabled setState:[LPSettingsManager sharedManager].changeAllWallpapersShortcutEnabled? NSOnState : NSOffState];
    [self.addToBlacklistShortcutEnabled setState:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcutEnabled? NSOnState : NSOffState];
    [self.recentWallpaperShortcutEnabled setState:[LPSettingsManager sharedManager].recentWallpaperShortcutEnabled? NSOnState : NSOffState];
    [self.saveCurrentWallpaperShortcutEnabled setState:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcutEnabled? NSOnState : NSOffState];

    [self.notificationsEnabled setState:[LPSettingsManager sharedManager].notificationsEnabled? NSOnState : NSOffState];
    [self.openSavedImageEnabled setState:[LPSettingsManager sharedManager].openSavedImageEnabled? NSOnState : NSOffState];
    
    [self.autoOSXThemeEnabled setState:([LPWallpaperManager sharedManager].autoSwithOSXTheme? NSOnState : NSOffState)];
    [self.autoOSXThemeEnabled setState:([LPWallpaperManager sharedManager].autoSwithOSXTheme? NSOnState : NSOffState) && self.autoOSXThemeEnabled.enabled];
    
    [self.preferredOrientation selectItemAtIndex:[LPUnsplashImageManager sharedManager].preferredOrientation];
    [self.updateScope selectItemAtIndex:[LPWallpaperManager sharedManager].scope];
    
    [self.nextWallpaperShortcut setShortcutValueChange:^(MASShortcutView *shortcutView) {
        [self nextWallpaperShortcutChanged];
    }];
    [self.changeAllWallpapersShortcut setShortcutValueChange:^(MASShortcutView *shortcutView) {
        [self changeAllWallpapersShortcutChanged];
    }];
    [self.addToBlacklistShortcut setShortcutValueChange:^(MASShortcutView *shortcutView) {
        [self addToBlacklistShortcutChanged];
    }];
    [self.recentWallpaperShortcut setShortcutValueChange:^(MASShortcutView *shortcutView) {
        [self recentWallpaperShortcutChanged];
    }];
    [self.saveCurrentWallpaperShortcut setShortcutValueChange:^(MASShortcutView *shortcutView) {
        [self saveCurrentWallpaperShortcutChanged];
    }];
}

- (void)show {
    [self.window makeKeyAndOrderFront:self];
}

#pragma mark Shortcut Actions

- (void)nextWallpaperShortcutChanged {
    [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].nextWallpaperShortcut];
    [[LPSettingsManager sharedManager] setNextWallpaperShortcut:self.nextWallpaperShortcut.shortcutValue];
    [self setNextWallpaperShortcutOn:[LPSettingsManager sharedManager].nextWallpaperShortcut != nil];
}

- (void)changeAllWallpapersShortcutChanged {
    [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].changeAllWallpapersShortcut];
    [[LPSettingsManager sharedManager] setChangeAllWallpapersShortcut:self.changeAllWallpapersShortcut.shortcutValue];
    [self setChangeAllWallpapersShortcutOn:[LPSettingsManager sharedManager].changeAllWallpapersShortcut != nil];
}

- (void)addToBlacklistShortcutChanged {
    [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut];
    [[LPSettingsManager sharedManager] setAddWallpaperToBlacklistShortcut:self.addToBlacklistShortcut.shortcutValue];
    [self setBlacklistShortcutOn:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut != nil];
}

- (void)recentWallpaperShortcutChanged {
    [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].recentWallpaperShortcut];
    [[LPSettingsManager sharedManager] setRecentWallpaperShortcut:self.recentWallpaperShortcut.shortcutValue];
    [self setRecentWallpaperShortcutOn:[LPSettingsManager sharedManager].recentWallpaperShortcut != nil];
}

- (void)saveCurrentWallpaperShortcutChanged {
    [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcut];
    [[LPSettingsManager sharedManager] setSaveCurrentWallpaperShortcut:self.saveCurrentWallpaperShortcut.shortcutValue];
    [self setSaveCurrentWallpaperShortcutOn:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcut != nil];
}

#pragma mark UIActions

- (IBAction)toggleNextWallpaperShortcut:(id)sender {
    [self setNextWallpaperShortcutOn:![LPSettingsManager sharedManager].nextWallpaperShortcutEnabled && ([LPSettingsManager sharedManager].nextWallpaperShortcut != nil)];
}

- (void)setNextWallpaperShortcutOn:(BOOL)on {
    [[LPSettingsManager sharedManager] setNextWallpaperShortcutEnabled:on];
    [self.nextWallpaperShortcutEnabled setState:[LPSettingsManager sharedManager].nextWallpaperShortcutEnabled? NSOnState : NSOffState];
    
    if ([[LPSettingsManager sharedManager] isNextWallpaperShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].nextWallpaperShortcut withAction:^{
            AppDelegate *delegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
            [delegate loadNextImage:nil];
        }];
    } else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].nextWallpaperShortcut];
    }
}

- (IBAction)toggleChangeAllWallpapersShortcut:(id)sender {
    [self setChangeAllWallpapersShortcutOn:![LPSettingsManager sharedManager].changeAllWallpapersShortcutEnabled && ([LPSettingsManager sharedManager].changeAllWallpapersShortcut != nil)];
}

- (void)setChangeAllWallpapersShortcutOn:(BOOL)on {
    [[LPSettingsManager sharedManager] setChangeAllWallpapersShortcutEnabled:on];
    [self.changeAllWallpapersShortcutEnabled setState:[LPSettingsManager sharedManager].changeAllWallpapersShortcutEnabled? NSOnState : NSOffState];
    
    if ([[LPSettingsManager sharedManager] isChangeAllWallpapersShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].changeAllWallpapersShortcut withAction:^{
            AppDelegate *delegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
            [delegate changeAllWallpapers:nil];
        }];
    } else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].changeAllWallpapersShortcut];
    }
}

- (IBAction)toggleBlacklistShortcut:(id)sender {
    [self setBlacklistShortcutOn:![LPSettingsManager sharedManager].addWallpaperToBlacklistShortcutEnabled && ([LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut != nil)];
}

- (void)setBlacklistShortcutOn:(BOOL)on {
    [[LPSettingsManager sharedManager] setAddWallpaperToBlacklistShortcutEnabled:on];
    [self.addToBlacklistShortcutEnabled setState:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcutEnabled? NSOnState : NSOffState];
    
    if ([[LPSettingsManager sharedManager] isAddWallpaperToBlacklistShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut withAction:^{
            AppDelegate *delegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
            [delegate addCurrentImageToBlackList:nil];
        }];
    } else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut];
    }
}

- (IBAction)toggleRecentWallpaperShortcut:(id)sender {
    [self setRecentWallpaperShortcutOn:![LPSettingsManager sharedManager].recentWallpaperShortcutEnabled && ([LPSettingsManager sharedManager].recentWallpaperShortcut != nil)];
}

- (void)setRecentWallpaperShortcutOn:(BOOL)on {
    [[LPSettingsManager sharedManager] setRecentWallpaperShortcutEnabled:on];
    [self.recentWallpaperShortcutEnabled setState:[LPSettingsManager sharedManager].recentWallpaperShortcutEnabled? NSOnState : NSOffState];
    
    if ([[LPSettingsManager sharedManager] isRecentWallpaperShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].recentWallpaperShortcut withAction:^{
            AppDelegate *delegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
            [delegate showRecentImage:nil];
        }];
    } else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].recentWallpaperShortcut];
    }
}

- (IBAction)toggleSaveCurrentWallpaperShortcut:(id)sender {
    [self setSaveCurrentWallpaperShortcutOn:![LPSettingsManager sharedManager].saveCurrentWallpaperShortcutEnabled && ([LPSettingsManager sharedManager].saveCurrentWallpaperShortcut != nil)];
}

- (void)setSaveCurrentWallpaperShortcutOn:(BOOL)on {
    [[LPSettingsManager sharedManager] setSaveCurrentWallpaperShortcutEnabled:on];
    [self.saveCurrentWallpaperShortcutEnabled setState:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcutEnabled? NSOnState : NSOffState];
    
    if ([[LPSettingsManager sharedManager] isSaveCurrentWallpaperShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcut withAction:^{
            AppDelegate *delegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
            [delegate saveCurrentImage:nil];
        }];
    } else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcut];
    }
}

- (IBAction)changePreferredOrientation:(id)sender {
    [[LPUnsplashImageManager sharedManager] setPreferredOrientation:(LPUnsplashImageOrientation)self.preferredOrientation.indexOfSelectedItem];
}

- (IBAction)changeUpdateScope:(id)sender {
    [[LPWallpaperManager sharedManager] setScope:(LPImageUpdateScope)self.updateScope.indexOfSelectedItem];
    
    [self.autoOSXThemeEnabled setEnabled:([LPWallpaperManager sharedManager].scope == LPImageUpdateScopeAll && NSAppKitVersionNumber >= NSAppKitVersionNumber10_10)];
    [self.autoOSXThemeEnabled setState:([LPWallpaperManager sharedManager].autoSwithOSXTheme? NSOnState : NSOffState) && self.autoOSXThemeEnabled.enabled];
}

- (IBAction)toggleNotifications:(id)sender {
    [[LPSettingsManager sharedManager] setNotificationsEnabled:![LPSettingsManager sharedManager].notificationsEnabled];
    [self.notificationsEnabled setState:[LPSettingsManager sharedManager].notificationsEnabled? NSOnState : NSOffState];
}

- (IBAction)toggleAutoOSXTheme:(id)sender {
    [[LPWallpaperManager sharedManager] setAutoSwithOSXTheme:![LPWallpaperManager sharedManager].autoSwithOSXTheme];
    [self.autoOSXThemeEnabled setState:[LPWallpaperManager sharedManager].autoSwithOSXTheme? NSOnState : NSOffState];
}

- (IBAction)toggleOpenSavedImage:(id)sender {
    [[LPSettingsManager sharedManager] setOpenSavedImageEnabled:![LPSettingsManager sharedManager].openSavedImageEnabled];
    [self.openSavedImageEnabled setState:[LPSettingsManager sharedManager].openSavedImageEnabled? NSOnState : NSOffState];
}

- (IBAction)showLaunchAtStartupInfo:(id)sender {
    
}

@end
