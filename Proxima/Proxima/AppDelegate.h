//
//  AppDelegate.h
//  Proxima
//
//  Created by Sukhwinder Lall on 1/31/2014.
//  Copyright (c) 2014 Sukhwinder Lall. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOBluetooth/IOBluetooth.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>
{
    
    CBCentralManager *manager;
    CBPeripheral *peripheral;
    NSMutableArray *peripherals;
    NSString *manufacturer;
    
    BOOL autoConnect;
    NSTimer *initiateTimer;
    
    IBOutlet NSTextField *statusConnection;
    IBOutlet NSButton *connectButton;


}


@property (strong)CBPeripheral *peripheral;
@property (nonatomic,strong)  NSMutableArray *peripherals;
@property (nonatomic,strong) NSString *manufacturer;
@property (copy) NSString *connected;

- (IBAction)connectButtonSelected:(id)sender;
- (void) startScan;
- (void) stopScan;
- (BOOL) isLECapableHardware;


@property (strong) IBOutlet NSButton *connectButton;

@property (strong) IBOutlet NSTextField *statusConnection;
@end
