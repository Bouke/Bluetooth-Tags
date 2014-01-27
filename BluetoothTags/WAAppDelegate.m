//
//  WAAppDelegate.m
//  BluetoothTags
//
//  Created by Bouke Haarsma on 26-01-14.
//  Copyright (c) 2014 Bouke Haarsma. All rights reserved.
//

#import "WAAppDelegate.h"

@implementation WAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    devices = [[NSMutableDictionary alloc] init];
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    if([self isLECapableHardware])
    {
        [self startScan];
    }
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)updateDevices
{
    NSDictionary *strongestDevice;
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:-30];
    for (NSDictionary *device in [devices objectEnumerator]) {
        if([timeout compare:[device objectForKey:@"last_seen"]] == NSOrderedDescending) {
            NSLog(@"Removing... %@ < %@", [device objectForKey:@"last_seen"], timeout);
            [devices removeObjectForKey:[device objectForKey:@"uuid"]];
            continue;
        }
        if([device objectForKey:@"rssi"] > [strongestDevice objectForKey:@"rssi"]) {
            strongestDevice = device;
        }
    }

    NSLog(@"Strongest peripheral: %@", [strongestDevice objectForKey:@"name"]);
}

#pragma mark - Start/Stop Scan methods

/*
 Uses CBCentralManager to check whether the current platform/hardware supports Bluetooth LE. An alert is raised if Bluetooth LE is not enabled or is not supported.
 */
- (BOOL) isLECapableHardware
{
    NSString * state = nil;

    switch ([manager state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;

    }

    NSLog(@"Central manager state: %@", state);

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:state];
    [alert addButtonWithTitle:@"OK"];
    [alert setIcon:[[NSImage alloc] initWithContentsOfFile:@"AppIcon"]];
    [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
    return FALSE;
}

- (void) startScan
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], CBCentralManagerScanOptionAllowDuplicatesKey, nil];

    [manager scanForPeripheralsWithServices:nil options:options];

    [self.progressIndicator startAnimation:nil];
    [self.progressIndicator setHidden:FALSE];
    [self.statusText setHidden:FALSE];
}

#pragma mark - CBCentralManager

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if([self isLECapableHardware]) {
        [self startScan];
    }
}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"UUID: %@ - RSSI: %@", peripheral.identifier, RSSI);

    NSString *uuid = peripheral.identifier.UUIDString;
    [devices setObject: @{
                          @"uuid": uuid,
                          @"name": peripheral.name,
                          @"rssi": RSSI,
                          @"last_seen": [NSDate date],
                          }
                forKey:uuid];
    [self updateDevices];
    [self.devicesTable reloadData];
    [self.devicesTable scrollToEndOfDocument:nil];
}

# pragma mark - NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [devices count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary *device = [devices objectForKey:[[devices allKeys] objectAtIndex:row]];
    return [device valueForKey:[tableColumn identifier]];
}

@end
