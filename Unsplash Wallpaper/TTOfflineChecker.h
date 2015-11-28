//
//  TTOfflineChecker.h
//  tentracks-ios
//
//  Created by Игорь Савельев on 15/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kTTDomain @"unsplash.com"
#define kOfflineStatusChangedNotification @"kOfflineStatusChanged"

enum {
    TTNetworkConnectionWIFI,
    TTNetworkConnectionCellular,
    TTNetworkConnectionNone
} typedef TTNetworkConnection;

@interface TTOfflineChecker : NSObject
@property (nonatomic, readonly) NSNotificationCenter *notificationCenter;

@property (nonatomic) BOOL enabled;
@property (atomic, readonly) BOOL offline;
@property (atomic, readonly) TTNetworkConnection networkConnection;
@property (nonatomic, strong, readonly) NSString *publicIP;
@property (nonatomic, setter = setOfflineManually:) BOOL isManualOffline;

+ (instancetype)defaultChecker;

- (BOOL)isOffline;

@end
