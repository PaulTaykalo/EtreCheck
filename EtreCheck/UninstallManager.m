/***********************************************************************
 ** Etresoft
 ** John Daniel
 ** Copyright (c) 2016. All rights reserved.
 **********************************************************************/

#import "UninstallManager.h"
#import "LibEtreCheck/LibEtreCheck.h"
#import "CURLRequest.h"
#import "TTTLocalizedPluralString.h"

@implementation UninstallManager

@synthesize window = myWindow;
@synthesize textView = myTextView;
@synthesize tableView = myTableView;
@dynamic canRemoveFiles;
@synthesize filesToRemove = myFilesToRemove;
@synthesize filesRemoved = myFilesRemoved;

- (void) dealloc
  {
  [myWindow release];
  [myTextView release];
  [myTableView release];
  [myFilesToRemove release];
  
  [super dealloc];
  }

// Can I remove files?
- (BOOL) canRemoveFiles
  {
  if([self.filesToRemove count] == 0)
    return NO;
    
  if([[Model model] oldEtreCheckVersion])
    return [self reportOldEtreCheckVersion];
    
  if(![[Model model] verifiedEtreCheckVersion])
    return [self reportUnverifiedEtreCheckVersion];

  if(![[Model model] verifiedSystemVersion])
    return [self reportUnverifiedSystemVersion];

  if(![[Model model] backupExists])
    return [self warnBackup];
    
  if([self needsAdministratorAuthorization])
    return [self requestAdministratorAuthorization];
    
  return YES;
  }

// Show the window.
- (void) show
  {
  }

// Show the window with content.
- (void) show: (NSString *) content
  {
  myFilesToRemove = [NSMutableArray new];
  
  [self.window makeKeyAndOrderFront: self];
  
  NSMutableAttributedString * details = [NSMutableAttributedString new];
  
  [details appendString: content];

  NSData * rtfData =
    [details
      RTFFromRange: NSMakeRange(0, [details length])
      documentAttributes: @{}];

  NSRange range = NSMakeRange(0, [[self.textView textStorage] length]);
  
  [self.textView replaceCharactersInRange: range withRTF: rtfData];
  [self.textView setFont: [NSFont systemFontOfSize: 13]];
  
  [self.textView setEditable: YES];
  [self.textView setEnabledTextCheckingTypes: NSTextCheckingTypeLink];
  [self.textView checkTextInDocument: nil];
  [self.textView setEditable: NO];

  [self.textView scrollRangeToVisible: NSMakeRange(0, 1)];
    
  [details release];
  }

// Close the window.
- (IBAction) close: (id) sender
  {
  if(self.filesRemoved)
    [self suggestRestart];
  
  self.filesToRemove = nil;

  [self.window close];
  }

// Remove the files.
- (IBAction) removeFiles: (id) sender
  {
  [self uninstallItems: self.filesToRemove];
  }

// Uninstall an array of items.
- (void) uninstallItems: (NSMutableArray *) items
  {
  if(![self canRemoveFiles])
    return;
  
  NSMutableArray * launchdFiles = [NSMutableArray new];
  NSMutableArray * safariExtensions = [NSMutableArray new];

  for(NSDictionary * item in items)
    {
    LaunchdFile * file = [item objectForKey: kLaunchdFile];
    
    if(file != nil)
      [launchdFiles addObject: file];
      
    SafariExtension * extension = [item objectForKey: kSafariExtension];
    
    if(extension != nil) 
      [safariExtensions addObject: extension];
    }
  
  [self reportFiles];
  //[Utilities uninstallLaunchdTasks: launchdFiles];
  //[Utilities deleteFiles: safariExtensions];
  
  [launchdFiles release];
  [safariExtensions release];
  
  [self verifyRemoveFiles: items];
  }

// Tell the user that EtreCheck is too old.
- (BOOL) reportOldEtreCheckVersion
  {
  NSAlert * alert = [[NSAlert alloc] init];

  [alert
    setMessageText:
      NSLocalizedString(@"Outdated EtreCheck version!", NULL)];
    
  [alert setAlertStyle: NSWarningAlertStyle];

  [alert
    setInformativeText: NSLocalizedString(@"oldetrecheckversion", NULL)];

  // This is the rightmost, first, default button.
  [alert addButtonWithTitle: NSLocalizedString(@"OK", NULL)];

  [alert runModal];

  [alert release];

  return NO;
  }

// Tell the user that the EtreCheck version is unverified.
- (BOOL) reportUnverifiedEtreCheckVersion
  {
  NSAlert * alert = [[NSAlert alloc] init];

  [alert
    setMessageText:
      NSLocalizedString(@"Unverified EtreCheck version!", NULL)];
    
  [alert setAlertStyle: NSWarningAlertStyle];

  [alert
    setInformativeText:
      NSLocalizedString(@"unverifiedetrecheckversion", NULL)];

  // This is the rightmost, first, default button.
  [alert addButtonWithTitle: NSLocalizedString(@"OK", NULL)];

  [alert runModal];

  [alert release];

  return NO;
  }

// Tell the user that the system version is unverified.
- (BOOL) reportUnverifiedSystemVersion
  {
  NSAlert * alert = [[NSAlert alloc] init];

  [alert
    setMessageText:
      NSLocalizedString(@"Unverified macOS version!", NULL)];
    
  [alert setAlertStyle: NSWarningAlertStyle];

  [alert
    setInformativeText:
      NSLocalizedString(@"unverifiedsystemversion", NULL)];

  // This is the rightmost, first, default button.
  [alert addButtonWithTitle: NSLocalizedString(@"OK", NULL)];

  [alert runModal];

  [alert release];

  return NO;
  }

// Warn the user to make a backup.
- (BOOL) warnBackup
  {
  NSAlert * alert = [[NSAlert alloc] init];

  [alert
    setMessageText:
      NSLocalizedString(@"Cannot verify Time Machine backup!", NULL)];
    
  [alert setAlertStyle: NSWarningAlertStyle];

  [alert
    setInformativeText:
      NSLocalizedString(@"cannotverifytimemachinebackup", NULL)];

  // This is the rightmost, first, default button.
  [alert addButtonWithTitle: NSLocalizedString(@"Cancel", NULL)];

  [alert
    addButtonWithTitle: NSLocalizedString(@"Continue", NULL)];

  NSInteger result = [alert runModal];

  [alert release];

  return (result == NSAlertSecondButtonReturn);
  }

- (BOOL) needsAdministratorAuthorization
  {
  for(NSDictionary * info in self.filesToRemove)
    {
    NSString * path = [info objectForKey: kPath];
    
    if(path != nil)
      if(![[NSFileManager defaultManager] isDeletableFileAtPath: path])
        return YES;
    }
    
  return NO;
  }

- (BOOL) requestAdministratorAuthorization
  {
  NSAlert * alert = [[NSAlert alloc] init];

  [alert setMessageText: NSLocalizedString(@"Password required!", NULL)];
    
  [alert setAlertStyle: NSWarningAlertStyle];

  NSString * message = NSLocalizedString(@"passwordrequired", NULL);
  
  [alert setInformativeText: message];

  // This is the rightmost, first, default button.
  [alert addButtonWithTitle: NSLocalizedString(@"Yes", NULL)];

  [alert addButtonWithTitle: NSLocalizedString(@"No", NULL)];

  NSInteger result = [alert runModal];

  [alert release];

  return (result == NSAlertFirstButtonReturn);
  }

// Verify removal of files.
- (void) verifyRemoveFiles: (NSMutableArray *) files
  {
  NSMutableArray * filesRemoved = [NSMutableArray new];
  NSMutableArray * filesRemaining = [NSMutableArray new];
    
  for(NSMutableDictionary * item in files)
    {
    NSString * path = [item objectForKey: kPath];
    
    if([path length])
      {
      BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: path];
      
      if(exists)
        [filesRemaining addObject: item];
      
      else
        {
        [item
          setObject: [NSNumber numberWithBool: YES] forKey: kFileDeleted];
        
        [filesRemoved addObject: path];
        
        LaunchdFile * file = [item objectForKey: kLaunchdFile];
        
        if(file != nil)
          [[[[Model model] launchd] adwareFiles] removeObject: file];
          
        SafariExtension * extension = [item objectForKey: kSafariExtension];
        
        if(extension != nil)
          [[[[Model model] safari] adwareExtensions] 
            removeObject: extension];
        }
      }
    }
    
  if([filesRemaining count] > 0)
    [self reportDeletedFilesFailed: filesRemoved];
  else
    [self reportDeletedFiles: filesRemoved];

  [filesRemoved release];
  
  [files setArray: filesRemaining];
  
  [filesRemaining release];
  }

// Report the files.
- (void) reportFiles
  {
  /* NSMutableString * json = [NSMutableString string];
  
  [json appendString: @"{\"action\":\"addtoblacklist\","];
  [json appendString: @"\"files\":["];
  
  bool first = YES;
  
  for(NSDictionary * item in self.filesToRemove)
    {
    NSString * path = [item objectForKey: kPath];
    
    if([path length])
      {
      NSDictionary * info = [item objectForKey: kLaunchdFile];
      
      NSArray * command =
        [path length] > 0
          ? [info objectForKey: kCommand]
          : nil;
      
      NSString * cmd =
        [command count] > 0
          ? [command componentsJoinedByString: @" "]
          : @"";
        
      if([[info objectForKey: kAdware] boolValue])
        cmd = [cmd stringByAppendingString: @" ==adware=="];
      else
        {
        NSString * signature = [info objectForKey: kSignature];
      
        if([signature length] > 0)
          cmd = [cmd stringByAppendingFormat: @" ==%@==", signature];
        }
        
      path =
        [path stringByReplacingOccurrencesOfString: @"\"" withString: @"'"];
        
      NSString * name = [path lastPathComponent];
      
      if(!first)
        [json appendString: @","];
        
      first = NO;
      
      [json appendString: @"{"];
      
      [json appendFormat: @"\"name\":\"%@\",", name];
      [json appendFormat: @"\"path\":\"%@\",", path];
      [json appendFormat: @"\"cmd\":\"%@\"", cmd];
      
      [json appendString: @"}"];
      }
    }
    
  [json appendString: @"]}"];
  
  POST * request =
    [[POST alloc]
      init:
        [Utilities
          buildSecureURLString:
            @"etrecheck.com/server/adware_detection.php"]];

  dispatch_async(
    dispatch_get_global_queue(
      DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
      ^{
        [request send: json];
        [request release];
      }); */
  }

// Suggest a restart.
- (void) suggestRestart
  {
  NSAlert * alert = [[NSAlert alloc] init];

  [alert
    setMessageText: NSLocalizedString(@"Restart recommended", NULL)];
    
  [alert setAlertStyle: NSInformationalAlertStyle];

  NSString * message = NSLocalizedString(@"restartrecommended", NULL);
  
  [alert setInformativeText: message];

  // This is the rightmost, first, default button.
  [alert addButtonWithTitle: NSLocalizedString(@"Restart", NULL)];

  [alert addButtonWithTitle: NSLocalizedString(@"Restart later", NULL)];

  NSInteger result = [alert runModal];

  [alert release];

  if(result == NSAlertFirstButtonReturn)
    {
    if(![Actions restart])
      [self restartFailed];
    }
  }

// Restart failed.
- (void) restartFailed
  {
  NSAlert * alert = [[NSAlert alloc] init];

  [alert setMessageText: NSLocalizedString(@"Restart failed", NULL)];
    
  [alert setAlertStyle: NSWarningAlertStyle];

  [alert setInformativeText: NSLocalizedString(@"restartfailed", NULL)];

  // This is the rightmost, first, default button.
  [alert addButtonWithTitle: NSLocalizedString(@"OK", NULL)];
  
  [alert runModal];

  [alert release];
  }

// Report which files were deleted.
- (void) reportDeletedFiles: (NSArray *) filesRemoved
  {
  NSAlert * alert = [[NSAlert alloc] init];

  [alert
    setMessageText:
      TTTLocalizedPluralString(
        [filesRemoved count], @"file deleted", NULL)];
    
  [alert setAlertStyle: NSInformationalAlertStyle];

  NSMutableString * message = [NSMutableString string];
  
  [message appendString: NSLocalizedString(@"filesdeleted", NULL)];
  
  for(NSString * path in filesRemoved)
    [message appendFormat: @"%@\n", path];
    
  [alert setInformativeText: message];

  [alert runModal];
  
  [alert release];
  }

// Report which files were deleted.
- (void) reportDeletedFilesFailed: (NSArray *) filesRemoved
  {
  NSUInteger count = [filesRemoved count];
  
  NSAlert * alert = [[NSAlert alloc] init];

  [alert
    setMessageText: TTTLocalizedPluralString(count, @"file deleted", NULL)];
    
  [alert setAlertStyle: NSWarningAlertStyle];

  NSMutableString * message = [NSMutableString string];
  
  if(count == 0)
    {
    [message appendString: NSLocalizedString(@"nofilesdeleted", NULL)];

    [alert setInformativeText: message];
    
    [alert runModal];
    }
  else
    {
    [message appendString: NSLocalizedString(@"filesdeleted", NULL)];
  
    for(NSString * path in filesRemoved)
      [message appendFormat: @"%@\n", path];
      
    [message appendString: NSLocalizedString(@"filesdeletedfailed", NULL)];
    
    [alert setInformativeText: message];

    [alert runModal];
    }

  [alert release];
  }

// Disable a single launchd file.
- (void) disableFile: (NSString *) file
  {
  NSString * homeDirectory = NSHomeDirectory();
  
  NSString * path = [file stringByExpandingTildeInPath];
  
  if(![path hasPrefix: homeDirectory])
    [self launchdctlInUserSpace: @"unload" path: path];
  else
    [self launchdctl: @"unload" path: path];
  }
  
// Enable a single launchd file.
- (void) enableFile: (NSString *) file
  {
  NSString * homeDirectory = NSHomeDirectory();
  
  NSString * path = [file stringByExpandingTildeInPath];
  
  if(![path hasPrefix: homeDirectory])
    [self launchdctlInUserSpace: @"load" path: path];
  else
    [self launchdctl: @"load" path: path];
  }
  
// Load launchd tasks in userspace.
- (void) launchdctlInUserSpace: (NSString *) action path: (NSString *) path
  {
  NSMutableArray * args = [NSMutableArray array];
  
  [args addObject: action];
  [args addObject: @"-wF"];
  [args addObject: path];
  
  if([args count] > 1)
    {
    SubProcess * launchctl = [[SubProcess alloc] init];

    [launchctl execute: @"/bin/launchctl" arguments: args];

    [launchctl release];
    }
  }

// Load launchd tasks in userspace.
- (void) launchdctl: (NSString *) action path: (NSString *) path
  {
  NSString * command =
    [NSString stringWithFormat: @"/bin/launchctl %@ -wF %@", action, path];

  NSMutableArray * args = [NSMutableArray array];
  
  [args addObject: @"-e"];
  [args addObject: 
    [NSString
      stringWithFormat:
        @"do shell script(\"%@\") with administrator privileges",
        command]];
    
  SubProcess * subProcess = [[SubProcess alloc] init];

  [subProcess execute: @"/usr/bin/osascript" arguments: args];

  [subProcess release];
  }

// Filter out any tasks that are in the user's home directory.
+ (NSArray *) rootLaunchdTasks: (NSArray *) tasks
  {
  NSString * homeDirectory = NSHomeDirectory();
  
  NSMutableArray * rootTasks = [NSMutableArray array];
  
  for(NSDictionary * info in tasks)
    {
    // Try to unload with any other status, including failed.
    NSString * path = [info objectForKey: kPath];
    
    // Make sure the path is rooted in the user's home directory.
    // This will also guarantee its validity.
    if(![path hasPrefix: homeDirectory])
      [rootTasks addObject: info];
    }
    
  return rootTasks;
  }
  
@end
