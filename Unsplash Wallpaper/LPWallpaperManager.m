//
//  LPWallpaperManager.m
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 04/06/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "LPWallpaperManager.h"
#import "NSImage+Luminance.h"

@import AppKit;

static NSString *const kNextRefreshDateKey = @"NextRefreshDate";
static NSString *const kLastRefreshDateKey = @"LastRefreshDate";
static NSString *const kDurationKey = @"Duration";
static NSString *const kScopeKey = @"Scope";
static NSString *const kRandomizeKey = @"Randomize";
static NSString *const kAutoSwithOSXThemeKey = @"autoSwithOSXTheme";
static NSString *const kImagesForWorkspaceInfoPlistFileName = @"imagesForWorkspace.plist";
static NSString *const kImagesForDisplayInfoPlistFileName = @"imagesForDisplay.plist";
static NSString *const kImagesLuminanceInfoPlistFileName = @"imagesLuminance.plist";
//will be removed
static NSString *const kCurrentImageIDKey = @"CurrentImageID";
static NSString *const kSystemPreferencesDarkModeOn = @"SystemPreferencesDarkModeOn";

@implementation LPWallpaperManager {
    NSString *cacheFolder;
    NSString *applicationSupportFolder;
    NSURLSession *session;
    
    NSString *setWallpaperForWorkspaceScriptSource;
    
    dispatch_queue_t luminanceCalculatingQueue;
}

+ (instancetype)sharedManager {
    static LPWallpaperManager *__sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedManager = [[LPWallpaperManager alloc] init];
    });
    return __sharedManager;
}

- (id)init {
    self = [super init];
    if (self) {
        session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        [self updatePaths];
        
        luminanceCalculatingQueue = dispatch_queue_create("Luminance Calculating", DISPATCH_QUEUE_SERIAL);
        
        setWallpaperForWorkspaceScriptSource = @"tell application \"System Events\"\n";
        setWallpaperForWorkspaceScriptSource = [setWallpaperForWorkspaceScriptSource stringByAppendingString:@"\t set picture of desktop <desktop> to POSIX file \"<file>\"\n"];
        setWallpaperForWorkspaceScriptSource = [setWallpaperForWorkspaceScriptSource stringByAppendingString:@"end tell"];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *currentImageID = [[NSUserDefaults standardUserDefaults] objectForKey:kCurrentImageIDKey];
            if (currentImageID) {
                NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:currentImageID];
                [self setCurrentImageAtPath:imagePath withName:[NSString stringWithFormat:@"unsplash_%@", currentImageID] forWorkspace:kAnyWorkspace];
                [self setCurrentImageAtPath:imagePath withName:[NSString stringWithFormat:@"unsplash_%@", currentImageID] forDisplay:kAnyDisplay];
                [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCurrentImageIDKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        });
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(activeSpaceDidChange) name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screensChanged) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    }
    return self;
}

- (void)updatePaths {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    cacheFolder = [paths firstObject];
    paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    applicationSupportFolder = [[paths firstObject] stringByAppendingPathComponent:@"Unsplash Wallpaper"];
}

#pragma mark Getters and Setters

- (NSDate *)nextRefreshDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kNextRefreshDateKey];
}

- (void)setNextRefreshDate:(NSDate *)nextRefreshDate {
    if (!nextRefreshDate) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kNextRefreshDateKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:nextRefreshDate forKey:kNextRefreshDateKey];
    }
    NSLog(@"Next refresh date will be %@", [nextRefreshDate descriptionWithLocale:[NSLocale currentLocale]]);
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)lastRefreshDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastRefreshDateKey];
}

- (void)setLastRefreshDate:(NSDate *)lastRefreshDate {
    if (!lastRefreshDate) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLastRefreshDateKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:lastRefreshDate forKey:kLastRefreshDateKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)randomize {
    //return [[NSUserDefaults standardUserDefaults] boolForKey:kRandomizeKey];
    return YES;
}

- (void)setRandomize:(BOOL)randomize{
    [[NSUserDefaults standardUserDefaults] setBool:randomize forKey:kRandomizeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)autoSwithOSXTheme {
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_10 || self.scope != LPImageUpdateScopeAll) {
        return NO;
    }
    
    return [[NSUserDefaults standardUserDefaults] boolForKey:kAutoSwithOSXThemeKey];
}

- (void)setAutoSwithOSXTheme:(BOOL)autoSwithOSXTheme {
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_10 || self.scope != LPImageUpdateScopeAll) {
        autoSwithOSXTheme = NO;
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:autoSwithOSXTheme forKey:kAutoSwithOSXThemeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (!autoSwithOSXTheme) {
        [self resetTheme];
    } else {
        [self setSuitableThemeIfNeeded];
    }
}

- (BOOL)isDarkModeEnabledInPreferencePanel {
    [[NSUserDefaults standardUserDefaults] removeSuiteNamed:NSGlobalDomain];
    [[NSUserDefaults standardUserDefaults] addSuiteNamed:NSGlobalDomain];
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    NSLog(@"MODE: %@", mode);
    [[NSUserDefaults standardUserDefaults] removeSuiteNamed:NSGlobalDomain];
    return [[mode uppercaseString] rangeOfString:@"DARK"].location != NSNotFound;
}

- (void)resetTheme {
    CFPreferencesSetValue((CFStringRef)@"AppleInterfaceStyle", NULL, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    dispatch_async(dispatch_get_main_queue(), ^{
        CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), (CFStringRef)@"AppleInterfaceThemeChangedNotification", NULL, NULL, YES);
    });
}

- (LPImageUpdateDuration)duration {
    if (self.scope != LPImageUpdateScopeAll) {
        return LPImageUpdateDurationNever;
    }
    
    NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:kDurationKey];
    return (LPImageUpdateDuration)[number integerValue];
}

- (void)setDuration:(LPImageUpdateDuration)duration {
    [[NSUserDefaults standardUserDefaults] setObject:@(duration) forKey:kDurationKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (self.lastRefreshDate) {
        [self setNextRefreshDate:[self.lastRefreshDate dateByAddingTimeInterval:[self timeIntervalForDuration:duration]]];
    } else {
        [self setNextRefreshDate:[[NSDate date] dateByAddingTimeInterval:[self timeIntervalForDuration:duration]]];
    }
}

- (LPImageUpdateScope)scope {
    NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:kScopeKey];
    return (LPImageUpdateScope)[number integerValue];
}

- (void)setScope:(LPImageUpdateScope)scope {
    [[NSUserDefaults standardUserDefaults] setObject:@(scope) forKey:kScopeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark Helpers

- (NSTimeInterval)timeIntervalForDuration:(LPImageUpdateDuration)duration {
    switch (duration) {
        case LPImageUpdateDurationNever:
            return 10*365*24*60*60;
            break;
        case LPImageUpdateDuration12Hours:
            return 12*60*60;
            break;
        case LPImageUpdateDuration24Hours:
            return 24*60*60;
            break;
        case LPImageUpdateDuration2Weeks:
            return 2*7*24*60*60;
            break;
        case LPImageUpdateDuration3Hours:
            return 3*60*60;
            break;
        case LPImageUpdateDurationWeek:
            return 7*24*60*60;
            break;
        case LPImageUpdateDurationMonth:
            return 30*24*60*60;
            break;
    }
}

#pragma mark Wallpapers Managing

- (void)activeSpaceDidChange {
    [self setWallpaper];
}

- (void)screensChanged {
    [self setWallpaper];
}

- (void)setWallpaper {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (self.scope) {
            case LPImageUpdateScopeAll: {
                NSString *imageName = [self currentImageNameForWorkspace:kAnyWorkspace];
                if (!imageName || imageName.length == 0) {
                    imageName = [self currentImageNameForDisplay:kAnyDisplay];
                    if (!imageName || imageName.length == 0) {
                        return;
                    }
                }
                
                NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:imageName];
                NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
                BOOL changed = NO;
                for (NSScreen *screen in [NSScreen screens]) {
                    NSError *error;
                    NSDictionary *properties = [[[NSWorkspace sharedWorkspace] desktopImageOptionsForScreen:screen] copy];
                    
                    if (![[[NSWorkspace sharedWorkspace] desktopImageURLForScreen:screen] isEqual:imageURL]) {
                        BOOL set = [[NSWorkspace sharedWorkspace] setDesktopImageURL:imageURL forScreen:screen options:properties error:&error];
                        changed = set;
                        NSLog(@"Wallpaper %@set for screen %ld", (set? @"": @"not "), (long)[[NSScreen screens] indexOfObject:screen]);
                        if (error) {
                            NSLog(@"Can not set wallpaper: %@", [error description]);
                        }
                    }
                }
                
                if (self.autoSwithOSXTheme && changed) {
                    [self setSuitableThemeIfNeeded];
                }
            }
                break;
            case LPImageUpdateScopeDisplay: {
                for (NSScreen *screen in [NSScreen screens]) {
                    NSString *imageName = [self currentImageNameForDisplay:[self monitorIdentifierForIndex:[[NSScreen screens] indexOfObject:screen]]];
                    if (!imageName || imageName.length == 0) {
                        return;
                    }
                    
                    NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:imageName];
                    NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
                    
                    NSError *error;
                    NSDictionary *properties = [[[NSWorkspace sharedWorkspace] desktopImageOptionsForScreen:screen] copy];
                    
                    if (![[[NSWorkspace sharedWorkspace] desktopImageURLForScreen:screen] isEqual:imageURL]) {
                        BOOL set = [[NSWorkspace sharedWorkspace] setDesktopImageURL:imageURL forScreen:screen options:properties error:&error];
                        NSLog(@"Wallpaper %@set for screen %ld", (set? @"": @"not "), (long)[[NSScreen screens] indexOfObject:screen]);
                        if (error) {
                            NSLog(@"Can not set wallpaper: %@", [error description]);
                        }
                    }
                }
            }
                break;
            case LPImageUpdateScopeWorkspace: {
                NSString *activeSpaceID = [self activeSpaceIdentifier];
//                NSLog(@"SPACE: %@\nDISPLAY INDEX: %ld\nDISPLAY: %@\nIMAGE: %@", activeSpaceID, (long)[self currentDisplayIndex], [self monitorIdentifierForIndex:[self currentDisplayIndex]], [self currentImageNameForWorkspace:activeSpaceID]);
                NSString *imageName = [self currentImageNameForWorkspace:activeSpaceID];
                if (!imageName || imageName.length == 0 || ![self currentDisplayHasSpace:activeSpaceID]) {
                    return;
                }
                
                NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:imageName];
                
                NSString *script = [setWallpaperForWorkspaceScriptSource stringByReplacingOccurrencesOfString:@"<file>" withString:imagePath];
                script = [script stringByReplacingOccurrencesOfString:@"<desktop>" withString:[NSString stringWithFormat:@"%ld", (long)[self currentDisplayIndex]+1]];
                NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
                NSDictionary *error;
                [appleScript executeAndReturnError:&error];
                if (error) {
                    NSLog(@"Can not set wallpaper: %@", [error description]);
                }
            }
                break;
                
            default:
                break;
        }
    });
}

- (void)setDarkTheme:(BOOL)dark {
    if (dark) {
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/defaults";
        task.arguments = @[@"write", @"NSGlobalDomain", @"AppleInterfaceStyle", @"Dark"];
        [task launch];
        CFPreferencesSetValue((CFStringRef)@"AppleInterfaceStyle", (__bridge CFPropertyListRef)(@"Dark"), kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
        dispatch_async(dispatch_get_main_queue(), ^{
            CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), (CFStringRef)@"AppleInterfaceThemeChangedNotification", NULL, NULL, YES);
        });
    } else if (!dark) {
        BOOL wasDark = [self isDarkModeEnabledInPreferencePanel];
        
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/defaults";
        task.arguments = @[@"remove", @"NSGlobalDomain", @"AppleInterfaceStyle"];
        [task launch];
        CFPreferencesSetValue((CFStringRef)@"AppleInterfaceStyle", NULL, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
        
        if (wasDark) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSTask *task = [[NSTask alloc] init];
                task.launchPath = @"/usr/bin/defaults";
                task.arguments = @[@"remove", @"NSGlobalDomain", @"AppleInterfaceStyle"];
                [task launch];
                CFPreferencesSetValue((CFStringRef)@"AppleInterfaceStyle", NULL, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
                dispatch_async(dispatch_get_main_queue(), ^{
                    CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), (CFStringRef)@"AppleInterfaceThemeChangedNotification", NULL, NULL, YES);
                });
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), (CFStringRef)@"AppleInterfaceThemeChangedNotification", NULL, NULL, YES);
        });
    }
}

- (void)setSuitableThemeIfNeeded {
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_10) {
        return;
    }
    
    NSString *imageName = [self currentImageNameForWorkspace:kAnyWorkspace];
    if (!imageName || imageName.length == 0) {
        imageName = [self currentImageNameForDisplay:kAnyDisplay];
        if (!imageName || imageName.length == 0) {
            return;
        }
    }
    
    CGFloat luminance = [self luminanceForImageWithName:imageName];
    BOOL shouldBeDark = luminance < 0.375f;
    [self setDarkTheme:shouldBeDark];
}

- (NSInteger)currentDisplayIndex {
    for (int i = 1; i <= [NSScreen screens].count; i++) {
        NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"System Events\"\n\tget id of desktop %d \nend tell", i]];
        NSAppleEventDescriptor *result = [script executeAndReturnError:nil];
        
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber *screenIDFromScript = [formatter numberFromString:[result stringValue]];
        
        NSNumber *screenID = [[[NSScreen mainScreen] deviceDescription] objectForKey:@"NSScreenNumber"];
        
        if ([screenIDFromScript isEqual:screenID]) {
            return i-1;
        }
    }
    return -1;
}

- (NSString *)monitorIdentifierForIndex:(NSInteger)index {
    [[NSUserDefaults standardUserDefaults] removeSuiteNamed:@"com.apple.spaces"];
    [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.apple.spaces"];
    
    NSArray *monitors = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"SpacesDisplayConfiguration"][@"Management Data"][@"Monitors"];
    
    NSDictionary *monitor;
    if (index >= 0 && monitors.count > index) {
        monitor = [monitors objectAtIndex:index];
    }
    
    if (!monitor) {
        return nil;
    }
    
    NSString *monitorIdentifier = [monitor objectForKey:@"Display Identifier"];
    return monitorIdentifier;
}

- (NSString *)activeDisplayIdentifier {
    return [self monitorIdentifierForIndex:[self currentDisplayIndex]];
}

- (BOOL)currentDisplayHasSpace:(NSString *)spaceID {
    [[NSUserDefaults standardUserDefaults] removeSuiteNamed:@"com.apple.spaces"];
    [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.apple.spaces"];
    
    NSArray *monitors = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"SpacesDisplayConfiguration"][@"Management Data"][@"Monitors"];
    
    NSDictionary *monitor;
    NSInteger index = [self currentDisplayIndex];
    if (index >= 0 && monitors.count > index) {
        monitor = [monitors objectAtIndex:index];
    }
    
    if (!monitor) {
        return NO;
    }
    
    NSArray *spaces = [monitor objectForKey:@"Spaces"];
    for (NSDictionary *space in spaces) {
        if ([[space objectForKey:@"uuid"] isEqualToString:spaceID]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)activeSpaceIdentifier {
    [[NSUserDefaults standardUserDefaults] removeSuiteNamed:@"com.apple.spaces"];
    [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.apple.spaces"];
    
    NSString *spacesConfigurationKey = @"SpacesDisplayConfiguration";
    
    NSArray *spaceProperties = [[NSUserDefaults standardUserDefaults] dictionaryForKey:spacesConfigurationKey][@"Space Properties"];
    NSMutableDictionary *spaceIdentifiersByWindowNumber = [NSMutableDictionary dictionary];
    for (NSDictionary *spaceDictionary in spaceProperties) {
        NSArray *windows = spaceDictionary[@"windows"];
        for (NSNumber *window in windows) {
            if (spaceIdentifiersByWindowNumber[window]) {
                spaceIdentifiersByWindowNumber[window] = [spaceIdentifiersByWindowNumber[window] arrayByAddingObject:spaceDictionary[@"name"]];
            } else {
                spaceIdentifiersByWindowNumber[window] = @[ spaceDictionary[@"name"] ];
            }
        }
    }
    
    CFArrayRef windowDescriptions = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    NSMutableSet *activeSpaceIdentifiers = [NSMutableSet set];
    
    for (NSDictionary *dictionary in (__bridge NSArray *)windowDescriptions) {
        NSNumber *windowNumber = dictionary[(__bridge NSString *)kCGWindowNumber];
        NSArray *spaceIdentifiers = spaceIdentifiersByWindowNumber[windowNumber];
        
        if (spaceIdentifiers.count == 1) {
            [activeSpaceIdentifiers addObject:spaceIdentifiers[0]];
        }
    }
    
    CFRelease(windowDescriptions);

    NSArray *monitors = [[NSUserDefaults standardUserDefaults] dictionaryForKey:spacesConfigurationKey][@"Management Data"][@"Monitors"];
    
    NSDictionary *monitor;
    NSInteger currentMonitorIndex = [self currentDisplayIndex];
    if (currentMonitorIndex >= 0 && monitors.count > currentMonitorIndex) {
        monitor = [monitors objectAtIndex:currentMonitorIndex];
    }
    
    NSString *activeSpaceIdentifier;
    for (NSString *spaceID in activeSpaceIdentifiers) {
        NSArray *spaces = [monitor objectForKey:@"Spaces"];
        for (NSDictionary *space in spaces) {
            if ([[space objectForKey:@"uuid"] isEqualToString:spaceID]) {
                activeSpaceIdentifier = spaceID;
                break;
            }
        }
    }
    
    return activeSpaceIdentifier;
}

- (NSArray *)spaceIdentifiers {
    [[NSUserDefaults standardUserDefaults] removeSuiteNamed:@"com.apple.spaces"];
    [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.apple.spaces"];
    
    NSString *spacesConfigurationKey = @"SpacesDisplayConfiguration";
    
    NSMutableArray *activeSpaceIdentifiers = [NSMutableArray array];
    NSArray *monitors = [[NSUserDefaults standardUserDefaults] dictionaryForKey:spacesConfigurationKey][@"Management Data"][@"Monitors"];
    for (NSDictionary *monitor in monitors) {
        NSArray *spaces = [monitor objectForKey:@"Spaces"];
        for (NSDictionary *space in spaces) {
            if ([[space objectForKey:@"uuid"] isKindOfClass:NSString.class]) {
                [activeSpaceIdentifiers addObject:[space objectForKey:@"uuid"]];
            }
        }
    }
    
    return activeSpaceIdentifiers;
}

- (NSArray *)displayIdentifiers {
    [[NSUserDefaults standardUserDefaults] removeSuiteNamed:@"com.apple.spaces"];
    [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.apple.spaces"];
    
    NSArray *monitors = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"SpacesDisplayConfiguration"][@"Management Data"][@"Monitors"];
    
    NSMutableArray *displayIdentifiers = [NSMutableArray array];
    for (NSDictionary *monitor in monitors) {
        if ([[monitor objectForKey:@"Display Identifier"] isKindOfClass:NSString.class]) {
            [displayIdentifiers addObject:[monitor objectForKey:@"Display Identifier"]];
        }
    }
    return displayIdentifiers;
}

#pragma mark Images Managing

- (CGFloat)luminanceForImageWithName:(NSString *)name {
    NSString *plistFilePath = [applicationSupportFolder stringByAppendingPathComponent:kImagesLuminanceInfoPlistFileName];
    NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithContentsOfFile:plistFilePath];
    
    if (!info || ![info.allKeys containsObject:name]) {
        [self calculateAndSaveLuminanceForName:name completion:NULL];
        return 0.5f;
    }
    return [[info objectForKey:name] doubleValue];
}

- (void)calculateAndSaveLuminanceForName:(NSString *)name completion:(void (^)())completion {
    dispatch_async(luminanceCalculatingQueue, ^{
        NSString *plistFilePath = [applicationSupportFolder stringByAppendingPathComponent:kImagesLuminanceInfoPlistFileName];
        NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithContentsOfFile:plistFilePath];
        if (!info) {
            info = [NSMutableDictionary dictionary];
        }
        
        if ([info.allKeys containsObject:name]) {
            if (completion) {
                completion();
            }
            return;
        } else {
            [info setObject:@0.5 forKey:name];
        }
        [info writeToFile:plistFilePath atomically:YES];
        
        NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:name];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
        if (image) {
            CGFloat luminance = image.luminance;
            [info setObject:@(luminance) forKey:name];
            [info writeToFile:plistFilePath atomically:YES];
        }
        
        if (completion) {
            completion();
        }
    });
}

- (NSString *)currentImageNameForWorkspace:(NSString *)workspace {
    NSString *imageInfoPlistPath = [applicationSupportFolder stringByAppendingPathComponent:kImagesForWorkspaceInfoPlistFileName];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:imageInfoPlistPath];
    return [info objectForKey:workspace];
}

- (NSString *)currentImageNameForDisplay:(NSString *)display {
    NSString *imageInfoPlistPath = [applicationSupportFolder stringByAppendingPathComponent:kImagesForDisplayInfoPlistFileName];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:imageInfoPlistPath];
    return [info objectForKey:display];
}

- (NSImage *)currentImageForWorkspace:(NSString *)workspace {
    NSString *imageName = [self currentImageNameForWorkspace:workspace];
    NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:imageName];
    return [[NSImage alloc] initWithContentsOfFile:imagePath];
}

- (NSImage *)currentImageForDisplay:(NSString *)display {
    NSString *imageName = [self currentImageNameForDisplay:display];
    NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:imageName];
    return [[NSImage alloc] initWithContentsOfFile:imagePath];
}

- (void)setCurrentImage:(NSImage *)image
               withName:(NSString *)name
           forWorkspace:(NSString *)workspace {
    if (!workspace) {
        return;
    }
    
    NSBitmapImageRep *imgRep = [[image representations] objectAtIndex:0];
    NSData *data = [imgRep representationUsingType:NSPNGFileType properties:nil];
    NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:name];
    [data writeToFile:imagePath atomically:YES];
    
    [self setCurrentImageAtPath:imagePath withName:name forWorkspace:workspace];
}

- (void)setCurrentImageAtPath:(NSString *)imagePath
                     withName:(NSString *)name
                 forWorkspace:(NSString *)workspace {
    if (!workspace) {
        return;
    }
    
    NSString *destinationPath = [applicationSupportFolder stringByAppendingPathComponent:name];
    if (![imagePath isEqualToString:destinationPath]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
        }
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:imagePath toPath:destinationPath error:&error];
    }
    
    NSString *imageInfoPlistPath = [applicationSupportFolder stringByAppendingPathComponent:kImagesForWorkspaceInfoPlistFileName];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:imageInfoPlistPath];
    
    NSString *oldImageName = [self currentImageNameForWorkspace:workspace];
    
    if (!info) {
        info = [@{workspace: name} mutableCopy];
    } else {
        [info setObject:name forKey:workspace];
    }
    [info writeToFile:imageInfoPlistPath atomically:YES];
    
    if (![workspace isEqualToString:kAnyWorkspace]) {
        [self setCurrentImageAtPath:imagePath withName:name forWorkspace:kAnyWorkspace];
    }
    
    if (oldImageName && ![self isInUse:oldImageName]) {
        [[NSFileManager defaultManager] removeItemAtPath:[applicationSupportFolder stringByAppendingPathComponent:oldImageName] error:nil];
    }
    
    [self calculateAndSaveLuminanceForName:name completion:^{
        [self setLastRefreshDate:[NSDate date]];
        [self setNextRefreshDate:[[NSDate date] dateByAddingTimeInterval:[self timeIntervalForDuration:self.duration]]];
        [self setWallpaper];
    }];
}

- (void)setCurrentImage:(NSImage *)image
               withName:(NSString *)name
             forDisplay:(NSString *)display {
    if (!display) {
        return;
    }
    
    NSBitmapImageRep *imgRep = [[image representations] objectAtIndex:0];
    NSData *data = [imgRep representationUsingType:NSPNGFileType properties:nil];
    NSString *imagePath = [applicationSupportFolder stringByAppendingPathComponent:name];
    [data writeToFile:imagePath atomically:YES];
    
    [self setCurrentImageAtPath:imagePath withName:name forDisplay:display];
}

- (void)setCurrentImageAtPath:(NSString *)imagePath
                     withName:(NSString *)name
                   forDisplay:(NSString *)display {
    if (!display) {
        return;
    }
    
    NSString *destinationPath = [applicationSupportFolder stringByAppendingPathComponent:name];
    if (![imagePath isEqualToString:destinationPath]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
        }
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:imagePath toPath:destinationPath error:&error];
    }
    
    NSString *imageInfoPlistPath = [applicationSupportFolder stringByAppendingPathComponent:kImagesForDisplayInfoPlistFileName];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:imageInfoPlistPath];
    
    NSString *oldImageName = [self currentImageNameForDisplay:display];
    
    if (!info) {
        info = [@{display: name} mutableCopy];
    } else {
        [info setObject:name forKey:display];
    }
    [info writeToFile:imageInfoPlistPath atomically:YES];
    
    if (![display isEqualToString:kAnyDisplay]) {
        [self setCurrentImageAtPath:imagePath withName:name forDisplay:kAnyDisplay];
    }
    
    if (oldImageName && ![self isInUse:oldImageName]) {
        [[NSFileManager defaultManager] removeItemAtPath:[applicationSupportFolder stringByAppendingPathComponent:oldImageName] error:nil];
    }
    
    [self calculateAndSaveLuminanceForName:name completion:^{
        [self setLastRefreshDate:[NSDate date]];
        [self setNextRefreshDate:[[NSDate date] dateByAddingTimeInterval:[self timeIntervalForDuration:self.duration]]];
        [self setWallpaper];
    }];
}

- (BOOL)isInUse:(NSString *)imageName {
    NSString *imageInfoPlistPath = [applicationSupportFolder stringByAppendingPathComponent:kImagesForDisplayInfoPlistFileName];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:imageInfoPlistPath];
    
    for (NSString *name in info.allValues) {
        if ([name isEqualToString:imageName]) {
            return YES;
        }
    }
    
    imageInfoPlistPath = [applicationSupportFolder stringByAppendingPathComponent:kImagesForWorkspaceInfoPlistFileName];
    info = [NSMutableDictionary dictionaryWithContentsOfFile:imageInfoPlistPath];
    for (NSString *name in info.allValues) {
        if ([name isEqualToString:imageName]) {
            return YES;
        }
    }
    return NO;
}

@end
