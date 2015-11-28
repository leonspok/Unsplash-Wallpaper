//
//  TTOfflineChecker.m
//  tentracks-ios
//
//  Created by Игорь Савельев on 15/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import "TTOfflineChecker.h"
#import "AFNetworkReachabilityManager.h"

@interface TTOfflineChecker()
@property (atomic, readwrite) BOOL offline;
@property (atomic, readwrite) TTNetworkConnection networkConnection;
@end

@implementation TTOfflineChecker {
    AFNetworkReachabilityManager *_reachabilityManager;
}

+ (instancetype)defaultChecker {
    static TTOfflineChecker* _checker = nil;
    static dispatch_once_t oncePresicate;
    dispatch_once(&oncePresicate, ^{
        _checker = [[TTOfflineChecker alloc] init];
    });
    return _checker;
}

- (id)init {
    self = [super init];
    if (self) {
        _notificationCenter = [[NSNotificationCenter alloc] init];
        
        _reachabilityManager = [AFNetworkReachabilityManager managerForDomain:kTTDomain];
        __block NSNotificationCenter *notificationCenter = _notificationCenter;
        __block TTOfflineChecker *offlineChecker = self;
        [_reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            switch(status) {
                case AFNetworkReachabilityStatusNotReachable:
                case AFNetworkReachabilityStatusUnknown: {
                    [offlineChecker clearIP];
                    offlineChecker.offline = YES;
                    offlineChecker.networkConnection = TTNetworkConnectionNone;
                }
                    break;
                case AFNetworkReachabilityStatusReachableViaWiFi: {
                    [offlineChecker getIP];
                    offlineChecker.networkConnection = TTNetworkConnectionWIFI;
                    offlineChecker.offline = NO;
                }
                    break;
                case AFNetworkReachabilityStatusReachableViaWWAN:{
                    [offlineChecker getIP];
                    offlineChecker.networkConnection = TTNetworkConnectionCellular;
                    offlineChecker.offline = NO;
                }
                    break;
            }
            [notificationCenter postNotificationName:kOfflineStatusChangedNotification object:nil];
        }];
        [self setEnabled:YES];
    }
    return self;
}

- (BOOL)isOffline {
    return _offline || _isManualOffline;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    if (enabled) {
        [_reachabilityManager startMonitoring];
    } else {
        [_reachabilityManager stopMonitoring];
    }
}

- (void)setOfflineManually:(BOOL)offline {
    _isManualOffline = offline;
    if (offline) {
        _networkConnection = TTNetworkConnectionNone;
    } else {
        if ([_reachabilityManager isReachableViaWiFi]) {
            _networkConnection = TTNetworkConnectionWIFI;
        } else if ([_reachabilityManager isReachableViaWWAN]) {
            _networkConnection = TTNetworkConnectionCellular;
        }
    }
    if (_isManualOffline != _offline) {
        [_notificationCenter postNotificationName:kOfflineStatusChangedNotification object:nil];
    }
}

- (void)getIP {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *url = @"http://api.ipify.org?format=json";
        NSHTTPURLResponse *response;
        NSError *error;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]] returningResponse:&response error:&error];
        
        if (error || response.statusCode >= 400) {
            return;
        }
        
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
        if (error) {
            return;
        }
        
        if (result) {
            _publicIP = [result objectForKey:@"ip"];
        }
    });
}

- (void)clearIP {
    _publicIP = nil;
}

@end
