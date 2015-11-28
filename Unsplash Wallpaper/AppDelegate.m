//
//  AppDelegate.m
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 31/01/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "AppDelegate.h"
#import "LPUnsplashImageManager.h"
#import "CoreData+MagicalRecord.h"
#import "MagicalRecord.h"
#import <MASShortcut/Shortcut.h>
#import "LPNSStatusItemIconAnimator.h"
#import "TTOfflineChecker.h"
#import "LPWallpaperManager.h"
#import "EnumsToStrings.h"
#import "LPSettingsManager.h"
#import "LPSettingsWindowController.h"
#import "LPAboutWindowController.h"

static NSString *const kNotificationsEnabled = @"kNotificationsEnabled";

@interface AppDelegate () <NSMenuDelegate>

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (weak) IBOutlet NSMenu *menu;
@property (weak) IBOutlet NSMenuItem *loadStatusItem;
@property (weak) IBOutlet NSMenuItem *nextImageItem;
@property (weak) IBOutlet NSMenuItem *changeAllWallpapersItem;
@property (weak) IBOutlet NSMenuItem *addImageToBlackListItem;
@property (weak) IBOutlet NSMenuItem *recentWallpaperItem;
@property (weak) IBOutlet NSMenuItem *saveCurrentWallpaperItem;
@property (weak) IBOutlet NSMenu *updateIntervalMenu;
@property (weak) IBOutlet NSMenuItem *randomizeItem;
@property (weak) IBOutlet NSMenu *collectionMenu;
@property (weak) IBOutlet NSMenuItem *authorItem;
@property (weak) IBOutlet NSMenuItem *availableImageLoads;

@property (nonatomic, assign) BOOL notificationsEnabled;

@property (nonatomic, strong) LPSettingsWindowController *settingsWindowController;
@property (nonatomic, strong) LPAboutWindowController *aboutWindowController;

@end

@implementation AppDelegate {
    NSTimer *updateImageTimer;
    NSTimer *updateLoadStatusToOK;
    BOOL imageLoading;
    
    NSArray *menubarIconAnimationFrames;
    LPNSStatusItemIconAnimator *menuBarAnimator;
}

@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [MagicalRecord setupAutoMigratingCoreDataStack];
    
    NSMutableDictionary *profile = [NSMutableDictionary dictionary];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"Initialized"]) {
        [profile setObject:[NSDate date] forKey:@"$created"];
    }
    NSString *name;
    if (NSFullUserName()) {
        name = NSFullUserName();
    } else {
        name = NSUserName();
    }
    if (name) {
        [profile setObject:name forKey:@"$name"];
    }
    /*******/
    
    [[TTOfflineChecker defaultChecker].notificationCenter addObserver:self selector:@selector(setStatusOK) name:kOfflineStatusChangedNotification object:nil];
    
    NSMutableArray *loadedFrames = [NSMutableArray array];
    for (NSInteger i = 0; i < 33; i++) {
        NSImage *frame = [NSImage imageNamed:[NSString stringWithFormat:@"menuBarLogoAnimation_%ld", (long)i]];
        [frame setTemplate:YES];
        [loadedFrames addObject:frame];
    }
    menubarIconAnimationFrames = [NSArray arrayWithArray:loadedFrames];
    menuBarAnimator = [[LPNSStatusItemIconAnimator alloc] initWithStatusItem:self.statusItem frames:menubarIconAnimationFrames frameDuration:1.0f/40];
    
    if ([[LPSettingsManager sharedManager] isNextWallpaperShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].nextWallpaperShortcut withAction:^{
            [self loadNextImage:nil];
        }];
    }
    if ([[LPSettingsManager sharedManager] isChangeAllWallpapersShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].changeAllWallpapersShortcut withAction:^{
            [self changeAllWallpapers:nil];
        }];
    }
    
    if ([[LPSettingsManager sharedManager] isAddWallpaperToBlacklistShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut withAction:^{
            [self addCurrentImageToBlackList:nil];
        }];
    }
    
    if ([[LPSettingsManager sharedManager] isRecentWallpaperShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].recentWallpaperShortcut withAction:^{
            [self showRecentImage:nil];
        }];
    }
    
    if ([[LPSettingsManager sharedManager] isSaveCurrentWallpaperShortcutEnabled]) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcut withAction:^{
            [self saveCurrentImage:nil];
        }];
    }
    
    self.menu.delegate = self;
    self.menu.autoenablesItems = NO;
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.title = @"";
    NSImage *menuBarLogo = [NSImage imageNamed:@"menuBarLogo"];
    [menuBarLogo setTemplate:YES];
    _statusItem.image = menuBarLogo;
    _statusItem.toolTip = @"Unsplash";
    _statusItem.menu = self.menu;
    menuBarAnimator = [[LPNSStatusItemIconAnimator alloc] initWithStatusItem:self.statusItem frames:menubarIconAnimationFrames frameDuration:1.0f/20];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"Initialized"]) {
        [[LPWallpaperManager sharedManager] setRandomize:NO];
        [[LPWallpaperManager sharedManager] setDuration:LPImageUpdateDuration12Hours];
        [[LPWallpaperManager sharedManager] setScope:LPImageUpdateScopeAll];
        [[LPWallpaperManager sharedManager] setAutoSwithOSXTheme:NO];
        [[LPUnsplashImageManager sharedManager] setCollection:LPUnsplashImageManagerCollectionFeatured];
        [self setNotificationsEnabled:YES];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"Initialized"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        [self setStatusOK];
    }
    
    updateImageTimer = [NSTimer scheduledTimerWithTimeInterval:5*60.0f target:self selector:@selector(loadImage) userInfo:nil repeats:YES];
    [self loadImage];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (self.statusItem) {
        return;
    }
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.title = @"";
    NSImage *menuBarLogo = [NSImage imageNamed:@"menuBarLogo"];
    [menuBarLogo setTemplate:YES];
    self.statusItem.image = menuBarLogo;
    self.statusItem.toolTip = @"Unsplash Wallpaper";
    self.statusItem.menu = self.menu;
    menuBarAnimator = [[LPNSStatusItemIconAnimator alloc] initWithStatusItem:self.statusItem frames:menubarIconAnimationFrames frameDuration:1.0f/20];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
}

#pragma mark Timer Methods

- (void)loadImage {
    if ([[NSDate date] compare:[LPWallpaperManager sharedManager].nextRefreshDate] == NSOrderedDescending) {
        if ([LPWallpaperManager sharedManager].scope == LPImageUpdateScopeAll) {
            [self changeImage];
        } else {
            [self changeAllWallpapers:self];
        }
    }
}

- (void)changeImage {
    self.loadStatusItem.title = @"Updating wallpaper...";
    imageLoading = YES;
    [self startMenubarAnimating];
    
    NSString *currentWorkspace;
    NSString *currentDisplay;
    
    switch ([LPWallpaperManager sharedManager].scope) {
        case LPImageUpdateScopeAll: {
            currentWorkspace = kAnyWorkspace;
            currentDisplay = kAnyDisplay;
        }
            break;
        case LPImageUpdateScopeDisplay: {
            currentWorkspace = [LPWallpaperManager sharedManager].activeSpaceIdentifier;
            currentDisplay = [LPWallpaperManager sharedManager].activeDisplayIdentifier;
            
            if (!currentDisplay) {
                imageLoading = NO;
                [self stopMenubarAnimating];
                [self setStatusOK];
                return;
            }
        }
            break;
        case LPImageUpdateScopeWorkspace:{
            currentWorkspace = [LPWallpaperManager sharedManager].activeSpaceIdentifier;
            currentDisplay = [LPWallpaperManager sharedManager].activeDisplayIdentifier;
            
            if (!currentWorkspace) {
                imageLoading = NO;
                [self stopMenubarAnimating];
                [self setStatusOK];
                return;
            }
        }
            break;
            
        default:
            break;
    }
    
    LPUnsplashLoadImageMode mode;
    if ([LPWallpaperManager sharedManager].randomize) {
        mode = LPUnsplashLoadImageModeRandom;
    } else {
        mode = LPUnsplashLoadImageModeSuccessive;
    }
    
    [[LPUnsplashImageManager sharedManager] loadImageCurrentImageName:[[LPWallpaperManager sharedManager] currentImageNameForWorkspace:currentWorkspace] mode:mode success:^(NSString *imagePath, NSString *name) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[LPWallpaperManager sharedManager] setCurrentImageAtPath:imagePath withName:name forWorkspace:currentWorkspace];
            [[LPWallpaperManager sharedManager] setCurrentImageAtPath:imagePath withName:name forDisplay:currentDisplay];
            
            imageLoading = NO;
            [self setStatusOK];
            [self setAuthorInfo];
            [self stopMenubarAnimating];
            
            if (self.notificationsEnabled) {
                LPUnsplashWallpaper *wallpaper = [[LPUnsplashImageManager sharedManager] wallpaperForName:name];
                [self sendNotificationForWallpaper:wallpaper imagePath:imagePath];
            }
        });
    } failure:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            imageLoading = NO;
            [self stopMenubarAnimating];
            self.loadStatusItem.title = @"Updating wallpaper failed";
            if (updateLoadStatusToOK) {
                [updateLoadStatusToOK invalidate];
                updateLoadStatusToOK = nil;
            }
            updateLoadStatusToOK = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(setStatusOK) userInfo:nil repeats:NO];
        });
    }];
}

#pragma mark Info

- (void)updateItemsInfo {
    [self.randomizeItem setState:([LPWallpaperManager sharedManager].randomize? NSOnState : NSOffState)];
    
    [self.changeAllWallpapersItem setEnabled:([LPWallpaperManager sharedManager].scope != LPImageUpdateScopeAll)];
    
    for (NSMenuItem *item in self.updateIntervalMenu.itemArray) {
        NSInteger index = [self.updateIntervalMenu.itemArray indexOfObject:item];
        if (index == [LPWallpaperManager sharedManager].duration) {
            [item setState:NSOnState];
        } else {
            [item setState:NSOffState];
        }
    }
    
    for (NSMenuItem *item in self.collectionMenu.itemArray) {
        NSInteger index = [self.collectionMenu.itemArray indexOfObject:item];
        if (index == [LPUnsplashImageManager sharedManager].collection) {
            [item setState:NSOnState];
        } else {
            [item setState:NSOffState];
        }
    }
    
    if ([LPUnsplashImageManager sharedManager].imageLoadsPerHourAvailable > 0) {
        self.availableImageLoads.title = [NSString stringWithFormat:@"%ld more times during this hour", (long)[LPUnsplashImageManager sharedManager].imageLoadsPerHourAvailable];
    } else {
        self.availableImageLoads.title = @"in the next hour";
    }
}

- (void)setShortcutsInfo {
    if ([[LPSettingsManager sharedManager] isNextWallpaperShortcutEnabled]) {
        [self.nextImageItem setKeyEquivalent:[LPSettingsManager sharedManager].nextWallpaperShortcut.keyCodeStringForKeyEquivalent];
        [self.nextImageItem setKeyEquivalentModifierMask:[LPSettingsManager sharedManager].nextWallpaperShortcut.modifierFlags];
    } else {
        [self.nextImageItem setKeyEquivalent:@""];
        [self.nextImageItem setKeyEquivalentModifierMask:0];
    }
    if ([[LPSettingsManager sharedManager] isAddWallpaperToBlacklistShortcutEnabled]) {
        [self.addImageToBlackListItem setKeyEquivalent:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut.keyCodeStringForKeyEquivalent];
        [self.addImageToBlackListItem setKeyEquivalentModifierMask:[LPSettingsManager sharedManager].addWallpaperToBlacklistShortcut.modifierFlags];
    } else {
        [self.addImageToBlackListItem setKeyEquivalent:@""];
        [self.addImageToBlackListItem setKeyEquivalentModifierMask:0];
    }
    if ([[LPSettingsManager sharedManager] isRecentWallpaperShortcutEnabled]) {
        [self.recentWallpaperItem setKeyEquivalent:[LPSettingsManager sharedManager].recentWallpaperShortcut.keyCodeStringForKeyEquivalent];
        [self.recentWallpaperItem setKeyEquivalentModifierMask:[LPSettingsManager sharedManager].recentWallpaperShortcut.modifierFlags];
    } else {
        [self.recentWallpaperItem setKeyEquivalent:@""];
        [self.recentWallpaperItem setKeyEquivalentModifierMask:0];
    }
    if ([[LPSettingsManager sharedManager] isSaveCurrentWallpaperShortcutEnabled]) {
        [self.saveCurrentWallpaperItem setKeyEquivalent:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcut.keyCodeStringForKeyEquivalent];
        [self.saveCurrentWallpaperItem setKeyEquivalentModifierMask:[LPSettingsManager sharedManager].saveCurrentWallpaperShortcut.modifierFlags];
    } else {
        [self.saveCurrentWallpaperItem setKeyEquivalent:@""];
        [self.saveCurrentWallpaperItem setKeyEquivalentModifierMask:0];
    }
}

- (void)setAuthorInfo {
    NSString *imageName;
    switch ([LPWallpaperManager sharedManager].scope) {
        case LPImageUpdateScopeAll:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForDisplay:kAnyDisplay];
            break;
        case LPImageUpdateScopeDisplay:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForDisplay:[[LPWallpaperManager sharedManager] activeDisplayIdentifier]];
            break;
        case LPImageUpdateScopeWorkspace:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForWorkspace:[[LPWallpaperManager sharedManager] activeSpaceIdentifier]];
            break;
            
        default:
            break;
    }
    
    LPUnsplashWallpaper *wallpaper = [[LPUnsplashImageManager sharedManager] wallpaperForName:imageName];
    NSString *author;
    if (wallpaper.author) {
        author = wallpaper.author;
    } else if (wallpaper.authorProfileName) {
        author = wallpaper.authorProfileName;
    }
    
    if (author.length == 0) {
        self.authorItem.title = @"-";
        [self.authorItem setEnabled:NO];
    } else {
        self.authorItem.title = [NSString stringWithFormat:@"Photo by %@ →", wallpaper.author];
        [self.authorItem setEnabled:YES];
    }
}

- (void)setStatusOK {
    if (imageLoading) {
        self.loadStatusItem.title = @"Updating wallpaper...";
    } else if ([[TTOfflineChecker defaultChecker] isOffline]) {
        self.loadStatusItem.title = @"No internet connection";
    } else {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        NSString *updateDate = [NSString stringWithFormat:@"Next update %@", [formatter stringFromDate:[LPWallpaperManager sharedManager].nextRefreshDate]];
        NSString *status = nil;
        if ([LPWallpaperManager sharedManager].duration != LPImageUpdateDurationNever) {
            status = updateDate;
        } else {
            status = @"Everything is OK";
        }
        self.loadStatusItem.title = status;
    }

    if (updateLoadStatusToOK) {
        [updateLoadStatusToOK invalidate];
        updateLoadStatusToOK = nil;
    }
}

#pragma mark Other

- (void)setNotificationsEnabled:(BOOL)notificationsEnabled {
    [[NSUserDefaults standardUserDefaults] setBool:notificationsEnabled forKey:kNotificationsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)notificationsEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kNotificationsEnabled];
}

- (void)sendNotificationForWallpaper:(LPUnsplashWallpaper *)wallpaper imagePath:(NSString *)imagePath {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Wallpaper changed";
    if (wallpaper.author) {
        notification.informativeText = [NSString stringWithFormat:@"Photo by %@", wallpaper.author];
    }
    notification.contentImage = [[NSImage alloc] initByReferencingFile:imagePath];
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark Animations

- (void)startMenubarAnimating {
    if (![menuBarAnimator animating]) {
        [menuBarAnimator startAnimating];
    }
}

- (void)stopMenubarAnimating {
    if (!imageLoading) {
        [menuBarAnimator stopAnimating];
        self.statusItem.image = [NSImage imageNamed:@"menuBarLogo"];
    }
}

#pragma mark UIActions

- (IBAction)loadNextImage:(id)sender {
    [self changeImage];
}

- (IBAction)changeAllWallpapers:(id)sender {
    if ([LPWallpaperManager sharedManager].scope == LPImageUpdateScopeAll) {
        return;
    }
    
    self.loadStatusItem.title = @"Updating wallpaper...";
    imageLoading = YES;
    [self startMenubarAnimating];
    
    LPUnsplashLoadImageMode mode;
    if ([LPWallpaperManager sharedManager].randomize) {
        mode = LPUnsplashLoadImageModeRandom;
    } else {
        mode = LPUnsplashLoadImageModeSuccessive;
    }
    
    switch ([LPWallpaperManager sharedManager].scope) {
        case LPImageUpdateScopeAll:
            break;
        case LPImageUpdateScopeDisplay: {
            NSArray *displays = [LPWallpaperManager sharedManager].displayIdentifiers;
            __block NSUInteger finished = 0;
            for (NSString *displayIdentifier in displays) {
                [[LPUnsplashImageManager sharedManager] loadImageCurrentImageName:[[LPWallpaperManager sharedManager] currentImageNameForDisplay:displayIdentifier] mode:mode success:^(NSString *imagePath, NSString *name) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[LPWallpaperManager sharedManager] setCurrentImageAtPath:imagePath withName:name forDisplay:displayIdentifier];
                        
                        if (self.notificationsEnabled) {
                            LPUnsplashWallpaper *wallpaper = [[LPUnsplashImageManager sharedManager] wallpaperForName:name];
                            [self sendNotificationForWallpaper:wallpaper imagePath:imagePath];
                        }
                        
                        finished++;
                        if (finished == displays.count) {
                            imageLoading = NO;
                            [self setStatusOK];
                            [self setAuthorInfo];
                            [self stopMenubarAnimating];
                        }
                    });
                } failure:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        finished++;
                        if (finished == displays.count) {
                            imageLoading = NO;
                            [self stopMenubarAnimating];
                            
                            self.loadStatusItem.title = @"Updating wallpaper failed";
                            if (updateLoadStatusToOK) {
                                [updateLoadStatusToOK invalidate];
                                updateLoadStatusToOK = nil;
                            }
                            updateLoadStatusToOK = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(setStatusOK) userInfo:nil repeats:NO];
                        }
                    });
                }];
            }
        }
            break;
        case LPImageUpdateScopeWorkspace:{
            NSArray *workspaces = [LPWallpaperManager sharedManager].spaceIdentifiers;
            __block NSUInteger finished = 0;
            for (NSString *workspaceIdentifier in workspaces) {
                [[LPUnsplashImageManager sharedManager] loadImageCurrentImageName:[[LPWallpaperManager sharedManager] currentImageNameForWorkspace:workspaceIdentifier] mode:mode success:^(NSString *imagePath, NSString *name) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[LPWallpaperManager sharedManager] setCurrentImageAtPath:imagePath withName:name forWorkspace:workspaceIdentifier];
                        
                        if (self.notificationsEnabled) {
                            LPUnsplashWallpaper *wallpaper = [[LPUnsplashImageManager sharedManager] wallpaperForName:name];
                            [self sendNotificationForWallpaper:wallpaper imagePath:imagePath];
                        }
                        
                        finished++;
                        if (finished == workspaces.count) {
                            imageLoading = NO;
                            [self setStatusOK];
                            [self setAuthorInfo];
                            [self stopMenubarAnimating];
                        }
                    });
                } failure:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        finished++;
                        if (finished == workspaces.count) {
                            imageLoading = NO;
                            [self stopMenubarAnimating];
                            
                            self.loadStatusItem.title = @"Updating wallpaper failed";
                            if (updateLoadStatusToOK) {
                                [updateLoadStatusToOK invalidate];
                                updateLoadStatusToOK = nil;
                            }
                            updateLoadStatusToOK = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(setStatusOK) userInfo:nil repeats:NO];
                        }
                    });
                }];
            }
        }
            break;
            
        default:
            break;
    }
}

- (IBAction)addCurrentImageToBlackList:(id)sender {
    NSString *imageName;
    
    switch ([LPWallpaperManager sharedManager].scope) {
        case LPImageUpdateScopeAll:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForDisplay:kAnyDisplay];
            break;
        case LPImageUpdateScopeDisplay:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForDisplay:[[LPWallpaperManager sharedManager] activeDisplayIdentifier]];
            break;
        case LPImageUpdateScopeWorkspace:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForWorkspace:[[LPWallpaperManager sharedManager] activeSpaceIdentifier]];
            break;
            
        default:
            break;
    }

    [[LPUnsplashImageManager sharedManager] addToBlackListImageWithName:imageName];
    [self loadNextImage:sender];
}

- (IBAction)setUpdateDuration:(id)sender {
    NSInteger index = [self.updateIntervalMenu.itemArray indexOfObject:sender];
    if (index >= 0) {
        [[LPWallpaperManager sharedManager] setDuration:(LPImageUpdateDuration)index];
    } else {
        [[LPWallpaperManager sharedManager] setDuration:LPImageUpdateDurationNever];
    }
    
    [self setStatusOK];
    for (NSMenuItem *item in self.updateIntervalMenu.itemArray) {
        BOOL shouldBeEnabled = ([LPWallpaperManager sharedManager].scope == LPImageUpdateScopeAll);
        NSInteger index = [self.updateIntervalMenu.itemArray indexOfObject:item];
        if (index == [LPWallpaperManager sharedManager].duration) {
            [item setState:NSOnState];
        } else {
            [item setState:NSOffState];
        }
        [item setEnabled:shouldBeEnabled];
    }
}

- (IBAction)toggleRandomize:(id)sender {
    [[LPWallpaperManager sharedManager] setRandomize:![LPWallpaperManager sharedManager].randomize];
    [self.randomizeItem setState:([LPWallpaperManager sharedManager].randomize? NSOnState : NSOffState)];
}

- (IBAction)saveCurrentImage:(id)sender {
    NSString *unsplashFolder = [[NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"UnsplashWallpapers"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:unsplashFolder]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:unsplashFolder withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    NSString *imageName;
    NSImage *image;
    
    switch ([LPWallpaperManager sharedManager].scope) {
        case LPImageUpdateScopeAll:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForDisplay:kAnyDisplay];
            image = [[LPWallpaperManager sharedManager] currentImageForDisplay:kAnyDisplay];
            break;
        case LPImageUpdateScopeDisplay:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForDisplay:[[LPWallpaperManager sharedManager] activeDisplayIdentifier]];
            image = [[LPWallpaperManager sharedManager] currentImageForDisplay:[[LPWallpaperManager sharedManager] activeDisplayIdentifier]];
            break;
        case LPImageUpdateScopeWorkspace:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForWorkspace:[[LPWallpaperManager sharedManager] activeSpaceIdentifier]];
            image = [[LPWallpaperManager sharedManager] currentImageForWorkspace:[[LPWallpaperManager sharedManager] activeSpaceIdentifier]];
            break;
            
        default:
            break;
    }
    
    if (!image) {
        return;
    }
    
    NSString *imagePath = [[unsplashFolder stringByAppendingPathComponent:imageName] stringByAppendingPathExtension:@"png"];
    NSBitmapImageRep *imgRep = (NSBitmapImageRep *)[[image representations] objectAtIndex:0];
    NSData *data = [imgRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    [data writeToFile:imagePath atomically:NO];
    
    if ([[LPSettingsManager sharedManager] isOpenSavedImageEnabled]) {
        [[NSWorkspace sharedWorkspace] openFile:imagePath];
    } else if ([[LPSettingsManager sharedManager] isNotificationsEnabled]) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = @"Unsplash Wallpaper";
        notification.subtitle = @"Image saved";
        notification.contentImage = [[NSImage alloc] initByReferencingFile:imagePath];
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}

- (IBAction)clearBlacklist:(id)sender {
    NSInteger cleared = [[LPUnsplashImageManager sharedManager] clearBlackList];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"%ld images removed from blacklist.", (long)cleared];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (IBAction)showRecentImage:(id)sender {
    self.loadStatusItem.title = @"Updating wallpaper...";
    imageLoading = YES;
    [self startMenubarAnimating];
    
    NSString *currentWorkspace = [LPWallpaperManager sharedManager].activeSpaceIdentifier;
    NSString *currentDisplay = [LPWallpaperManager sharedManager].activeDisplayIdentifier;
    
    switch ([LPWallpaperManager sharedManager].scope) {
        case LPImageUpdateScopeAll:
            currentWorkspace = kAnyWorkspace;
            currentDisplay = kAnyDisplay;
            break;
        case LPImageUpdateScopeDisplay:
            if (!currentDisplay) {
                imageLoading = NO;
                [self stopMenubarAnimating];
                [self setStatusOK];
                return;
            }
            break;
        case LPImageUpdateScopeWorkspace:
            if (!currentWorkspace) {
                imageLoading = NO;
                [self stopMenubarAnimating];
                [self setStatusOK];
                return;
            }
            break;
            
        default:
            break;
    }
    
    [[LPUnsplashImageManager sharedManager] loadRecentImage:^(NSString *imagePath, NSString *name) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[LPWallpaperManager sharedManager] setCurrentImageAtPath:imagePath withName:name forWorkspace:currentWorkspace];
            [[LPWallpaperManager sharedManager] setCurrentImageAtPath:imagePath withName:name forDisplay:currentDisplay];
            
            imageLoading = NO;
            [self stopMenubarAnimating];
            [self setStatusOK];
            [self setAuthorInfo];
            
            if (self.notificationsEnabled) {
                LPUnsplashWallpaper *wallpaper = [[LPUnsplashImageManager sharedManager] wallpaperForName:name];
                [self sendNotificationForWallpaper:wallpaper imagePath:imagePath];
            }
        });
    } failure:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error.code == 1) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self showRecentImage:sender];
                });
            }
            imageLoading = NO;
            [self stopMenubarAnimating];
            
            self.loadStatusItem.title = @"Updating wallpaper failed";
            if (updateLoadStatusToOK) {
                [updateLoadStatusToOK invalidate];
                updateLoadStatusToOK = nil;
            }
            updateLoadStatusToOK = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(setStatusOK) userInfo:nil repeats:NO];
        });
    }];
}

- (IBAction)setCollection:(id)sender {
    NSInteger index = [self.collectionMenu.itemArray indexOfObject:sender];
    if (index >= 0) {
        [[LPUnsplashImageManager sharedManager] setCollection:(LPUnsplashImageManagerCollection)index];
    }
    
    for (NSMenuItem *item in self.collectionMenu.itemArray) {
        NSInteger index = [self.collectionMenu.itemArray indexOfObject:item];
        if (index == [LPUnsplashImageManager sharedManager].collection) {
            [item setState:NSOnState];
        } else {
            [item setState:NSOffState];
        }
    }
}

- (IBAction)openAuthorProfile:(id)sender {
    NSString *imageName;
    switch ([LPWallpaperManager sharedManager].scope) {
        case LPImageUpdateScopeAll:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForDisplay:kAnyDisplay];
            break;
        case LPImageUpdateScopeDisplay:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForDisplay:[[LPWallpaperManager sharedManager] activeDisplayIdentifier]];
            break;
        case LPImageUpdateScopeWorkspace:
            imageName = [[LPWallpaperManager sharedManager] currentImageNameForWorkspace:[[LPWallpaperManager sharedManager] activeSpaceIdentifier]];
            break;
            
        default:
            break;
    }
    
    LPUnsplashWallpaper *wallpaper = [[LPUnsplashImageManager sharedManager] wallpaperForName:imageName];
    if (wallpaper) {
        [[NSWorkspace sharedWorkspace] openURL:[[LPUnsplashImageManager sharedManager] URLForProfileName:wallpaper.authorProfileName]];
    }
}

- (IBAction)openSettings:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    if (!self.settingsWindowController) {
        self.settingsWindowController = [[LPSettingsWindowController alloc] initWithWindowNibName:NSStringFromClass(LPSettingsWindowController.class)];
    }
    [self.settingsWindowController show];
}

- (IBAction)showAboutWindow:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    
    if (!self.aboutWindowController) {
        self.aboutWindowController = [[LPAboutWindowController alloc] initWithWindowNibName:NSStringFromClass(LPAboutWindowController.class)];
    }
    [self.aboutWindowController show];
}

- (IBAction)hideMenubarIcon:(id)sender {
    [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
    self.statusItem = nil;
}

- (IBAction)quit:(id)sender {
    [[LPWallpaperManager sharedManager] resetTheme];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSApplication sharedApplication] terminate:sender];
    });
}

#pragma mark NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    [self updateItemsInfo];
    [self setAuthorInfo];
    [self setShortcutsInfo];
}

#pragma mark Core Data

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil)
    {
        if ([managedObjectContext hasChanges] & ![managedObjectContext save:&error])
        {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil)
    {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil)
    {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"LPWallpapers" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil)
    {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"LPWallpapers.sqlite"];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error])
    {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
