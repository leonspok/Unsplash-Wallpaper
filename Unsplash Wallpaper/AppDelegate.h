//
//  AppDelegate.h
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 31/01/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

- (IBAction)loadNextImage:(id)sender;
- (IBAction)changeAllWallpapers:(id)sender;
- (IBAction)showRecentImage:(id)sender;
- (IBAction)saveCurrentImage:(id)sender;
- (IBAction)addCurrentImageToBlackList:(id)sender;


@end

