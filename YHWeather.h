//
//  YHWeather.h
//  DreamLand
//
//  Created by ricky on 14-2-28.
//  Copyright (c) 2014年 ricky. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface Weather : NSObject
@property (nonatomic, retain) NSString     *city;
@property (nonatomic, retain) NSString     *country;
@property (nonatomic, retain) NSArray      *forecasts;
@property (nonatomic, retain) NSDictionary *currentCondition;
@property (nonatomic, retain) NSDate       *timeStamp;
@end

typedef void(^CompleteBlock)(id data, NSError *error);

typedef enum {
    YHWeatherStateNone              = 0,
    YHWeatherStateError,
    YHWeatherStateLocating,
    YHWeatherStateLocated,
    YHWeatherStateQueryWeatherInfo,
    YHWeatherStateFinished
} YHWeatherState;

@class YHWeather;
@protocol YHWeatherDelegate <NSObject>

- (void)weatherStateDidChanged:(YHWeather*)weather;

@end

@interface YHWeather : NSObject
@property (nonatomic, assign) id<YHWeatherDelegate> delegate;
@property (nonatomic, assign) YHWeatherState state;
@property (nonatomic, readonly) Weather *weather;
@property (nonatomic, readonly) NSError *error;

- (void)weatherForLocation:(CLLocation *)location
         withCompleteBlock:(CompleteBlock)block;
- (void)weatherForWoeid:(NSString *)woeid
      withCompleteBlock:(CompleteBlock)block;
- (void)weatherForCurrentLocationWithCompleteBlock:(CompleteBlock)block;

@end
