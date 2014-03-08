

#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreWLAN/CoreWLAN.h>

#define NOTIFY_MTU      99


@implementation AppDelegate


@synthesize connected;

@synthesize manufacturer;
@synthesize peripherals;
@synthesize proxima;
@synthesize statusConnection;
@synthesize connectButton;
@synthesize initiateTimer;

static NSString * const XXServiceType = @"proxima-service";

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //initially the 'connect' button is disabled because we are going to try to connect automatically first
    [connectButton setEnabled:FALSE];
    
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    //if there is a current peripheral connected, we are going to disconnect it and then try to reconnect , for now we are just doing this to ensure that every time we run the app its a new connection, nothing funny going on
    if(self.proxima)
    {
        [manager cancelPeripheralConnection:self.proxima];
    }
    isConnectedToProximaWifi = FALSE;
    //now that the existing peripheral has been cancelled, we will start a timer that continuously scans for the device, once the device has been found, the timer stops and is invalidated
    self.initiateTimer=[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(startScan) userInfo:nil repeats:YES];
    
    
    
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
    if(self.proxima)
    {
        [manager cancelPeripheralConnection:self.proxima];
    }
}


#pragma mark - Network Protocols
-(NSString*)runCommand:(NSString*)commandToRun
{
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/sh"];
    
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-c" ,
                          [NSString stringWithFormat:@"%@", commandToRun],
                          nil];
    NSLog(@"run command: %@",commandToRun);
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *output;
    output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    return output;
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
        [rssiTimer invalidate];
        rssiTimer = nil;
        [manager cancelPeripheralConnection:self.proxima];
    }
}



/*
 Invoked when the central discovers heart rate peripheral while scanning.
 */
- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    //if the peripheral has a name -- My Arduino 71:C6:86 then we are going to connect to it.
    
    //the manager found a device, we will stop and invalidate the timer
 
        NSLog(@"aperiph--%@", aPeripheral.name);
    NSLog(@"rssi -- %d",[RSSI intValue]);
    
    
    if(aPeripheral && [aPeripheral.name rangeOfString:@"My Arduino" ].location!=NSNotFound && [RSSI intValue] > -60)
    {
     
        [manager connectPeripheral:aPeripheral options:nil];
        
        //have to set the current peripheral to a strong variable so that it is retained and doesn't get dealloced while it is being connected
        [self.proxima setDelegate:self];
        self.proxima=aPeripheral;
        
        
        [self.initiateTimer invalidate];
        self.initiateTimer=nil;
        return;
      
    }
    
    if(!self.initiateTimer)
    {
    
      self.initiateTimer=[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(startScan) userInfo:nil repeats:YES];
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
    
    
    /* If there are any known devices, automatically connect to it.*/
    if([p count] >=1)
    {
        
        [manager connectPeripheral:self.proxima options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    }
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber  numberWithBool:YES], CBCentralManagerScanOptionAllowDuplicatesKey, nil];
    [manager scanForPeripheralsWithServices:nil options:options];
}

/*
 Invoked whenever a connection is succesfully created with the peripheral.
 Discover available services on the peripheral
 */
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    [manager stopScan];
    //once the peripheral has been connected, we update the feedbac, label, enable the connect button and change its label to 'disconnect'
    [aPeripheral setDelegate:self];
   
	[statusConnection setStringValue:@"Connected"];
    [connectButton setEnabled:true];
    [connectButton setTitle:@"Disconnect"];
    [aPeripheral discoverServices:nil];

    // add some characteristics, also identified by your own custom UUIDs.
    [self sendData];
    
    self.rssiTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkRssi) userInfo:nil repeats:YES];
    
  }

-(void) checkService
{
    [manager scanForPeripheralsWithServices:nil options:nil];
}

- (void) checkRssi
{
  [self.proxima readRSSI];
}


- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
   NSLog(@"rssi -- %@", peripheral.RSSI);

    if([peripheral.RSSI intValue] < -60)
    {
        [manager cancelPeripheralConnection:self.proxima];
        [self.rssiTimer invalidate];
        self.rssiTimer = nil;
       
    }
}

/*
 Invoked whenever an existing connection with the peripheral is torn down.
 Reset local variables
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
  
    
	[statusConnection setStringValue:@"Disconnected"];
    [connectButton setTitle:@"Connect"];
    if( self.proxima)
    {
        [self.proxima setDelegate:nil];
        self.proxima = nil;
    }

    
     self.initiateTimer=[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(startScan) userInfo:nil repeats:YES];
    
}

/*
 Invoked whenever the central manager fails to create a connection with the peripheral.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    if( self.proxima )
    {
        [self.proxima setDelegate:nil];
        self.proxima = nil;
    }
}


#pragma mark - sending files
- (void)sendData {
    

    CWInterface *wif = [CWInterface interface];
    
   if([wif.ssid rangeOfString:@"Proxima"].location==NSNotFound)
   {
    [self runCommand:@"networksetup -setairportnetwork en0 Proxima anson"];
   }
    [self runScriptToMount];
    
    
}

- (void)runScriptToMount
{
  
        [self runCommand:@"/opt/local/bin/sshfs Anson@Drs-MacBook-Air.local:/Proxima ~/mount"];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(runScriptTocCopy) userInfo:nil repeats:NO];
        
}

- (void)runScriptTocCopy
{
    if(!fileManager)
    {
        fileManager=[NSFileManager defaultManager];
    }
    NSString *userFacingDir=[@"~/ProximaRecvd" stringByStandardizingPath];
    NSError *error;
    if(![fileManager fileExistsAtPath:userFacingDir])
    {
        [fileManager createDirectoryAtPath:userFacingDir withIntermediateDirectories:FALSE attributes:nil error:&error];
    }
    NSString *mountedDir=[@"~/mount" stringByStandardizingPath];
    NSArray *mountedContents = [fileManager contentsOfDirectoryAtPath:mountedDir error:&error];
    BOOL isDirectory;
    NSString *pathToTransfer;
    
        
        for(NSString *file in mountedContents)
        {
            BOOL fileExistsAtPath = [[NSFileManager defaultManager] fileExistsAtPath:[mountedDir stringByAppendingPathComponent:file]  isDirectory:&isDirectory];
          
            if([file rangeOfString:@"com.apple"].location==NSNotFound && [file rangeOfString:@".DS"].location==NSNotFound  &&  !isDirectory)
            {
                pathToTransfer=file;
                NSString *command =[NSString stringWithFormat:@"mkdir ~/ProximaRecvd | cp ~/mount/%@ ~/ProximaRecvd",pathToTransfer];
                [self runCommand:command];
                return;
            }
        }
        
    
    
        NSURL* scriptURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:@"filepathofactive" ofType:@"scpt"]];
        NSURL* url = scriptURL;NSDictionary* errors = [NSDictionary dictionary];
        
        NSAppleScript* appleScript = [[NSAppleScript alloc] initWithContentsOfURL:url error:&errors];
        [appleScript executeAndReturnError:nil];
        
        NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
        NSString* filePathOfActive = [myPasteboard  stringForType:NSPasteboardTypeString];
        NSLog(@"filepath = %@",filePathOfActive);
        NSString *command =[NSString stringWithFormat:@"cp %@ ~/mount/",filePathOfActive];
        [self runCommand:command];
        return;

    
}
- (NSString *)stringToHex:(NSString *)string
{
    const char *utf8 = [string UTF8String];
    NSMutableString *hex = [NSMutableString string];
    while ( *utf8 ) [hex appendFormat:@"%02X" , *utf8++ & 0x00FF];
    
    return [NSString stringWithFormat:@"%@", hex];
}

- (NSData *)dataFromHexString:(NSString *)string {
    string = [string lowercaseString];
    NSMutableData *data= [NSMutableData new];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i = 0;
    int length = (int)string.length;
    while (i < length-1) {
        char c = [string characterAtIndex:i++];
        if (c < '0' || (c > '9' && c < 'a') || c > 'f')
            continue;
        byte_chars[0] = c;
        byte_chars[1] = [string characterAtIndex:i++];
        whole_byte = strtol(byte_chars, NULL, 16);
        [data appendBytes:&whole_byte length:1];
        
    }
    
    return data;
    
}

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
        NSLog(@"ERROR BITCH %@", error);
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
        }else if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }else if ( [aService.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }else{
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
        
//        if([aService.UUID isEqual:[CBUUID UUIDWithString:@"195ae58a 437a489b b0cdb7c9 c394bae4"]])
//        {
//            NSLog(@"yay");
//        }
        /* GAP (Generic Access Profile) for Device Name */
        
    }
}

/*
 Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 Perform appropriate operations on interested characteristics
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{

    
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
    }else if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
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
    }else{
        for (CBCharacteristic *aChar in service.characteristics)
        {
            if([service.characteristics indexOfObject:aChar]==0)
            {
            transferCharacteristic=(CBMutableCharacteristic*)aChar;
                
                [self.proxima setNotifyValue:TRUE forCharacteristic:aChar];
                
                [self.proxima readValueForCharacteristic:aChar];
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
    NSLog(@"char -- %@",characteristic.UUID);
    NSLog(@"value -- %@",characteristic.value);
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
    else{
    }
}

@end
