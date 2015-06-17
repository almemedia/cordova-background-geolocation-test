////
//  CDVBackgroundGeolocation
//
//  Created by Chris Scott <chris@transistorsoft.com> on 2013-06-15
//
#import "CDVBackgroundGeolocation.h"

@implementation CDVBackgroundGeolocation {
    TSLocationManager *bgGeo;
    NSDictionary *config;
}

@synthesize syncCallbackId, syncTaskId, locationCallbackId, geofenceListeners, stationaryRegionListeners;

- (void)pluginInitialize
{
    bgGeo = [[TSLocationManager alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLocationChanged:) name:@"TSLocationManager.location" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStationaryLocation:) name:@"TSLocationManager.stationary" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onEnterGeofence:) name:@"TSLocationManager.geofence" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSyncComplete:) name:@"TSLocationManager.sync" object:nil];
}

/**
 * configure plugin
 * @param {String} token
 * @param {String} url
 * @param {Number} stationaryRadius
 * @param {Number} distanceFilter
 */
- (void) configure:(CDVInvokedUrlCommand*)command
{
    self.locationCallbackId = command.callbackId;
    
    config = [command.arguments objectAtIndex:0];

    [bgGeo configure:config];
}

- (void) setConfig:(CDVInvokedUrlCommand*)command
{
    NSDictionary *cfg  = [command.arguments objectAtIndex:0];
    [bgGeo setConfig:cfg];
    
    CDVPluginResult* result = nil;
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/**
 * Turn on background geolocation
 */
- (void) start:(CDVInvokedUrlCommand*)command
{
    [bgGeo start];
}
/**
 * Turn it off
 */
- (void) stop:(CDVInvokedUrlCommand*)command
{
    [bgGeo stop];
}
- (void) getOdometer:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble: bgGeo.odometer];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}
- (void) resetOdometer:(CDVInvokedUrlCommand*)command
{
    bgGeo.odometer = 0;
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/**
 * Change pace to moving/stopped
 * @param {Boolean} isMoving
 */
- (void) onPaceChange:(CDVInvokedUrlCommand *)command
{
    BOOL moving = [[command.arguments objectAtIndex: 0] boolValue];
    [bgGeo onPaceChange:moving];
}

/**
 * location handler from BackgroundGeolocation
 */
- (void)onLocationChanged:(NSNotification*)notification {
    CLLocation *location = [notification.userInfo objectForKey:@"location"];
    
    NSDictionary *params = @{
        @"location": [bgGeo locationToDictionary:location],
        @"taskId": @([bgGeo createBackgroundTask])
    };
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
    [result setKeepCallbackAsBool:YES];

    [self.commandDelegate runInBackground:^{
        [self.commandDelegate sendPluginResult:result callbackId:self.locationCallbackId];
    }];
}

- (void) onStationaryLocation:(NSNotification*)notification
{
    if (![self.stationaryRegionListeners count]) {
        return;
    }
    CLLocation *location = [notification.userInfo objectForKey:@"location"];   
    NSDictionary *locationData = [bgGeo locationToDictionary:location];

    for (NSString *callbackId in self.stationaryRegionListeners) {
        NSDictionary *params = @{
            @"location": locationData,
            @"taskId": @([bgGeo createBackgroundTask])
        };
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate runInBackground:^{
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        }];
        
    }
}

- (void) onEnterGeofence:(NSNotification*)notification
{
    if (![self.geofenceListeners count]) {
        return;
    }
    NSLog(@"- onEnterGeofence: %@", notification.userInfo);
    
    CLCircularRegion *region = [notification.userInfo objectForKey:@"geofence"];

    for (NSString *callbackId in self.geofenceListeners) {
        NSDictionary *params = @{
            @"identifier": region.identifier,
            @"action": [notification.userInfo objectForKey:@"action"],
            @"taskId": @([bgGeo createBackgroundTask])
        };
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate runInBackground:^{
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        }];       
    }
}

- (void) onSyncComplete:(NSNotification*)notification
{
    NSDictionary *params = @{
        @"locations": [notification.userInfo objectForKey:@"locations"],
        @"taskId": @(syncTaskId)
    };
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
    [self.commandDelegate sendPluginResult:result callbackId:syncCallbackId];
    
    // Ready for another sync task.
    syncCallbackId  = nil;
    syncTaskId      = UIBackgroundTaskInvalid;
}

/**
 * Fetches current stationaryLocation
 */
- (void) getStationaryLocation:(CDVInvokedUrlCommand *)command
{
    NSDictionary* location = [bgGeo getStationaryLocation];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:location];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/**
 * Fetches current stationaryLocation
 */
- (void) getLocations:(CDVInvokedUrlCommand *)command
{   
    NSDictionary *params = @{
        @"locations": [bgGeo getLocations],
        @"taskId": @([bgGeo createBackgroundTask])
    };
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:params];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/**
 * Fetches current stationaryLocation
 */
- (void) sync:(CDVInvokedUrlCommand *)command
{
    if (syncCallbackId != nil) {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A sync action is already in progress."];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    // Important to set these before we execute #sync since this fires a *very fast* async NSNotification event!
    syncCallbackId  = command.callbackId;
    syncTaskId      = [bgGeo createBackgroundTask];

    NSArray* locations = [bgGeo sync];
    if (locations == nil) {
        syncCallbackId  = nil;
        syncTaskId      = UIBackgroundTaskInvalid;
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Sync failed.  Is there a network connection?"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void) addStationaryRegionListener:(CDVInvokedUrlCommand*)command
{
    if (self.stationaryRegionListeners == nil) {
        self.stationaryRegionListeners = [[NSMutableArray alloc] init];
    }
    [self.stationaryRegionListeners addObject:command.callbackId];
}

- (void) addGeofence:(CDVInvokedUrlCommand*)command
{
    NSDictionary *cfg  = [command.arguments objectAtIndex:0];
    NSString *notifyOnExit = [cfg objectForKey:@"notifyOnExit"];
    NSString *notifyOnEntry = [cfg objectForKey:@"notifyOnEntry"];

    [bgGeo addGeofence:[cfg objectForKey:@"identifier"] 
        radius:[[cfg objectForKey:@"radius"] doubleValue] 
        latitude:[[cfg objectForKey:@"latitude"] doubleValue] 
        longitude:[[cfg objectForKey:@"longitude"] doubleValue]
        notifyOnEntry: (notifyOnEntry) ? [notifyOnEntry boolValue] : NO
        notifyOnExit: (notifyOnExit) ? [notifyOnExit boolValue] : NO
    ];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void) removeGeofence:(CDVInvokedUrlCommand*)command
{
    NSString *identifier  = [command.arguments objectAtIndex:0];
    CDVPluginResult *result;
    if ([bgGeo removeGeofence:identifier]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed to locate geofence"];
    }
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void) getGeofences:(CDVInvokedUrlCommand*)command
{
    NSMutableArray *rs = [[NSMutableArray alloc] init];
    for (CLRegion *geofence in [bgGeo getGeofences]) {
        [rs addObject:@{
            @"identifier":geofence.identifier,
            @"radius": @(geofence.radius),
            @"latitude": @(geofence.center.latitude),
            @"longitude": @(geofence.center.longitude)
        }];
    }
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:rs];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}


- (void) onGeofence:(CDVInvokedUrlCommand*)command
{
    if (self.geofenceListeners == nil) {
        self.geofenceListeners = [[NSMutableArray alloc] init];
    }
    [self.geofenceListeners addObject:command.callbackId];
}

- (void) playSound:(CDVInvokedUrlCommand*)command
{
    int soundId = [[command.arguments objectAtIndex:0] integerValue];
    [bgGeo playSound: soundId];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/**
 * Called by js to signify the end of a background-geolocation event
 */
-(void) finish:(CDVInvokedUrlCommand*)command
{
    UIBackgroundTaskIdentifier taskId = [[command.arguments objectAtIndex: 0] integerValue];
    [bgGeo stopBackgroundTask:taskId];
}

/**
 * Called by js to signal a caught exception from application code.
 */
-(void) error:(CDVInvokedUrlCommand*)command
{
    UIBackgroundTaskIdentifier taskId = [[command.arguments objectAtIndex: 0] integerValue];
    NSString *error = [command.arguments objectAtIndex:1];
    [bgGeo error:taskId message:error];
    
}
/**
 * If you don't stopMonitoring when application terminates, the app will be awoken still when a
 * new location arrives, essentially monitoring the user's location even when they've killed the app.
 * Might be desirable in certain apps.
 */
- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
