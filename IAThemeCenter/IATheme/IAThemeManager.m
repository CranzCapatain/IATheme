//
//  IAThemeManager.m
//  IAThemeCenter
//
//  Created by 金峰 on 2018/4/15.
//  Copyright © 2018年 IA.Alter.com. All rights reserved.
//

#import "IAThemeManager.h"
#import "IAThemeHelper.h"
#import "IAThemeDefines.h"
#import "IAThemeFileHandler.h"
#import <UIKit/UIImage.h>

@interface IAThemeManager ()
@property (nonatomic, strong, readwrite) IATheme *theme;
@property (nonatomic, strong) IAThemeFileHandler *fileHandler;
@property (nonatomic, strong) NSMapTable *resultCallbackMap;
@end

@implementation IAThemeManager

+ (IAThemeManager *)sharedManager {
    static IAThemeManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[IAThemeManager alloc] init];
        [instance initWithConfig];
    });
    return instance;
}

- (void)initWithConfig {
    self.fileHandler = [[IAThemeFileHandler alloc] init];
    self.resultCallbackMap = [NSMapTable strongToStrongObjectsMapTable];
}

- (void)loadTheme {
    if (![[NSFileManager defaultManager] fileExistsAtPath:[IAThemeFileHandler pathOfLocalTheme]]) {
        // 第一次配置主题,读取默认配置
        if (self.fileHandler.isUserDefaultThemeSetting) {
            [self switchSystemTheme];
        } else {
            NSLog(@"请先配置 ‘IAThemeDefines.h’");
        }
    } else {
        self.theme = [self.fileHandler localTheme];
    }
}

- (IATheme *)themeWithKey:(NSString *)key {
    NSDictionary *themeDic = self.fileHandler.configDic[key];
    IATheme *theme = [[IATheme alloc] init];
    theme.themeKey = key;
    theme.themeName = themeDic[kThemeName];
    theme.themeColor = themeDic[kThemeColor];
    theme.currentBundle = themeDic[kImageBundle];
    return theme;
}

- (IAThemeLoadResult *)resultWithPredicate:(IAThemePredicate *)predicate {
    if ((predicate.key == IAKeyCustom && predicate.keyValue.length == 0) || !predicate) {
        return nil;
    }
    IAThemeLoadResult *result = [[IAThemeLoadResult alloc] init];
    result.sourceType = predicate.sourceType;
    
    NSDictionary *themeDic = self.fileHandler.configDic[self.theme.themeKey];
    switch (predicate.sourceType) {
        case IASourceTypeColor:
        {
            NSString *themeColor;
            if (predicate.key == IAKeyDefault) {
                themeColor = themeDic[kThemeColor];
            } else {
                themeColor = themeDic[predicate.keyValue];
            }
            result.color = [IAThemeHelper colorWithThemeColor:themeColor];
        }
            break;
        case IASourceTypeImage:
        {
            NSString *imageName;
            NSString *imageValue = themeDic[predicate.keyValue];
            if (imageValue.length == 0 || imageValue == nil) {
                imageName = [self.fileHandler imageNamed:predicate.keyValue];
                predicate.key = IAKeyCustom;
            } else {
                imageName = [self.fileHandler imageNamed:imageValue];
                predicate.key = IAKeyDefault;
            }
            result.image = [UIImage imageNamed:imageName];
        }
            break;
        case IASourceTypeUnknown:
        {
            // unknown
        }
            break;
        default:
            break;
    }
    
    return result;
}

- (void)loadResourceWithPredicate:(IAThemePredicate *)predicate load:(IALoadComplication)complication {
    IAThemeLoadResult *result = [self resultWithPredicate:predicate];
    if (complication) {
        for (IAThemePredicate *filter in self.resultCallbackMap.objectEnumerator) {
            if ([filter.filter isEqual:predicate.filter]) {
                return;
            }
        }
        complication(result, result ? YES : NO);
        [self.resultCallbackMap setObject:predicate forKey:complication];
    }
}

- (void)switchThemeWithKey:(NSString *)key {
    self.theme = [self themeWithKey:key];
    [self.fileHandler saveTheme:self.theme];

    for (IALoadComplication complicaiton in self.resultCallbackMap.keyEnumerator) {
        if (!complicaiton) continue;
        
        IAThemePredicate *predicate = [self.resultCallbackMap objectForKey:complicaiton];
        IAThemeLoadResult *result = [self resultWithPredicate:predicate];
        complicaiton(result, result ? YES : NO);
    }
}

- (void)switchSystemTheme {
    [self switchThemeWithKey:defaultThemeKey];
}

- (void)clear {
    [self.fileHandler clearThemeAndInit];
}

@end
