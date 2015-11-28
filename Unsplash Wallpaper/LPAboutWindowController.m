//
//  LPAboutWindowController.m
//  Unsplash Wallpaper
//
//  Created by Игорь Савельев on 24/07/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "LPAboutWindowController.h"

@interface LPAboutWindowController ()
@property (weak) IBOutlet NSTextField *versionLabel;

@end

@implementation LPAboutWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    self.versionLabel.stringValue = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (void)show {
    [self.window makeKeyAndOrderFront:self];
}

@end
