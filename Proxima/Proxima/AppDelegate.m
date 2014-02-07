

#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>

#define NOTIFY_MTU      100000


@implementation AppDelegate


@synthesize connected;
@synthesize manufacturer;
@synthesize peripherals;
@synthesize peripheral;
@synthesize statusConnection;
@synthesize connectButton;


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //initially the 'connect' button is disabled because we are going to try to connect automatically first
    [connectButton setEnabled:FALSE];
    
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    //if there is a current peripheral connected, we are going to disconnect it and then try to reconnect , for now we are just doing this to ensure that every time we run the app its a new connection, nothing funny going on
    if(self.peripheral)
    {
        [manager cancelPeripheralConnection:self.peripheral];
    }
    
    //now that the existing peripheral has been cancelled, we will start a timer that continuously scans for the device, once the device has been found, the timer stops and is invalidated
    initiateTimer=[NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(startScan) userInfo:nil repeats:YES];
    
    
}

- (void) dealloc
{
   
 
}

/*
 Disconnect peripheral when application terminate
 */
- (void) applicationWillTerminate:(NSNotification *)notification
{
    //cancel current peripherals when we close the app
    if(peripheral)
    {
        [manager cancelPeripheralConnection:peripheral];
    }
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
      return FALSE;
}




/*
 Request CBCentralManager to scan for heart rate peripherals using service UUID 0x180D
 */
- (void) startScan
{
    //change the text in the feedback label to say connecting, so user knows the scan has started
    NSLog(@"connecting");
    [statusConnection setStringValue:@"Connecting"];
    [manager scanForPeripheralsWithServices:nil options:nil];
}

/*
 Request CBCentralManager to stop scanning for heart rate peripherals
 */
- (void) stopScan
{
    [manager stopScan];
}

#pragma mark - CBCentralManager delegate methods
/*
 Invoked whenever the central manager's state is updated.
 */
- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self isLECapableHardware];
    if(central.state==CBCentralManagerStatePoweredOn)
    {
        //Now do your scanning and retrievals
        [self startScan];
    }
}

- (IBAction)connectButtonSelected:(id)sender
{
    NSButton *b = (NSButton *)sender;
    if([b.title isEqualToString:@"Connect"])
    {
        [self startScan];
    }else{
        [manager cancelPeripheralConnection:self.peripheral];
    }
}



/*
 Invoked when the central discovers heart rate peripheral while scanning.
 */
- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    //the manager found a device, we will stop and invalidate the timer
    [initiateTimer invalidate];
    initiateTimer=nil;
    
    //initialise the peripherals array -- we aren't really using this just yet
    if(!self.peripherals)
    {
        self.peripherals = [[NSMutableArray alloc] init];
    }
    
    //if the peripheral has a name -- My Arduino 71:C6:86 then we are going to connect to it.
//    if(aPeripheral && [aPeripheral.name isEqualToString:@"My Arduino 71:C6:86"])
    
    if(aPeripheral && [aPeripheral.name isEqualToString:@"My Arduino 71:C6:86"])
    {
        [manager connectPeripheral:aPeripheral options:nil];
        
        //have to set the current peripheral to a strong variable so that it is retained and doesn't get dealloced while it is being connected
        [self.peripheral setDelegate:self];
        self.peripheral=aPeripheral;
        
       
    }
    
    
    /* Retreive already known devices */ //--- not really using this right now either
    if(autoConnect)
    {
        [manager retrieveConnectedPeripheralsWithServices:[NSArray arrayWithObject:(id)aPeripheral.identifier]];
    }
}

/*
 Invoked when the central manager retrieves the list of known peripherals.
 Automatically connect to first known peripheral
 */
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)p
{
    NSLog(@"Retrieved peripheral: %lu - %@", [p count], peripherals);
    
    [self stopScan];
    
    /* If there are any known devices, automatically connect to it.*/
    if([p count] >=1)
    {
        
        [manager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    }
}

/*
 Invoked whenever a connection is succesfully created with the peripheral.
 Discover available services on the peripheral
 */
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    
    //once the peripheral has been connected, we update the feedbac, label, enable the connect button and change its label to 'disconnect'
    [aPeripheral setDelegate:self];
   
    
    peripheralManager = [[CBPeripheralManager alloc] init];
	[statusConnection setStringValue:@"Connected"];
    [connectButton setEnabled:true];
    [connectButton setTitle:@"Disconnect"];
    
    NSImage *screenShot= [NSImage imageNamed:@"screen.png"];
    NSData *screenShotData = [self PNGRepresentationOfImage:screenShot] ;
    dataToSend =screenShotData;
    
    
    NSLog(@"connected -- %@",aPeripheral);
	self.connected = @"Connected";
  }

/*
 Invoked whenever an existing connection with the peripheral is torn down.
 Reset local variables
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
	[statusConnection setStringValue:@"Disconnected"];
    [connectButton setTitle:@"Connect"];
    if( self.peripheral )
    {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

/*
 Invoked whenever the central manager fails to create a connection with the peripheral.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    if( peripheral )
    {
        [peripheral setDelegate:nil];
        peripheral = nil;
    }
}


#pragma mark - sending files
- (void)sendData {
    // First up, check if we're meant to be sending an EOM
    static BOOL sendingEOM = NO;
    if(!transferCharacteristic)
    {
 
        transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"E788D73B-E793-4D9E-A608-2F2BAFC59A00"]properties:CBCharacteristicPropertyRead|CBCharacteristicPropertyWrite value:nil permissions:CBAttributePermissionsReadable|CBAttributePermissionsWriteable];
        
    }
    
    if (sendingEOM) {
        
        // send it
       [self.peripheral writeValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:transferCharacteristic type:CBCharacteristicWriteWithResponse];
       
        
            
            // It did, so mark it as sent
            sendingEOM = NO;
            
            NSLog(@"Sent: EOM");
        
        
        // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // We're not sending an EOM, so we're sending data
    
    // Is there any left to send?
    
    if (sendDataIndex >= dataToSend.length) {
        
        // No data left.  Do nothing
        return;
    }
    
    // There's data left, so send until the callback fails, or we're done.
    
    sendDataIndex=0;
    while (sendDataIndex<dataToSend.length) {
        
        // Make the next chunk
        
        // Work out how big it should be
        NSInteger amountToSend = dataToSend.length - sendDataIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU)
        {
            amountToSend = NOTIFY_MTU;
            
        }
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytesNoCopy:(char *)[dataToSend bytes] length:amountToSend freeWhenDone:NO];
        
        NSLog(@"send index -- %ld",(long)sendDataIndex);
        // Send it
        [self.peripheral writeValue:chunk forCharacteristic:transferCharacteristic type:CBCharacteristicWriteWithResponse];
        
        
        // It did send, so update our index
        sendDataIndex += amountToSend;
        
        // Was it the last one?
        if (sendDataIndex >= dataToSend.length) {
            
            // It was - send an EOM
            
            // Set this so if the send fails, we'll send it next time
            sendingEOM = YES;
            
            // Send it
            [self.peripheral writeValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:transferCharacteristic type:CBCharacteristicWriteWithResponse];
            
            
                sendingEOM = NO;
                
                NSLog(@"Sent: EOM");
            
            
            return;
        }
    }}


- (NSData *) PNGRepresentationOfImage:(NSImage *) image {
    // Create a bitmap representation from the current image
    
    [image lockFocus];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, image.size.width, image.size.height)];
    [image unlockFocus];
    
    return [bitmapRep representationUsingType:NSPNGFileType properties:Nil];
}


- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"ERROR BITCH");
        return ;
    }else{
        NSLog(@"SUCCESS BITCH");
    }
}
#pragma mark - CBPeripheral delegate methods
/*
 Invoked upon completion of a -[discoverServices:] request.
 Discover available characteristics on interested services
 
 ####aren't using this just yet, but might be able to use it later when we add the rfid stuff
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
    for (CBService *aService in aPeripheral.services)
    {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        
        /* Heart Rate Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180D"]])
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
        
        /* Device Information Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
        
        /* GAP (Generic Access Profile) for Device Name */
        if ( [aService.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

/*
 Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 Perform appropriate operations on interested characteristics
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
//    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180D"]])
//    {
//        for (CBCharacteristic *aChar in service.characteristics)
//        {
//            /* Set notification on heart rate measurement */
//            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]])
//            {
//                [peripheral setNotifyValue:YES forCharacteristic:aChar];
//                NSLog(@"Found a Heart Rate Measurement Characteristic");
//            }
//            /* Read body sensor location */
//            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]])
//            {
//                [aPeripheral readValueForCharacteristic:aChar];
//                NSLog(@"Found a Body Sensor Location Characteristic");
//            }
//            
//            /* Write heart rate control point */
//            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A39"]])
//            {
//                uint8_t val = 1;
//                NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
//                [aPeripheral writeValue:valData forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
//            }
//        }
//    }
    
    if ( [service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            /* Read device name */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
            {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Device Name Characteristic");
            }
        }
    }
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            /* Read manufacturer name */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]])
            {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Device Manufacturer Name Characteristic");
            }
        }
    }
}

- (IBAction)initiateTransfer:(id)sender
{
    [self sendData];
}
/*
 Invoked upon completion of a -[readValueForCharacteristic:] request or on the reception of a notification/indication.
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    /* Updated value for heart rate measurement received */
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]])
    {
        if( (characteristic.value)  || !error )
        {
            /* Update UI with heart rate data */
        }
    }
    /* Value for body sensor location received */
    else  if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]])
    {
        NSData * updatedValue = characteristic.value;
        uint8_t* dataPointer = (uint8_t*)[updatedValue bytes];
        if(dataPointer)
        {
                  }
    }
    /* Value for device Name received */
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
    {
        NSString * deviceName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"Device Name = %@", deviceName);
    }
    /* Value for manufacturer name received */
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]])
    {
        self.manufacturer = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding] ;
        NSLog(@"Manufacturer Name = %@", self.manufacturer);
    }
}

@end
