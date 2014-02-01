

#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>

@implementation AppDelegate


@synthesize connected;
@synthesize manufacturer;
@synthesize peripherals;
@synthesize peripheral;
@synthesize statusConnection;
@synthesize connectButton;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{

    [connectButton setEnabled:FALSE];
    
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    if(self.peripheral)
    {
    [manager cancelPeripheralConnection:self.peripheral];
    }
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
    [initiateTimer invalidate];
    initiateTimer=nil;
    if(!self.peripherals)
    {
    self.peripherals = [[NSMutableArray alloc] init];
    }
    if(aPeripheral && [aPeripheral.name isEqualToString:@"My Arduino 71:C6:86"])
    {
    [manager connectPeripheral:aPeripheral options:nil];
        self.peripheral=aPeripheral;

    }
    /* Retreive already known devices */
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
    [aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
	[statusConnection setStringValue:@"Connected"];
    [connectButton setEnabled:true];
    [connectButton setTitle:@"Disconnect"];
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
    if( peripheral )
    {
        [peripheral setDelegate:nil];
        peripheral = nil;
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

#pragma mark - CBPeripheral delegate methods
/*
 Invoked upon completion of a -[discoverServices:] request.
 Discover available characteristics on interested services
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
