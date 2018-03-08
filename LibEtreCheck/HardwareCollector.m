/***********************************************************************
 ** Etresoft
 ** John Daniel
 ** Copyright (c) 2014-2017. All rights reserved.
 **********************************************************************/

#import "HardwareCollector.h"
#import "NSMutableAttributedString+Etresoft.h"
#import "Model.h"
#import "Utilities.h"
#import "NSArray+Etresoft.h"
#import "NSDictionary+Etresoft.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "SubProcess.h"
#import "ByteCountFormatter.h"
#import "XMLBuilder.h"
#import "NumberFormatter.h"
#import "LocalizedString.h"
#import "StorageDevice.h"
#import "Drive.h"
#import "Volume.h"
#import "EtreCheckConstants.h"
#import "OSVersion.h"
#import "NSString+Etresoft.h"
#import "NSNumber+Etresoft.h"

// Some keys to be returned from machine lookuup.
#define kMachineIcon @"machineicon"
#define kMachineName @"machinename"

#define kVintage @"vintage"
#define kObsolete @"obsolete"

// Collect hardware information.
@implementation HardwareCollector

@synthesize properties = myProperties;
@synthesize machineIcon = myMachineIcon;
@synthesize genericDocumentIcon = myGenericDocumentIcon;
@synthesize marketingName = myMarketingName;
@synthesize EnglishMarketingName = myEnglishMarketingName;
@synthesize CPUCode = myCPUCode;
@synthesize supportsHandoff = mySupportsHandoff;
@synthesize supportsInstantHotspot = mySupportsInstantHotspot;
@synthesize supportsLowEnergy = mySupportsLowEnergy;
@synthesize vintageStatus = myVintageStatus;
@synthesize wikiChips = myWikiChips;

// Constructor.
- (id) init
  {
  self = [super initWithName: @"hardware"];
  
  if(self != nil)
    {
    }
    
  return self;
  }

// Destructor.
- (void) dealloc
  {
  self.genericDocumentIcon = nil;
  self.CPUCode = nil;
  self.EnglishMarketingName = nil;
  self.marketingName = nil;
  self.machineIcon = nil;
  self.properties = nil;
  self.vintageStatus = nil;
  [myWikiChips release];
  
  [super dealloc];
  }

// Perform the collection.
- (void) performCollect
  {
  [self loadProperties];  
  [self loadWikiChips];  

  [self collectBluetooth];
  [self collectSysctl];
  [self collectHardware];
  [self collectDevices];
    
  [self.result appendCR];
  }

// Load machine properties.
- (void) loadProperties
  {
  // First look for a machine attributes file.
  self.properties =
    [NSDictionary
      readPropertyList: ECLocalizedString(@"machineattributes")];
    
  // Don't give up yet. Try the old one too.
  if(!self.properties)
    self.properties =
      [NSDictionary
        readPropertyList:
          ECLocalizedString(@"oldmachineattributes")];
    
  // This is as good a place as any to collect this.
  NSString * computerName =
    (NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);

  NSString * hostName = (NSString *)SCDynamicStoreCopyLocalHostName(NULL);

  // Load the machine image.
  [self.model setComputerName: computerName];
  [self.model setHostName: hostName];
  
  if(self.machineIcon != nil)
    [self.model setMachineIcon: self.machineIcon];
  
  [computerName release];
  [hostName release];
  }

// Load wikichips.
- (void) loadWikiChips
  {
  NSBundle * bundle = [NSBundle bundleForClass: [self class]];

  NSString * signaturePath =
    [bundle pathForResource: @"wikichip" ofType: @"plist"];
    
  NSData * plistData = [NSData dataWithContentsOfFile: signaturePath];
  
  NSDictionary * plist = [NSDictionary readPropertyListData: plistData];
  
  if(plist != nil)
    {
    NSArray * chips = [plist objectForKey: @"chips"];
    
    if([NSArray isValid: chips])
      myWikiChips = [[NSSet alloc] initWithArray: chips];
    }
  }

// Collect bluetooth information.
- (void) collectBluetooth
  {
  NSString * key = @"SPBluetoothDataType";
  
  NSArray * args =
    @[
      @"-xml",
      key
    ];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  [subProcess loadDebugOutput: [self.model debugInputPath: key]];      
  [subProcess saveDebugOutput: [self.model debugOutputPath: key]];

  if([subProcess execute: @"/usr/sbin/system_profiler" arguments: args])
    {
    NSArray * plist =
      [NSArray readPropertyListData: subProcess.standardOutput];
  
    if([NSArray isValid: plist])
      {
      NSDictionary * results = [plist objectAtIndex: 0];
      
      if([NSDictionary isValid: results])
        {
        NSArray * infos = [results objectForKey: @"_items"];
          
        if([NSArray isValid: infos])
          for(NSDictionary * info in infos)
            if([NSDictionary isValid: info])
              {
              NSDictionary * localInfo =
                [info objectForKey: @"local_device_title"];
              
              if([NSDictionary isValid: localInfo])
                {
                NSString * generalSupportsHandoff =
                  [localInfo objectForKey: @"general_supports_handoff"];
                  
                NSString * generalSupportsInstantHotspot =
                  [localInfo
                    objectForKey: @"general_supports_instantHotspot"];
                
                NSString * generalSupportsLowEnergy =
                  [localInfo objectForKey: @"general_supports_lowEnergy"];
                  
                if([NSString isValid: generalSupportsHandoff])
                  self.supportsHandoff =
                    [generalSupportsHandoff isEqualToString: @"attrib_Yes"];
                
                if([NSString isValid: generalSupportsInstantHotspot])
                  self.supportsInstantHotspot =
                    [generalSupportsInstantHotspot
                      isEqualToString: @"attrib_Yes"];

                if([NSString isValid: generalSupportsLowEnergy])
                  self.supportsLowEnergy =
                    [generalSupportsLowEnergy 
                      isEqualToString: @"attrib_Yes"];     
                }
              }
        }
      }
    }
    
  [subProcess release];
  }

// Collect sysctl information.
- (void) collectSysctl
  {
  NSString * code = nil;
  
  NSString * key = @"machdep.cpu.brand_string";
  
  NSArray * args = @[key];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  [subProcess loadDebugOutput: [self.model debugInputPath: key]];      
  [subProcess saveDebugOutput: [self.model debugOutputPath: key]];

  if([subProcess execute: @"/usr/sbin/sysctl" arguments: args])
    {
    NSArray * lines = [Utilities formatLines: subProcess.standardOutput];
    
    for(NSString * line in lines)
      if([line hasPrefix: @"machdep.cpu.brand_string:"])
        if([line length] > 26)
          {
          NSString * description = [line substringFromIndex: 26];
          NSArray * parts = [description componentsSeparatedByString: @" "];
          
          NSUInteger count = [parts count];
          
          for(NSUInteger i = 0; i < count; ++i)
            {
            NSString * part = [parts objectAtIndex: i];
            
            if([part isEqualToString: @"CPU"])
              if(i > 0)
                code = [parts objectAtIndex: i - 1];
            }
          }
    }
    
  [subProcess release];
  
  if([code length] > 0)
    self.CPUCode = code;
  }

// Collect hardware information.
- (void) collectHardware
  {
  NSString * key = @"SPHardwareDataType";
  
  NSArray * args =
    @[
      @"-xml",
      key
    ];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  [subProcess loadDebugOutput: [self.model debugInputPath: key]];      
  [subProcess saveDebugOutput: [self.model debugOutputPath: key]];

  if([subProcess execute: @"/usr/sbin/system_profiler" arguments: args])
    {
    NSArray * plist =
      [NSArray readPropertyListData: subProcess.standardOutput];
  
    if([NSArray isValid: plist])
      {
      NSDictionary * results = [plist objectAtIndex: 0];
      
      if([NSDictionary isValid: results])
        {
        NSArray * infos = [results objectForKey: @"_items"];
          
        if([NSArray isValid: infos])
          {
          [self.result appendAttributedString: [self buildTitle]];

          for(NSDictionary * info in infos)
            [self printMachineInformation: info];
            
          [self printBluetoothInformation];
          [self printWirelessInformation];
          [self printBatteryInformation];
          }
        }
      }
    }
    
  [subProcess release];
  }

// Collect all disk devices.
- (BOOL) collectDevices
  {
  BOOL dataFound = NO;
  
  NSArray * args =
    @[
      @"/dev",
      @"-name",
      @"disk*"
    ];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  NSString * key = @"diskdevices";
  
  [subProcess loadDebugOutput: [self.model debugInputPath: key]];      
  [subProcess saveDebugOutput: [self.model debugOutputPath: key]];

  if([subProcess execute: @"/usr/bin/find" arguments: args])
    {
    NSArray * devices = [Utilities formatLines: subProcess.standardOutput];
    
    // Carefully sort the devices.
    NSArray * sortedDevices = [StorageDevice sortDeviceIdenifiers: devices];
    
    // Collect each device.
    for(NSString * device in sortedDevices)
      if([self collectDevice: device])
        dataFound = YES;
    }
    
  [subProcess release];
  
  return dataFound;
  }
  
// Collect a single device.
- (BOOL) collectDevice: (NSString *) device
  {
  BOOL dataFound = NO;
  
  NSArray * args =
    @[
      @"info",
      @"-plist",
      device
    ];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  NSString * key = 
    [device stringByReplacingOccurrencesOfString: @"/" withString: @"_"];
  
  [subProcess loadDebugOutput: [self.model debugInputPath: key]];      
  [subProcess saveDebugOutput: [self.model debugOutputPath: key]];

  if([subProcess execute: @"/usr/sbin/diskutil" arguments: args])
    {
    NSDictionary * plist =
      [NSDictionary readPropertyListData: subProcess.standardOutput];
  
    if([NSDictionary isValid: plist])
      {
      // Separate items by virtual or physical. Anything virtual will be
      // considered a volume.
      NSString * type = [plist objectForKey: @"VirtualOrPhysical"];
      NSNumber * wholeDisk = [plist objectForKey: @"WholeDisk"];
      
      BOOL drive = NO;
      
      if([NSString isValid: type] && [type isEqualToString: @"Physical"])
        drive = YES;
      
      // WholeDisk could be true and type could be Virtual. I just want
      // pre-container HFS+ before Core Storage or APFS.
      if([NSNumber isValid: wholeDisk] && wholeDisk.boolValue)
        drive = YES;
        
      if([NSString isValid: type] && [type isEqualToString: @"Virtual"])
        drive = NO;

      // Not so fast. If there is a volume indicator, it must be a volume.
      NSString * volumeUUID = [plist objectForKey: @"VolumeUUID"];
      
      if([NSString isValid: volumeUUID])
        drive = NO;  

      // Same for a disk.
      NSString * diskUUID = [plist objectForKey: @"DiskUUID"];
      
      if([NSString isValid: diskUUID])
        drive = NO;  

      // Hack this for now. disk0 always has to be a disk.
      if([device isEqualToString: @"disk0"])
        drive = YES;
        
      if(drive)
        {
        if([self collectPhysicalDrive: plist])
          dataFound = YES;
        }
      else if([self collectVolume: plist])
        dataFound = YES;
      }
    }
    
  [subProcess release];
  
  return dataFound;
  }

// Collect a physical drive.
- (BOOL) collectPhysicalDrive: (NSDictionary *) plist
  {
  Drive * drive = [[Drive alloc] initWithDiskUtilInfo: plist];
  
  drive.cleanName = [self cleanName: drive.name];
  
  drive.dataModel = self.model;
  
  BOOL dataFound = NO;
  
  if(drive != nil)
    {
    [[self.model storageDevices] 
      setObject: drive forKey: drive.identifier];
    
    dataFound = YES;
    }
  
  [drive release];
  
  return dataFound;
  }

// Collect a volume.
- (BOOL) collectVolume: (NSDictionary *) plist
  {
  Volume * volume = [[Volume alloc] initWithDiskUtilInfo: plist];
  
  volume.model = self.model;
  volume.cleanName = [self cleanName: volume.name];
  
  BOOL dataFound = NO;
  
  if(volume != nil)
    {
    [[self.model storageDevices] 
      setObject: volume forKey: volume.identifier];
      
    dataFound = YES;
    }
    
  [volume release];
  
  return dataFound;
  }

// Print informaiton for the machine.
- (void) printMachineInformation: (NSDictionary *) info
  {
  NSString * name = [info objectForKey: @"machine_name"];
  NSString * model = [info objectForKey: @"machine_model"];
  NSString * cpu_type = [info objectForKey: @"cpu_type"];
  
  if(cpu_type.length == 0)
    cpu_type = self.CPUCode;
    
  NSNumber * core_count =
    [info objectForKey: @"number_processors"];
  
  NSString * speed =
    [info objectForKey: @"current_processor_speed"];
  
  NSNumber * cpu_count = [info objectForKey: @"packages"];
  NSString * memory = [info objectForKey: @"physical_memory"];
  NSString * serial = [info objectForKey: @"serial_number"];

  if([NSString isValid: model])
    [self.model setModel: model];
  
  // Extract the memory.
  if([NSString isValid: memory])
    [self.model
      setPhysicalRAM: [self parseMemory: memory]];

  if(self.simulating)
    memory = @"2 GB";
    
  if([NSString isValid: serial] && (serial.length >= 8))
    [self.model setSerialCode: [serial substringFromIndex: 8]];

  self.vintageStatus = [self getVintageStatus];
  
  if([NSString isValid: model])
    {
    // Print the human readable machine name, if I can find one.
    [self printHumanReadableMacName: model];
    
    [self.result
      appendString:
        [NSString
          stringWithFormat:
            ECLocalizedString(@"    %@ - %@: %@\n"),
            name, ECLocalizedString(@"model"), model]];
    }
    
  if([NSString isValid: name])
    [self.xml addElement: @"name" value: name];
  
  if([NSString isValid: model])  
    [self.xml addElement: @"model" value: model];
  
  if([NSString isValid: self.vintageStatus])
    [self.xml addElement: @"vintage" value: self.vintageStatus];
    
  NSString * type = [self.model modelType];
  
  if([NSString isValid: type])  
    [self.xml addElement: @"modeltype" value: type];
  
  [self.xml 
    addElement: @"modelmajorversion" 
    intValue: [self.model modelMajorVersion]];
    
  [self.xml 
    addElement: @"modelminorversion" 
    intValue: [self.model modelMinorVersion]];
  
  NSString * code = @"";
  
  if(self.CPUCode.length > 0)
    code = [NSString stringWithFormat: @" (%@)", self.CPUCode];
    
  if(![NSNumber isValid: cpu_count])
    return;
    
  if(![NSString isValid: speed])
    return;

  if(![NSString isValid: cpu_type])
    return;

  if(![NSNumber isValid: core_count])
    return;
    
  [self.result
    appendString:
      [NSString
        stringWithFormat:
          ECLocalizedString(
            @"    %@ %@ %@%@ CPU: %@-core\n"),
          cpu_count,
          speed,
          cpu_type ? cpu_type : @"",
          code,
          core_count]];
    
  NSString * wikichip = 
    [[self.CPUCode lowercaseString]   
      stringByReplacingOccurrencesOfString: @" " withString: @"_"];
  
  [self.xml addElement: @"cpucount" number: cpu_count];
  [self.xml addElement: @"speed" valueWithUnits: speed];
  [self.xml addElement: @"cpu_type" value: cpu_type];      
  [self.xml addElement: @"cpucode" value: self.CPUCode];
  
  if([self.wikiChips containsObject: wikichip])
    [self.xml addElement: @"wikichip" value: wikichip];
  
  [self.xml addElement: @"corecount" number: core_count];

  if([NSString isValid: memory])
    [self printMemory: memory];
  }

// Parse a memory string into an int (in GB).
- (int) parseMemory: (NSString *) memory
  {
  NSScanner * scanner = [NSScanner scannerWithString: memory];

  int physicalMemory;
  
  if(![scanner scanInt: & physicalMemory])
    physicalMemory = 0;

  if(self.simulating)
    physicalMemory = 2;
    
  return physicalMemory;
  }

// Extract a "marketing name" for a machine from a serial number.
- (void) printHumanReadableMacName: (NSString *) code
  {
  // Try to get the marketing name from Apple.
  [self askAppleForMarketingName];
  
  // Get information on my own.
  NSDictionary * machineProperties = [self lookupMachineProperties: code];
  
  if([NSDictionary isValid: machineProperties])
    if(self.marketingName.length == 0)
      self.marketingName = [machineProperties objectForKey: kMachineName];
      
  [self.result
    appendString:
      [NSString
        stringWithFormat: @"    %@ \n", self.marketingName]];
      
  [self.xml addElement: @"marketingname" value: self.marketingName];
    
  NSString * language = ECLocalizedString(@"en");

  [self.result appendString: @"    "];
  
  NSString * url = [self technicalSpecificationsURL: language];
  
  [self.result
    appendAttributedString:
      [Utilities
        buildURL: url
        title:
          ECLocalizedString(
            @"[Technical Specifications]")]];

  [self.xml
    addElement: @"technicalspecificationsurl"
    url: [NSURL URLWithString: url]];

  [self.result appendString: @" - "];

  url = [self userGuideURL: language];

  [self.result
    appendAttributedString:
      [Utilities
        buildURL: url
        title:
          ECLocalizedString(
            @"[User Guide]")]];
    
  [self.xml 
    addElement: @"userguideurl" url: [NSURL URLWithString: url]];

  [self.result appendString: @" - "];

  url = [self serviceURL];

  [self.result
    appendAttributedString:
      [Utilities
        buildURL: url
        title:
          ECLocalizedString(
            @"[Warranty & Service]")]];

  [self.xml
    addElement: @"warrantyandserviceurl"
    url: [NSURL URLWithString: url]];

  [self.result appendString: @"\n"];
  }

// Try to get the marketing name directly from Apple.
- (void) askAppleForMarketingName
  {
  NSString * language = ECLocalizedString(@"en");
  
  self.marketingName = [self askAppleForMarketingName: language];
  
  if([language isEqualToString: @"en"])
    self.EnglishMarketingName = self.marketingName;
  else
    self.EnglishMarketingName = [self askAppleForMarketingName: @"en"];
  }

// Try to get the marketing name directly from Apple.
- (NSString *) askAppleForMarketingName: (NSString *) language
  {
  return
    [Utilities
      askAppleForMarketingName: [self.model serialCode]
      language: language
      type: @"product?"];
  }

// Construct a technical specifications URL.
- (NSString *) technicalSpecificationsURL: (NSString *) language
  {
  return
    [Utilities
      AppleSupportSPQueryURL: [self.model serialCode]
      language: language
      type: @"index?page=cpuspec"];
  }

// Construct a user guide URL.
- (NSString *) userGuideURL: (NSString *) language
  {
  return
    [Utilities
      AppleSupportSPQueryURL: [self.model serialCode]
      language: language
      type: @"index?page=cpuuserguides"];
  }

// Construct a memory upgrade URL.
- (NSString *) memoryUpgradeURL: (NSString *) language
  {
  return
    [Utilities
      AppleSupportSPQueryURL: [self.model serialCode]
      language: language
      type: @"index?page=cpumemory"]; 
  }

// Construct a user guide URL.
- (NSString *) serviceURL
  {
  NSString * localeCode = [Utilities localeCode];
  
  NSString * url =
    @"https://support.apple.com/%@/mac-desktops/repair/service";
  
  if([[self.model model] hasPrefix: @"MacBook"])
    url = @"https://support.apple.com/%@/mac-notebooks/repair/service";

  return [NSString stringWithFormat: url, localeCode];
  }

// Try to get information about the machine from system resources.
- (NSDictionary *) lookupMachineProperties: (NSString *) code
  {
  // If I have a machine code, try to look up the built-in attributes.
  if(code)
    if(self.properties)
      {
      NSDictionary * modelInfo = [self.properties objectForKey: code];
      
      // Load the machine image.
      if(self.machineIcon == nil)
        self.machineIcon = [self findCurrentMachineIcon];
      
      // Get machine name.
      NSString * machineName = [self lookupMachineName: modelInfo];
        
      // Fallback.
      if(!machineName)
        machineName = code;
        
      NSMutableDictionary * result = [NSMutableDictionary dictionary];
      
      [result setObject: machineName forKey: kMachineName];
      
      if(self.machineIcon)
        [result setObject: self.machineIcon forKey: kMachineIcon];
        
      return result;
      }
  
  return nil;
  }

// Get the machine name.
- (NSString *) lookupMachineName: (NSDictionary *) machineInformation
  {
  // Now get the machine name.
  NSDictionary * localizedModelInfo =
    [machineInformation objectForKey: @"_LOCALIZABLE_"];
    
  // New machines.
  NSString * machineName =
    [localizedModelInfo objectForKey: @"marketingModel"];

  // Older machines.
  if(![NSString isValid: machineName])
    if([NSDictionary isValid: localizedModelInfo])
      machineName = [localizedModelInfo objectForKey: @"description"];
    
  return machineName;
  }

// Find a machine icon.
- (NSImage *) findCurrentMachineIcon
  {
  NSImage * icon = [NSImage imageNamed: NSImageNameComputer];
  
  [icon setSize: NSMakeSize(1024, 1024)];

  return icon;
  }

// Print memory, flagging insufficient amounts.
- (void) printMemory: (NSString *) memory
  {
  NSDictionary * details = [self collectMemoryDetails];
  
  bool upgradeable = NO;
  NSString * upgradeableString = @"";
  
  if([NSDictionary isValid: details])
    {
    NSNumber * isUpgradeable =
      [details objectForKey: @"is_memory_upgradeable"];
    
    if([NSNumber isValid: isUpgradeable])  
      upgradeable = [isUpgradeable boolValue];
    else
      {
      NSString * isUpgradeableString = (NSString *)isUpgradeable;
      
      if([NSString isValid: isUpgradeableString])
        upgradeable = [isUpgradeableString isEqualToString: @"Yes"];
      }
    
    if(self.simulating)
      upgradeable = true;
      
    // Snow Leopoard doesn't seem to report this.
    if(isUpgradeable != nil)
      upgradeableString =
        upgradeable
          ? ECLocalizedString(@"Upgradeable")
          : ECLocalizedString(@"Not upgradeable");
    }
    
  if([self.model physicalRAM] < 4)
    {
    [self.result
      appendString:
        [NSString
          stringWithFormat:
            @"    %@ RAM - %@ %@",
            memory,
            ECLocalizedString(@"insufficientram"),
            upgradeableString]
      attributes:
        [NSDictionary
          dictionaryWithObjectsAndKeys:
            [NSColor redColor], NSForegroundColorAttributeName, nil]];
    }
  else
    [self.result
      appendString:
        [NSString
          stringWithFormat: @"    %@ RAM %@", memory, upgradeableString]];

  [self.xml addElement: @"ram" valueWithUnits: memory];
  
  NSString * language = ECLocalizedString(@"en");

  NSString * url = [self memoryUpgradeURL: language];
  
  [self.xml addElement: @"upgradeable" boolValue: upgradeable];
  
  if(upgradeable)
    {
    [self.result appendString: @" - "];

    [self.result
      appendAttributedString:
        [Utilities
          buildURL: url
          title:
            ECLocalizedString(
              @"[Instructions]\n")]];
      
    [self.xml
      addElement: @"memoryupgradeinstructionsurl"
      url: [NSURL URLWithString: url]];
      
    int max = [self getMaximumMemory];
    
    [self.xml
      addElement: @"applemaximummemory" 
      intValue: max 
      attributes: 
        [NSDictionary 
          dictionaryWithObjectsAndKeys: 
            @"number", @"type", @"GB", @"units", nil]];
    }
  else
    [self.result appendString: @"\n"];
    
  if([NSDictionary isValid: details])
    {
    NSArray * banks = [details objectForKey: @"_items"];
    
    if([NSArray isValid: banks])
      [self printMemoryBanks: banks];
    }
  }

- (NSDictionary *) collectMemoryDetails
  {
  NSString * key = @"SPMemoryDataType";
  
  NSArray * args =
    @[
      @"-xml",
      key
    ];
  
  NSDictionary * result = nil;
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  [subProcess loadDebugOutput: [self.model debugInputPath: key]];      
  [subProcess saveDebugOutput: [self.model debugOutputPath: key]];
  
  if([subProcess execute: @"/usr/sbin/system_profiler" arguments: args])
    {
    NSArray * plist =
      [NSArray readPropertyListData: subProcess.standardOutput];
  
    if([NSArray isValid: plist])
      {
      NSDictionary * results = [plist objectAtIndex: 0];
      
      if([NSDictionary isValid: results])
        {
        NSArray * infos = [results objectForKey: @"_items"];
          
        if([NSArray isValid: infos])
          result = [infos objectAtIndex: 0];
        }
      }
    }
    
  [subProcess release];
    
  return result;
  }

// Print memory banks.
- (void) printMemoryBanks: (NSArray *) banks
  {
  [self.xml startElement: @"memorybanks"];
  
  for(NSDictionary * bank in banks)
    {
    if(![NSDictionary isValid: bank])
      continue;
      
    NSString * name = [bank objectForKey: @"_name"];
    NSString * size = [bank objectForKey: @"dimm_size"];
    NSString * type = [bank objectForKey: @"dimm_type"];
    NSString * speed = [bank objectForKey: @"dimm_speed"];
    NSString * status = [bank objectForKey: @"dimm_status"];
    
    if(![NSString isValid: name])
      continue;
      
    if(![NSString isValid: size])
      continue;

    if(![NSString isValid: type])
      continue;

    if(![NSString isValid: speed])
      continue;

    if(![NSString isValid: status])
      continue;

    NSString * currentBankID = name;
      
    if([size isEqualToString: @"(empty)"])
      size = @"empty";
      
    NSString * empty = ECLocalizedString(@"Empty");
    
    if([size isEqualToString: @"empty"])
      {
      size = empty;
      type = @"";
      speed = @"";
      status = @"";
      }
      
    NSString * currentBankInfo =
      [NSString
        stringWithFormat:
          @"            %@ %@ %@ %@\n", size, type, speed, status];
      
    [self.result appendString: @"        "];
    [self.result appendString: currentBankID];
    [self.result appendString: @"\n"];
    [self.result appendString: currentBankInfo];
    
    [self.xml startElement: @"memorybank"];
    
    [self.xml addElement: @"identifier" value: currentBankID];
    [self.xml addElement: @"size" valueWithUnits: size];
    [self.xml addElement: @"type" value: type];
    [self.xml addElement: @"speed" valueWithUnits: speed];
    [self.xml addElement: @"status" value: status];

    [self.xml endElement: @"memorybank"];
    }

  [self.xml endElement: @"memorybanks"];
  }

// Print information about bluetooth.
- (void) printBluetoothInformation
  {
  NSString * info = [self collectBluetoothInformation];
  
  [self.result
    appendString:
      [NSString 
        stringWithFormat: 
          ECLocalizedString(@"    Handoff/Airdrop2: %@\n"), info]];
  }

// Collect bluetooth information.
- (NSString *) collectBluetoothInformation
  {
  [self.xml 
    addElement: @"continuity" boolValue: [self supportsContinuity]];

  if([self supportsContinuity])
    return ECLocalizedString(@"supported");
              
  return ECLocalizedString(@"not supported");
  }

// Is continuity supported?
- (bool) supportsContinuity
  {
  if(self.supportsHandoff)
    return YES;
    
  NSString * model = [self.model model];
  
  NSString * specificModel = nil;
  int target = 0;
  int number = 0;
  
  if([model hasPrefix: @"MacBookPro"])
    {
    specificModel = @"MacBookPro";
    target = 9;
    }
  else if([model hasPrefix: @"iMac"])
    {
    specificModel = @"iMac";
    target = 13;
    }
  else if([model hasPrefix: @"MacPro"])
    {
    specificModel = @"MacPro";
    target = 6;
    }
  else if([model hasPrefix: @"MacBookAir"])
    {
    specificModel = @"MacBookAir";
    target = 5;
    }
  else if([model hasPrefix: @"MacBook"])
    {
    specificModel = @"MacBook";
    target = 8;
    }
  else if([model hasPrefix: @"Macmini"])
    {
    specificModel = @"Macmini";
    target = 6;
    }
    
  if(specificModel)
    {
    NSScanner * scanner = [NSScanner scannerWithString: model];
    
    if([scanner scanString: specificModel intoString: NULL])
      if([scanner scanInt: & number])
        if(number >= target)
          self.supportsHandoff = YES;
    }
    
  return self.supportsHandoff;
  }

// Print wireless information.
- (void) printWirelessInformation
  {
  NSString * key = @"SPAirPortDataType";
  
  NSArray * args =
    @[
      @"-xml",
      key
    ];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  [subProcess loadDebugOutput: [self.model debugInputPath: key]];      
  [subProcess saveDebugOutput: [self.model debugOutputPath: key]];

  if([subProcess execute: @"/usr/sbin/system_profiler" arguments: args])
    {
    NSArray * plist =
      [NSArray readPropertyListData: subProcess.standardOutput];
  
    if(plist && [plist count])
      {
      NSArray * infos =
        [[plist objectAtIndex: 0] objectForKey: @"_items"];
        
      if([NSArray isValid: infos])
        for(NSDictionary * info in infos)
          if([NSDictionary isValid: info])
            {
            NSArray * interfaces =
              [info objectForKey: @"spairport_airport_interfaces"];
              
            if([NSArray isValid: interfaces])
              {
              NSUInteger count = [interfaces count];
              
              if(interfaces)
                [self.result
                  appendString:
                    [NSString
                      stringWithFormat:
                        ECLocalizedString(@"    Wireless: %@"),
                        ECLocalizedPluralString(count, @"interface")]];
              
              for(NSDictionary * interface in interfaces)
                [self
                  printWirelessInterface: interface
                  indent: count > 1 ? @"        " : @" "];
              }
            }
      }
    }
    
  [subProcess release];
  }

// Print a single wireless interface.
- (void) printWirelessInterface: (NSDictionary *) interface
  indent: (NSString *) indent
  {
  NSString * name = [interface objectForKey: @"_name"];
  NSString * modes = 
    [interface objectForKey: @"spairport_supported_phymodes"];

  if([NSString isValid: name] && [NSString isValid: modes])
    {
    [self.result
      appendString:
        [NSString 
          stringWithFormat: 
            ECLocalizedString(@"%@%@: %@\n"), indent, name, modes]];
    
    [self.xml startElement: @"wireless"];

    [self.xml addElement: @"name" value: name];
    [self.xml addElement: @"modes" value: modes];

    [self.xml endElement: @"wireless"];
    }
    
  else if([NSString isValid: name])
    {
    [self.result
      appendString:
        [NSString 
          stringWithFormat: 
            ECLocalizedString(@"%@%@: %@\n"), 
            indent, 
            name, 
            ECLocalizedString(@"Unknown")]];

    [self.xml startElement: @"wireless"];

    [self.xml addElement: @"name" value: name];

    [self.xml endElement: @"wireless"];
    }
            
  else
    {
    [self.result
      appendString:
        [NSString 
          stringWithFormat: 
            @"%@%@\n", indent, ECLocalizedString(@"Unknown")]];

    [self.xml addElement: @"wireless"];
    }
  }

// Print battery information.
- (void) printBatteryInformation
  {
  NSString * key = @"SPPowerDataType";
  
  NSArray * args =
    @[
      @"-xml",
      key
    ];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  [subProcess loadDebugOutput: [self.model debugInputPath: key]];      
  [subProcess saveDebugOutput: [self.model debugOutputPath: key]];

  if([subProcess execute: @"/usr/sbin/system_profiler" arguments: args])
    {
    NSArray * plist =
      [NSArray readPropertyListData: subProcess.standardOutput];
  
    if([NSArray isValid: plist])
      {
      NSDictionary * results = [plist objectAtIndex: 0];
      
      if([NSDictionary isValid: results])
        {
        NSArray * infos = [results objectForKey: @"_items"];
          
        if([NSArray isValid: infos])
          [self printBatteryInformation: infos];
        }
      }
    }
    
  [subProcess release];
  }

// Print battery information.
- (void) printBatteryInformation: (NSArray *) infos
  {
  NSNumber * cycleCount = nil;
  NSString * health = nil;
  NSString * serialNumber = @"";
  BOOL serialNumberInvalid = NO;
  
  if([NSArray isValid: infos])
    for(NSDictionary * info in infos)
      {
      NSDictionary * healthInfo =
        [info objectForKey: @"sppower_battery_health_info"];
        
      if([NSDictionary isValid: healthInfo])
        {
        cycleCount =
          [healthInfo objectForKey: @"sppower_battery_cycle_count"];
        health = [healthInfo objectForKey: @"sppower_battery_health"];
        }

      NSDictionary * modelInfo =
        [info objectForKey: @"sppower_battery_model_info"];
        
      if([NSDictionary isValid: modelInfo])
        {
        serialNumber =
          [modelInfo objectForKey: @"sppower_battery_serial_number"];
        
        if([serialNumber isEqualToString: @"0123456789ABC"])
        //if([serialNumber isEqualToString: @"D865033Y2CXF9CPAW"])
          serialNumberInvalid = YES;
        }
      }
    
  if(self.simulating)
    health = @"Poor";
    
  if(cycleCount && [health length])
    {
    BOOL flagged = NO;
    
    if([health isEqualToString: @"Poor"])
      flagged = YES;
      
    if([health isEqualToString: @"Check Battery"])
      flagged = YES;
      
    if(flagged)
      [self.result
        appendString:
          [NSString
            stringWithFormat:
            ECLocalizedString(
              @"    Battery: Health = %@ - Cycle count = %@\n"),
            ECLocalizedStringFromTable(health, @"System"), cycleCount]
        attributes:
          [NSDictionary
            dictionaryWithObjectsAndKeys:
              [NSColor redColor], NSForegroundColorAttributeName, nil]];
    else
      [self.result
        appendString:
          [NSString
            stringWithFormat:
              ECLocalizedString(
                @"    Battery: Health = %@ - Cycle count = %@\n"),
              ECLocalizedStringFromTable(health, @"System"), 
              cycleCount]];
      
    [self.xml addElement: @"batteryhealth" value: health];
    
    [self.xml addElement: @"batterycyclecount" number: cycleCount];
    
    [self.xml 
      addElement: @"batterypercent" 
      intValue: cycleCount.intValue * 100 / [self getLifetimeCycles]];
      
    //[self.xml addElement: @"batteryserialnumber" value: serialNumber];
    
    if(serialNumberInvalid)
      [self.result
        appendString:
          [NSString
            stringWithFormat:
              ECLocalizedString(
                @"        Battery serial number %@ invalid\n"),
                serialNumber]
        attributes:
          [NSDictionary
            dictionaryWithObjectsAndKeys:
              [NSColor redColor], NSForegroundColorAttributeName, nil]];
    }
  }

// Get the number of lifetime batter cycles for this machine.
- (int) getLifetimeCycles
  {
  int cycles = 1000;
  
  NSString * modelType = [self.model modelType];
  int majorVersion = [self.model modelMajorVersion];
  int minorVersion = [self.model modelMinorVersion];
  
  if([modelType isEqualToString: @"MacBookPro"])
    {
    if(majorVersion == 5)
      {
      BOOL oldModel = 
        [self.EnglishMarketingName 
          isEqualToString: @"MacBook Pro (15-inch Late 2008)"];
          
      if(oldModel)
        cycles = 500;
      }
    else if(majorVersion < 5)
      cycles = 300;
    }
  else if([modelType isEqualToString: @"MacBookAir"])
    {
    if(majorVersion == 5)
      {
      BOOL newModel = 
        [self.EnglishMarketingName 
          isEqualToString: @"MacBook Air (Mid 2009)"];
      
      if(newModel)
        cycles = 500;
      else
        cycles = 300;
      }
    else if (majorVersion < 2)
      cycles = 300;
    }
  else if([modelType isEqualToString: @"MacBook"])
    {
    if((majorVersion == 5) && (minorVersion == 1))
      cycles = 500;
    else if(majorVersion < 6)
      cycles = 300;
    }
        
  return cycles;
  }
  
// Get the vintage status of the machine.
- (NSString *) getVintageStatus
  {
  NSString * modelType = [self.model modelType];
  int majorVersion = [self.model modelMajorVersion];
  int minorVersion = [self.model modelMinorVersion];
  
  if([modelType isEqualToString: @"MacBookPro"])
    {
    if(majorVersion < 6)
      return kObsolete;
    else if(majorVersion < 8)
      return kVintage;
    }
  else if([modelType isEqualToString: @"MacBookAir"])
    {
    if(majorVersion < 5)
      return kObsolete;
    else if (majorVersion < 3)
      return kVintage;
    }
  else if([modelType isEqualToString: @"MacBook"])
    {
    if(majorVersion < 6)
      return kObsolete;
    else if(majorVersion < 8)
      return kVintage;
    }
  else if([modelType isEqualToString: @"iMac"])
    {
    if(majorVersion < 11)
      return kObsolete;
    else if(majorVersion < 12)
      return kVintage;
    }
  else if([modelType isEqualToString: @"Macmini"])
    {
    if(majorVersion < 4)
      return kObsolete;
    else if(majorVersion < 6)
      return kVintage;
    }
  else if([modelType isEqualToString: @"MacPro"])
    {
    if(majorVersion < 4)
      return kObsolete;
    else if(majorVersion < 5)
      return kVintage;
    else if((majorVersion == 5) && (minorVersion == 1))
      {
      BOOL vintageModel = 
        [self.EnglishMarketingName isEqualToString: @"Mac Pro (Mid 2010)"];
      
      if(vintageModel)
        return kVintage;
      }
    }
  else if([modelType isEqualToString: @"Xserve"])
    {
    if(majorVersion < 3)
      return kObsolete;
    else if(majorVersion < 4)
      return kVintage;
    }
        
  return nil;
  }

// Get the maximum memory for this machine.
- (int) getMaximumMemory
  {
  int max = 2;
  
  NSString * modelType = [self.model modelType];
  int majorVersion = [self.model modelMajorVersion];
  int minorVersion = [self.model modelMinorVersion];
  int cores = [self.model coreCount];
  
  if([modelType isEqualToString: @"MacBookPro"])
    {
    if(majorVersion > 5)
      max = 8;
    else if(majorVersion == 5)
      {
      max = 8;
      
      BOOL oldModel = 
        [self.EnglishMarketingName 
          isEqualToString: @"MacBook Pro (15-inch Late 2008)"];
          
      if(oldModel)
        max = 4;
      }
    else if(majorVersion >= 3)
      max = 4;
    else if(majorVersion == 2)
      max = 3;
    else 
      max = 2;
    }
  else if([modelType isEqualToString: @"MacBook"])
    {
    if(majorVersion >= 3)
      max = 4;
    else 
      max = 2;
    }
  else if([modelType isEqualToString: @"Macmini"])
    {
    if(majorVersion >= 6)
      max = 16;
    else if(majorVersion >= 4)
      max = 8;
    else if(majorVersion >= 3)
      max = 4;
    else 
      max = 2;
    }
  else if([modelType isEqualToString: @"iMacPro"])
    {
    max = 128;
    }
  else if([modelType isEqualToString: @"iMac"])
    {
    if(majorVersion >= 18)
      max = 64;
    else if(majorVersion >= 13)
      max = 32;
    else if(majorVersion >= 10)
      max = 16;
    else if(majorVersion >= 9)
      max = 8;
    else if(majorVersion >= 5)
      {
      max = 4;

      if(minorVersion == 2)
        max = 2;
      }
    else 
      max = 2;
    }
  else if([modelType isEqualToString: @"MacPro"])
    {
    if(majorVersion >= 6)
      max = 64;
    else if(majorVersion >= 5)
      {
      max = 32;
      
      if(cores > 6)
        max = 64;
      }
    else if(majorVersion >= 4)
      {
      max = 16;
      
      if(cores > 4)
        max = 32;
      }
    else 
      max = 32;
    }
        
  return max;
  }

@end
