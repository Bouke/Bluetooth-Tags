//
//  WAAppDelegate.h
//  BluetoothTags
//
//  Created by Bouke Haarsma on 26-01-14.
//  Copyright (c) 2014 Bouke Haarsma. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOBluetooth/IOBluetooth.h>

@interface WAAppDelegate : NSObject <NSApplicationDelegate, CBCentralManagerDelegate, NSTableViewDataSource, CBPeripheralDelegate>
{
    CBCentralManager *manager;
    NSMutableDictionary *devices;
    NSFileHandle *logFileHandle;
}

@property (assign) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (strong) IBOutlet NSTextField *statusText;
@property (strong) IBOutlet NSTableView *devicesTable;
@end
