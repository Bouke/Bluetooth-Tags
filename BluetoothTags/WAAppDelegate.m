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

    [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(updateDevices) userInfo:nil repeats:YES];

    // There should be a better way, but this will do for now.
    NSString *logPath = [[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iBeacon Log.csv"];
    [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [logFileHandle truncateFileAtOffset:0];
    [logFileHandle writeData:[@"UUID,Major,Minor,RSSI\n" dataUsingEncoding:NSASCIIStringEncoding]];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [logFileHandle closeFile];
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)updateDevices
{
    NSDictionary *strongestDevice;
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:-30];
    for (NSData *key in [devices keyEnumerator]) {
        NSDictionary *device = [devices objectForKey:key];
        if([timeout compare:[device objectForKey:@"last_seen"]] == NSOrderedDescending) {
            NSLog(@"Removing... %@ < %@", [device objectForKey:@"last_seen"], timeout);
            [devices removeObjectForKey:key];
            continue;
        }
        if([device objectForKey:@"rssi"] > [strongestDevice objectForKey:@"rssi"]) {
            strongestDevice = device;
        }
    }

    NSLog(@"Strongest peripheral: %@", [strongestDevice objectForKey:@"name"]);
    [self.devicesTable reloadData];
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
    [manager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];

    [self.progressIndicator startAnimation:nil];
    [self.progressIndicator setHidden:FALSE];
    [self.statusText setHidden:FALSE];
}

- (void) stopScan
{
    [manager stopScan];
    [self.progressIndicator setHidden:TRUE];
    [self.statusText setHidden:TRUE];
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
    NSData *data = [advertisementData valueForKey:CBAdvertisementDataManufacturerDataKey];
    if(!data) {
        return;  // not an iBeacon
    }

    unsigned char manufacturerData[21] = {0};
    [data getBytes:&manufacturerData range:NSMakeRange(4, 21)];
    NSUUID *uuid = [[NSUUID alloc]initWithUUIDBytes:manufacturerData];

    NSNumber *major = @((manufacturerData[16] << 8) + (manufacturerData[17] & 255));
    NSNumber *minor = @((manufacturerData[18] << 8) + (manufacturerData[19] & 255));

    NSString *name = peripheral.name;
    if(!name) {
        name = @"N/A";
    }

    NSString *logLine = [NSString stringWithFormat:@"%@,%@,%@,%@\n", [uuid UUIDString], [major stringValue], [minor stringValue], [RSSI stringValue]];
    [logFileHandle writeData:[logLine dataUsingEncoding:NSASCIIStringEncoding]];

    [devices setObject: @{
                          @"uuid": [uuid UUIDString],
                          @"name": name,
                          @"major": major,
                          @"minor": minor,
                          @"rssi": RSSI,
                          @"last_seen": [NSDate date],
                          @"peripheral": peripheral,
                          }
                forKey:advertisementData];
    [self updateDevices];

    [peripheral setDelegate:self];
    // If connected, we'll not receive new readings from the device.
    // @todo can we do without?
//    if(peripheral.state != CBPeripheralStateConnected) {
//        [manager connectPeripheral:peripheral options:nil];
//    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [peripheral discoverServices:@[[CBUUID UUIDWithString:@"180a"]]];
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for(CBService *service in peripheral.services) {
        if([service.UUID isEqual:[CBUUID UUIDWithString:@"180a"]]) {
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"2a29"]] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if([service.UUID isEqual:[CBUUID UUIDWithString:@"180a"]]) {
        for(CBCharacteristic *characteristic in service.characteristics) {
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2a29"]]) {
                [peripheral readValueForCharacteristic:characteristic];
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%@: %@", characteristic.UUID, [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding]);
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
