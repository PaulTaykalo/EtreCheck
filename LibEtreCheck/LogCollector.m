/***********************************************************************
 ** Etresoft
 ** John Daniel
 ** Copyright (c) 2014-2017. All rights reserved.
 **********************************************************************/

#import "LogCollector.h"
#import "Model.h"
#import "Utilities.h"
#import "NSArray+Etresoft.h"
#import "DiagnosticEvent.h"
#import "SubProcess.h"
#import "DiagnosticsCollector.h"
#import "LocalizedString.h"
#import "StorageDevice.h"
#import "NSString+Etresoft.h"
#import "NSDictionary+Etresoft.h"
#import "NSDate+Etresoft.h"

// Collect information from log files.
@implementation LogCollector

// Constructor.
- (id) init
  {
  self = [super initWithName: @"log"];
  
  if(self)
    {
    }
    
  return self;
  }

// Perform the collection.
- (void) performCollect
  {
  [self collectLogInformation];
  
  [self collectSystemLog];
  }

// Collect information from log files.
- (void) collectLogInformation
  {
  NSArray * args =
    @[
      @"-xml",
      @"SPLogsDataType"
    ];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  [subProcess autorelease];
  
  if([subProcess execute: @"/usr/sbin/system_profiler" arguments: args])
    {
    if(!subProcess.standardOutput)
      return;
      
    NSArray * plist =
      [NSArray readPropertyListData: subProcess.standardOutput];

    if([NSArray isValid: plist])
      {      
      NSDictionary * results = [plist objectAtIndex: 0];
      
      if([NSDictionary isValid: results])
        {
        NSArray * items = [results objectForKey: @"_items"];
          
        if([NSArray isValid: items])
          for(NSDictionary * item in items)
            if([NSDictionary isValid: item])
              [self collectLogResults: item];
        }
      }
    }
  }

// Collect results from a log entry.
- (void) collectLogResults: (NSDictionary *) result
  {
  if(![NSDictionary isValid: result])
    return;
    
  // Currently the only thing I am looking for are I/O errors like this:
  // kernel_log_description / contents
  // 17 Nov 2014 15:39:31 kernel[0]: disk0s2: I/O error.
  NSString * name = [result objectForKey: @"_name"];
  
  if(![NSString isValid: name])
    return;
    
  NSString * content = [result objectForKey: @"contents"];
  
  if(![NSString isValid: content])
    return;
    
  if([name isEqualToString: @"kernel_log_description"])
    [self collectKernelLogContent: content];
  else if([name isEqualToString: @"asl_messages_description"])
    [self collectASLLogContent: content];
  else if([name isEqualToString: @"panic_log_description"])
    [self collectPanicLog: result];
  else if([name isEqualToString: @"ioreg_output_description"])
    [self collectIOReg: content];
    
  // I could do this on Sierra:
  // log show --predicate '(process == "kernel") && (eventMessage endswith ": I/O error.")'
  // but it would take forever.
    
  if(self.simulating)
    [self parseShutdownCode: -100];
  }

// Collect results from the kernel log entry.
- (void) collectKernelLogContent: (NSString *) content
  {
  NSArray * lines = [content componentsSeparatedByString: @"\n"];
  
  for(NSString * line in lines)
    if([line hasSuffix: @": I/O error."])
      [self collectIOError: line];
  }

// Collect I/O errors.
// 17 Nov 2014 10:06:15 kernel[0]: disk0s2: I/O error.
- (void) collectIOError: (NSString *) line
  {
  if(![NSString isValid: line])
    return;
    
  NSRange diskRange = [line rangeOfString: @": disk"];
  
  if(diskRange.location != NSNotFound)
    {
    diskRange.length = ([line length] - 12) - diskRange.location - 2;
    diskRange.location += 2;
    
    if(diskRange.location < [line length])
      if((diskRange.location + diskRange.length) < [line length])
        {
        NSString * disk = [line substringWithRange: diskRange];
        
        if([NSString isValid: disk])
          {
          NSDictionary * devices = [self.model storageDevices];
          
          if([NSDictionary isValid: devices])
            {
            StorageDevice * device = [devices objectForKey: disk];
            
            [device.errors addObject: line];
            }
          }
        }
    }
  }

// Collect GPU errors.
// 01/01/14 19:59:49,000 kernel[0]: Trying restart GPU ...
// 01/01/14 19:59:50,000 kernel[0]: GPU Hang State = 0x00000000
// 01/01/14 19:59:50,000 kernel[0]: GPU hang:
- (void) collectGPUError: (NSString *) line
  {
  BOOL errorFound = NO;
  
  NSRange tryingRange = [line rangeOfString: @": Trying restart GPU ..."];
  
  if(tryingRange.location != NSNotFound)
    errorFound = YES;
    
  NSRange hangStateRange = [line rangeOfString: @": GPU Hang State"];
  
  if(hangStateRange.location != NSNotFound)
    errorFound = YES;
    
  NSRange hangRange = [line rangeOfString: @": GPU hang:"];

  if(hangRange.location != NSNotFound)
    errorFound = YES;
    
  if(errorFound)
    {
    NSNumber * errorCount =
      [self.model gpuErrors];
      
    if(errorCount == nil)
      errorCount = [NSNumber numberWithUnsignedInteger: 0];
      
    errorCount =
      [NSNumber
        numberWithUnsignedInteger:
          [errorCount unsignedIntegerValue] + 1];
      
    [self.model setGpuErrors: errorCount];
    }
  }

// Collect results from the asl log entry.
- (void) collectASLLogContent: (NSString *) content
  {
  NSArray * lines = [content componentsSeparatedByString: @"\n"];
  
  NSMutableArray * events = [NSMutableArray array];
  
  __block DiagnosticEvent * event = nil;
  
  [lines
    enumerateObjectsUsingBlock:
      ^(id obj, NSUInteger idx, BOOL * stop)
        {
        NSString * line = (NSString *)obj;
        
        if([line length] >= 24)
          {
          NSDate * logDate =
            [Utilities
              stringAsDate: [line substringToIndex: 24]
              format: @"MMM d, yyyy, hh:mm:ss a"];
        
          if(logDate)
            {
            event = [DiagnosticEvent new];
            
            event.type = kASLLog;
            event.date = logDate;
            event.details = [self cleanPath: line];
            
            [events addObject: event];
            
            return;
            }
          }
          
        if(event.details)
          event.details =
            [NSString stringWithFormat: @"%@\n", event.details];
        }];
    
    
  [self.model setLogEntries: events];
  }

// Collect results from the panic log entry.
- (void) collectPanicLog: (NSDictionary *) info
  {
  if(![NSDictionary isValid: info])
    return;
    
  NSString * file = [info objectForKey: @"source"];
  
  if(![NSString isValid: file])
    return;
    
  NSString * sanitizedName = nil;
  
  NSDate * date = [info objectForKey: @"lastModified"];
  
  if(![NSDate isValid: date])
    return;
    
  [self parseFileName: file date: & date name: & sanitizedName];
  
  NSString * contents = [info objectForKey: @"contents"];
  
  if(![NSString isValid: contents])
    return;
    
  DiagnosticEvent * event = [DiagnosticEvent new];
  
  if(event != nil)
    {
    event.name = ECLocalizedString(@"Kernel");
    event.date = date;
    event.type = kPanic;
    event.file = file;
    event.details = contents;
    event.count = 1;
    
    [DiagnosticsCollector 
      parseDiagnosticData: contents event: event model: self.model];

    [[self.model diagnosticEvents] setObject: event forKey: event.name];
    
    [event release];
    }
  }

// Parse a file name and extract the date and sanitized name.
- (void) parseFileName: (NSString *) file
  date: (NSDate **) date
  name: (NSString **) name
  {
  NSString * extension = [file pathExtension];
  NSString * base = [file stringByDeletingPathExtension];
  
  // First the 2nd portion of the file name that contains the date.
  NSArray * parts = [base componentsSeparatedByString: @"_"];

  NSUInteger count = [parts count];
  
  if(count > 1)
    if(date)
      *date =
        [Utilities
          stringAsDate: [parts objectAtIndex: count - 2]
          format: @"yyyy-MM-dd-HHmmss"];

  // Now construct a safe file name.
  NSMutableArray * safeParts = [NSMutableArray arrayWithArray: parts];
  
  [safeParts removeLastObject];
  [safeParts
    addObject:
      [ECLocalizedString(@"[redacted]")
        stringByAppendingPathExtension: extension]];
  
  if(name)
    *name =
      [self cleanPath: [safeParts componentsJoinedByString: @"_"]];
  }

// Collect the system log, if accessible.
- (void) collectSystemLog
  {
  NSString * content =
    [NSString
      stringWithContentsOfFile: @"/var/log/system.log"
      encoding: NSUTF8StringEncoding
      error: NULL];
    
  if(content)
    [self collectSystemLogContent: content];
  }

// Collect results from the system log content.
- (void) collectSystemLogContent: (NSString *) content
  {
  NSArray * lines = [content componentsSeparatedByString: @"\n"];
  
  NSMutableArray * events = [NSMutableArray array];
  
  __block DiagnosticEvent * event = nil;
  
  [lines
    enumerateObjectsUsingBlock:
      ^(id obj, NSUInteger idx, BOOL * stop)
        {
        NSString * line = (NSString *)obj;
        
        if([line length] >= 15)
          {
          NSDate * logDate =
            [Utilities
              stringAsDate: [line substringToIndex: 15]
              format: @"MMM d HH:mm:ss"];
        
          if(logDate)
            {
            event = [DiagnosticEvent new];
            
            event.type = kSystemLog;
            event.date = logDate;
            event.details = [self cleanPath: line];
            
            [events addObject: event];
            
            return;
            }
          }
          
        if(event.details)
          event.details =
            [NSString stringWithFormat: @"%@\n", event.details];
        }];
    
    
  [self.model setLogEntries: events];
  }

// Collect results from the ioreg_output_description log entry.
- (void) collectIOReg: (NSString *) content
  {
  //BOOL found = NO;
  
  NSArray * lines = [content componentsSeparatedByString: @"\n"];
  
  for(NSString * line in lines)
    {
    NSRange range = [line rangeOfString: @"ShutdownCause"];
    
    if(range.location != NSNotFound)
      {
      NSString * shutdownCauseString =
        [line substringFromIndex: range.location + range.length];
      
      NSScanner * scanner =
        [NSScanner scannerWithString: shutdownCauseString];
      
      [scanner
        setCharactersToBeSkipped:
          [NSCharacterSet characterSetWithCharactersInString: @" =\""]];
        
      int shutdownCause = 0;
      
      if([scanner scanInt: & shutdownCause])
        {
        [self parseShutdownCode: shutdownCause];
        //found = YES;
        }
      }
    }
  }

// Parse a shutdown code.
- (void) parseShutdownCode: (int) shutdownCause
  {
  NSString * shutdownString = ECLocalizedString(@"Unknown");
  
  switch(shutdownCause)
    {
    case 5:
      //shutdownString = ECLocalizedString(@"Normal");
      return;
      
    case 3:
      shutdownString = ECLocalizedString(@"Hard shutdown");
      break;
      
    case 0:
      shutdownString = ECLocalizedString(@"Power loss");
      break;
      
    case -3:
    case -86:
      shutdownString = ECLocalizedString(@"Overheating");
      break;
      
    case -60:
      shutdownString = ECLocalizedString(@"Corrupt filesystem");
      break;
    
    case -61:
    case -62:
      shutdownString = ECLocalizedString(@"System unresponsive");
      break;
    
    case -71:
      shutdownString = ECLocalizedString(@"RAM overheating");
      break;
    
    case -74:
      shutdownString = ECLocalizedString(@"Battery overheating");
      break;
    
    case -75:
    case -78:
      shutdownString = ECLocalizedString(@"Power supply failure");
      break;
    
    case -79:
    case -103:
      shutdownString = ECLocalizedString(@"Battery failure");
      break;
    
    case -95:
      shutdownString = ECLocalizedString(@"CPU overheating");
      break;
    
    case -100:
      shutdownString = ECLocalizedString(@"Power supply overheating");
      break;
    }
    
  NSDate * date = [self getShutdownTime];
  
  DiagnosticEvent * event = [DiagnosticEvent new];
  
  event.code = shutdownCause;
  event.date = date;
  event.type = kShutdown;
  event.name =
    [NSString stringWithFormat: @"%d - %@", shutdownCause, shutdownString];
  event.count = 1;
  
  [[self.model diagnosticEvents] setObject: event forKey: event.name];
  
  [event release];
  }

// Get the shutdown time.
- (NSDate *) getShutdownTime
  {
  NSDate * date = nil;
  
  NSArray * args = @[@"kern.boottime"];
  
  SubProcess * subProcess = [[SubProcess alloc] init];
  
  if([subProcess execute: @"/usr/sbin/sysctl" arguments: args])
    {
    NSArray * lines = [Utilities formatLines: subProcess.standardOutput];
    
    for(NSString * line in lines)
      if([line hasPrefix: @"kern.boottime: { sec = "])
        {
        NSString * secondsString = [line substringFromIndex: 23];
        
        NSScanner * scanner = [NSScanner scannerWithString: secondsString];
      
        long long boottime = 0;
      
        if([scanner scanLongLong: & boottime])
          date = [NSDate dateWithTimeIntervalSince1970: boottime];
        }
    }
    
  [subProcess release];
    
  return date;
  }

@end
