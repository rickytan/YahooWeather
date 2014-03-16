//
//  YHWeather.m
//  DreamLand
//
//  Created by ricky on 14-2-28.
//  Copyright (c) 2014年 ricky. All rights reserved.
//

#import "YHWeather.h"

#define YAHOO_GEO_API       @"http://query.yahooapis.com/v1/public/yql"
#define YAHOO_WEATHER_API   @"http://weather.yahooapis.com/forecastrss"

#if __has_feature(objc_arc)
#error "This is Non-ARC file!"
#endif

@implementation Weather

- (void)dealloc
{
    self.city = nil;
    self.country = nil;
    self.forecasts = nil;
    self.currentCondition = nil;
    self.timeStamp = nil;
    [super dealloc];
}

@end

@interface YHWeather () <CLLocationManagerDelegate, NSXMLParserDelegate>
@property (nonatomic, copy) CompleteBlock callback;
@property (nonatomic, retain) NSString *woeid;
@property (nonatomic, retain) Weather *weather;
@property (nonatomic, retain) NSError *error;

@property (nonatomic, retain) NSString *xmlValue;
@property (nonatomic, retain) NSMutableArray *forecasts;
@property (nonatomic, assign) BOOL shouldStore;
@end

@implementation YHWeather

- (void)dealloc
{
    self.weather  = nil;
    self.woeid    = nil;
    self.callback = nil;
    self.delegate = nil;
    [super dealloc];
}

- (Weather *)weather
{
    if (!_weather) {
        _weather = [[Weather alloc] init];
    }
    return _weather;
}

- (NSMutableArray *)forecasts
{
    if (!_forecasts) {
        _forecasts = [[NSMutableArray alloc] initWithCapacity:5];
    }
    return _forecasts;
}

- (void)parseGEOData:(NSData *)data
{
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    if ([parser parse]) {
        self.state = YHWeatherStateLocated;
        [self getWeather:self.woeid];
    }
    else {
        self.error = parser.parserError;
        self.state = YHWeatherStateError;
    }
    [parser release];
}

- (void)parseWeatherData:(NSData *)data
{
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    if ([parser parse]) {
        self.state = YHWeatherStateFinished;
    }
    else {
        self.error = parser.parserError;
        self.state = YHWeatherStateError;
    }
    [parser release];
}

- (void)getWoeid:(CLLocation *)location
{
    static NSInteger retriedTimes = 0;

    NSString *query = [NSString stringWithFormat:@"select * from geo.placefinder where text=\"%.6f,%.6f\" and gflags = \"R\"", location.coordinate.latitude, location.coordinate.longitude];
    NSString *urlStr = [NSString stringWithFormat:@"%@?q=%@", YAHOO_GEO_API, query];
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (!data) {
                                   if (retriedTimes++ < 3) {
                                       [self performSelector:@selector(getWoeid:)
                                                  withObject:location
                                                  afterDelay:5.0];
                                   }
                                   else {
                                       self.error = connectionError;
                                       self.state = YHWeatherStateError;
                                   }
                               }
                               else {
                                   retriedTimes = 0;
                                   [self parseGEOData:data];
                               }
                           }];
}

- (void)getLocation
{
    if ([CLLocationManager locationServicesEnabled] &&
        [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied) {
        CLLocationManager *manager = [[CLLocationManager alloc] init];
        manager.delegate = self;
        [manager startUpdatingLocation];
        self.state = YHWeatherStateLocating;
    }
}

- (void)getWeather:(NSString *)woeid
{
    static NSInteger retriedTimes = 0;

    __block typeof(self) weakSelf = self;
    NSString *urlStr = [NSString stringWithFormat:@"%@?w=%@", YAHOO_WEATHER_API, woeid];
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (!data) {
                                   if (retriedTimes++ < 3) {
                                       [weakSelf performSelector:@selector(getWeather:)
                                                      withObject:woeid
                                                      afterDelay:5.0];
                                   }
                                   else {
                                       weakSelf.error = connectionError;
                                       weakSelf.state = YHWeatherStateError;
                                   }
                               }
                               else {
                                   retriedTimes = 0;
                                   [weakSelf parseWeatherData:data];
                               }
                           }];

    self.state = YHWeatherStateQueryWeatherInfo;
}

- (void)setState:(YHWeatherState)state
{
    if (_state != state) {
        _state = state;
        if ([self.delegate respondsToSelector:@selector(weatherStateDidChanged:)])
            [self.delegate performSelector:@selector(weatherStateDidChanged:)
                                withObject:self];
        if (_state == YHWeatherStateError ||
            _state == YHWeatherStateFinished) {
            if (self.callback) {
                self.callback(self.weather, self.error);
                self.callback = nil;
            }
        }
    }
}

- (void)weatherForCurrentLocationWithCompleteBlock:(CompleteBlock)block
{
    self.callback = block;
    [self getLocation];
}

- (void)weatherForWoeid:(NSString *)woeid
      withCompleteBlock:(CompleteBlock)block
{
    self.woeid = woeid;
    [self getWeather:woeid];
}

- (void)weatherForLocation:(CLLocation *)location
         withCompleteBlock:(CompleteBlock)block
{
    self.callback = block;
    [self getWoeid:location];
}

#pragma mark - CLLocation Delegate

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    [manager stopUpdatingLocation];
    manager.delegate = nil;
    [manager release];

    [self getWoeid:newLocation];
}

#pragma mark - NSXML Delegate


// Document handling methods
- (void)parserDidStartDocument:(NSXMLParser *)parser
{

}

// sent when the parser begins parsing of the document.
- (void)parserDidEndDocument:(NSXMLParser *)parser
{

}

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict
{
    self.shouldStore = NO;
    if ([elementName isEqualToString:@"city"]) {
        self.shouldStore = YES;
    }
    else if ([elementName isEqualToString:@"country"]) {
        self.shouldStore = YES;
    }
    else if ([elementName isEqualToString:@"woeid"]) {
        self.shouldStore = YES;
    }
    else if ([elementName isEqualToString:@"pubDate"]) {
        self.shouldStore = YES;
    }
    else if ([elementName isEqualToString:@"yweather:condition"]) {
        self.weather.currentCondition = attributeDict;
    }
    else if ([elementName isEqualToString:@"yweather:forecast"]) {
        [self.forecasts addObject:attributeDict];
    }
}

- (void)parser:(NSXMLParser *)parser
foundCharacters:(NSString *)string
{
    if (self.shouldStore)
        self.xmlValue = string;
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"city"]) {
        self.weather.city = self.xmlValue;
    }
    else if ([elementName isEqualToString:@"country"]) {
        self.weather.country = self.xmlValue;
    }
    else if ([elementName isEqualToString:@"woeid"]) {
        self.woeid = self.xmlValue;
    }
    else if ([elementName isEqualToString:@"pubDate"]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterFullStyle;
        self.weather.timeStamp = [formatter dateFromString:self.xmlValue];
        [formatter release];
    }
    else if ([elementName isEqualToString:@"yweather:forecast"]) {
        self.weather.forecasts = [NSArray arrayWithArray:self.forecasts];
        self.forecasts = nil;
    }

    self.xmlValue = nil;
}

- (void)parser:(NSXMLParser *)parser
    foundCDATA:(NSData *)CDATABlock
{
    
}

@end
