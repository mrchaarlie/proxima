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
    
    CBCentralManager *manager;   //bluetooth connection manager
    CBPeripheral *peripheral;   //peripheral = bluetooth device thats been detected
    NSMutableArray *peripherals; //an array containing all detected peripherals matching Proxima criteria
    NSString *manufacturer; //the manufacturer of the peripheral
    
    BOOL autoConnect; //boolean value, should the device autoconnect?
    NSTimer *initiateTimer;  //timer is used to continusely check for peripherals until one is found
    
    IBOutlet NSTextField *statusConnection; //feedback to the user as to what the status of the current connection is (disconnected connected, etc)
    IBOutlet NSButton *connectButton; // will allow users to manually connect and disconnect from proxima


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
