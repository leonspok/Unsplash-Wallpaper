#import "EnumsToStrings.h"
#import "LPUnsplashImageManager.h"
#import "LPWallpaperManager.h"

NSString * const UpdateScope_toString[] = {
    [LPImageUpdateScopeAll] = @"All",
    [LPImageUpdateScopeDisplay] = @"Display",
    [LPImageUpdateScopeWorkspace] = @"Workspace"
};

NSString * const UpdateDuration_toString[] = {
    [LPImageUpdateDurationNever] = @"Never",
    [LPImageUpdateDuration3Hours] = @"3 Hours",
    [LPImageUpdateDuration12Hours] = @"12 Hours",
    [LPImageUpdateDuration24Hours] = @"24 Hours",
    [LPImageUpdateDurationWeek] = @"Week",
    [LPImageUpdateDuration2Weeks] = @"2 Weeks",
    [LPImageUpdateDurationMonth] = @"Month"
};

NSString * const Collection_toString[] = {
    [LPUnsplashImageManagerCollectionFeatured] = @"Featured",
    [LPUnsplashImageManagerCollectionAll] = @"All"
};

NSString *const UnsplashImageOrientation_toString[] = {
    [LPUnsplashImageLandscape] = @"Landscape",
    [LPUnsplashImagePortrait] = @"Portrait",
    [LPUnsplashImageLandscapeOrPortrait] = @"Landscape or Portrait"
};