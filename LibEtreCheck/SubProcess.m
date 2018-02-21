/***********************************************************************
 ** Etresoft
 ** John Daniel
 ** Copyright (c) 2016. All rights reserved.
 **********************************************************************/

#import "SubProcess.h"
#import <unistd.h>
#import <spawn.h>
#import <sys/select.h>
#import <crt_externs.h>

@implementation SubProcess

// Did the task time out?
@synthesize timedout = myTimedout;

// The task timeout.
@synthesize timeout = myTimeout;
  
// The task result.
@synthesize result = myResult;
  
// Standard output.
@synthesize standardOutput = myStandardOutput;
  
// Standard error.
@synthesize standardError = myStandardError;

// Does the task need a tty?
@synthesize usePseudoTerminal = myUsePseudoTerminal;

// Debug data to stuff into standard output.
@synthesize debugStandardOutput = myDebugStandardOutput;

// Debug data to stuff into standard error.
@synthesize debugStandardError = myDebugStandardError;

// Path to save debug output.
@synthesize debugOutputPath = myDebugOutputPath;

// Constructor.
- (instancetype) init
  {
  if(self = [super init])
    {
    myTimeout = 30;
    
    myStandardOutput = [NSMutableData new];
    myStandardError = [NSMutableData new];
  
    return self;
    }
    
  return nil;
  }

// Deallocate.
- (void) dealloc
  {
  [myDebugStandardOutput release];
  [myDebugStandardError release];
  [myStandardOutput release];
  [myStandardError release];
  [myDebugOutputPath release];
  
  [super dealloc];
  }

// Execute an external program and return the results.
- (BOOL) execute: (NSString *) program arguments: (NSArray *) args
  {
  if((self.debugStandardOutput != nil) || (self.debugStandardError != nil))
    {
    if(self.debugStandardOutput != nil)
      [self.standardOutput appendData: self.debugStandardOutput];
    
    if(self.debugStandardError != nil)
      [self.standardError appendData: self.debugStandardError];
    
    return YES;
    }
    
  BOOL success = NO;
  
  struct sigaction sa;
  
  sa.sa_handler = SIG_IGN;
  
  sigemptyset(& sa.sa_mask);
  
  sa.sa_flags = 0;
  
  sigaction(SIGCHLD, & sa, 0);
  
  if(self.usePseudoTerminal)
    success = [self forkpty: program arguments: args];
  else
    success = [self fork: program arguments: args];
    
  if(success)
    if(self.debugOutputPath.length > 0)
      {
      NSString * outputPath = 
        [self.debugOutputPath stringByAppendingPathExtension: @"out"];
      
      NSString * errorPath = 
        [self.debugOutputPath stringByAppendingPathExtension: @"err"];
        
      if(self.standardOutput.length > 0)
        [self.standardOutput writeToFile: outputPath atomically: NO];

      if(self.standardError.length > 0)
        [self.standardError writeToFile: errorPath atomically: NO];
      }
    
  return success;
  }

// Load debug information.
- (void) loadDebugOutput: (NSString *) path
  {
  NSString * outputPath = [path stringByAppendingPathExtension: @"out"];
  NSString * errorPath = [path stringByAppendingPathExtension: @"err"];
  
  if([[NSFileManager defaultManager] fileExistsAtPath: outputPath])
    {
    NSData * data = [[NSData alloc] initWithContentsOfFile: outputPath];
    
    self.debugStandardOutput = data;
    
    [data release];
    }

  if([[NSFileManager defaultManager] fileExistsAtPath: errorPath])
    {
    NSData * data = [[NSData alloc] initWithContentsOfFile: errorPath];
    
    self.debugStandardError = data;
    
    [data release];
    }
  }
  
// Save debug information.
- (void) saveDebugOutput: (NSString *) path
  {
  self.debugOutputPath = path;
  }
  
// Execute an external program, use a pseudo-terminal, and return the
// results.
- (BOOL) forkpty: (NSString *) program arguments: (NSArray *) args
  {
  const char * path = [program fileSystemRepresentation];
  
  NSRange range = NSMakeRange(0, [args count]);
  
  const char ** argv = malloc(sizeof(char *) * (range.length + 2));
 
  NSUInteger i = 0;
  
  argv[i++] = path;
  
  for(NSString * arg in args)
    argv[i++] = [arg UTF8String];
    
  argv[i] = 0;
  
  // Open the master side of the pseudo-terminal.
  int master = posix_openpt(O_RDWR);
  
  if(master < 0)
    {
    free(argv);

    return NO;
    }
    
  int rc = grantpt(master);
  
  if(rc != 0)
    {
    close(master);
    free(argv);

    return NO;
    }
    
  rc = unlockpt(master);
  
  if(rc != 0)
    {
    close(master);
    free(argv);

    return NO;
    }

  // Open the slave side ot the pseudo-terminal
  char * device = ptsname(master);
  
  if(device == NULL)
    {
    close(master);
    free(argv);

    return NO;
    }
    
  int slave = open(device, O_RDWR);
  
  if(slave == -1)
    {
    close(master);
    free(argv);

    return NO;
    }
    
  pid_t pid;
  
  posix_spawn_file_actions_t child_fd_actions;
  
  int error = posix_spawn_file_actions_init(& child_fd_actions);
  
  if(error)
    {
    close(master);
    free(argv);

    return NO;
    }

  error =
    posix_spawn_file_actions_addclose(& child_fd_actions, master);

  if(error)
    {
    close(master);
    free(argv);

    return NO;
    }

  error =
    posix_spawn_file_actions_adddup2(
      & child_fd_actions, slave, STDOUT_FILENO);
  
  if(error)
    {
    close(master);
    free(argv);
    
    return NO;
    }

  error =
    posix_spawn(
      & pid,
      path,
      & child_fd_actions,
      NULL,
      (char * const *)argv, *_NSGetEnviron());
  
  if(error)
    {
    close(master);
    close(slave);

    free(argv);
  
    return NO;
    }
  
  free(argv);
  
  close(slave);

  fcntl(master, F_SETFL, O_NONBLOCK);

  fd_set fds;
  int nfds = 0;
    
  size_t bufferSize = 65536;
  char * buffer = (char *)malloc(bufferSize);
  
  bool stdoutOpen = YES;
  
  while(stdoutOpen)
    {
    FD_ZERO(& fds);
    
    if(stdoutOpen)
      {
      FD_SET(master, & fds);
      
      nfds = master + 1;
      }
      
    struct timeval tv;

    tv.tv_sec = myTimeout;
    tv.tv_usec = 0;

    int result = select(nfds, & fds, NULL, NULL, & tv);

    if((result == -1) && (errno != EINTR))
      break;
      
    else if(result == 0)
      {
      myTimedout = YES;
      break;
      }
      
    else
      {
      if(FD_ISSET(master, & fds))
        {
        ssize_t amount = read(master, buffer, bufferSize);
        
        if(amount < 1)
          stdoutOpen = NO;
        else
          [myStandardOutput appendBytes: buffer length: amount];
        }
      }
    }
    
  close(master);

  free(buffer);
      
  posix_spawn_file_actions_destroy(& child_fd_actions);

  return !self.timedout;
  }

// Execute an external program and return the results.
- (BOOL) fork: (NSString *) program arguments: (NSArray *) args
  {
  const char * path = [program fileSystemRepresentation];
  
  NSRange range = NSMakeRange(0, [args count]);
  
  const char ** argv = malloc(sizeof(char *) * (range.length + 2));
 
  NSUInteger i = 0;
  
  argv[i++] = path;
  
  for(NSString * arg in args)
    argv[i++] = [arg UTF8String];
    
  argv[i] = 0;
  
  int outputPipe[2];
  int errorPipe[2];
  
  if(pipe(outputPipe) == -1)
    return NO;
    
  if(pipe(errorPipe) == -1)
    {
    close(outputPipe[0]);
    close(outputPipe[1]);

    return NO;
    }
    
  pid_t pid = 0;
  
  posix_spawn_file_actions_t child_fd_actions;
  
  int error = error = posix_spawn_file_actions_init(& child_fd_actions);
  
  if(!error)
    error =
      posix_spawn_file_actions_addclose(& child_fd_actions, outputPipe[0]);
  
  if(!error)
    error =
      posix_spawn_file_actions_addclose(& child_fd_actions, errorPipe[0]);

  if(!error)
    error =
      posix_spawn_file_actions_adddup2(
        & child_fd_actions, outputPipe[1], STDOUT_FILENO);
  
  if(!error)
    error =
      posix_spawn_file_actions_adddup2(
        & child_fd_actions, errorPipe[1], STDERR_FILENO);
  
  if(!error)
    error =
      posix_spawn(
        & pid,
        path,
        & child_fd_actions,
        NULL,
        (char * const *)argv, *_NSGetEnviron());
  
  if(error)
    {
    close(outputPipe[0]);
    close(outputPipe[1]);

    close(errorPipe[0]);
    close(errorPipe[1]);

    free(argv);
  
    return NO;
    }
  
  free(argv);
  
  close(outputPipe[1]);
  close(errorPipe[1]);

  fcntl(outputPipe[0], F_SETFL, O_NONBLOCK);
  fcntl(errorPipe[0], F_SETFL, O_NONBLOCK);

  fd_set fds;
  int nfds = 0;
    
  size_t bufferSize = 65536;
  char * buffer = (char *)malloc(bufferSize);
  
  bool stdoutOpen = YES;
  bool stderrOpen = YES;
  
  while(stdoutOpen || stderrOpen)
    {
    FD_ZERO(& fds);
    
    if(stdoutOpen)
      {
      FD_SET(outputPipe[0], & fds);
      
      nfds = outputPipe[0] + 1;
      }
      
    if(stderrOpen)
      {
      FD_SET(errorPipe[0], & fds);
      
      if(stdoutOpen && (outputPipe[0] > errorPipe[0]))
        nfds = outputPipe[0] + 1;
      else
        nfds = errorPipe[0] + 1;
      }
    
    struct timeval tv;

    tv.tv_sec = myTimeout;
    tv.tv_usec = 0;

    int result = select(nfds, & fds, NULL, NULL, & tv);

    if((result == -1) && (errno != EINTR))
      break;
      
    else if(result == 0)
      {
      myTimedout = YES;
      break;
      }
      
    else
      {
      if(FD_ISSET(outputPipe[0], & fds))
        {
        ssize_t amount = read(outputPipe[0], buffer, bufferSize);
        
        if(amount < 0)
          stdoutOpen = NO;
        else if(amount < 1)
          stdoutOpen = NO;
        else
          [myStandardOutput appendBytes: buffer length: amount];
        }
        
      if(FD_ISSET(errorPipe[0], & fds))
        {
        ssize_t amount = read(errorPipe[0], buffer, bufferSize);
        
        if(amount < 0)
          stderrOpen = NO;
        else if(amount < 1)
          stderrOpen = NO;
        else
          [myStandardError appendBytes: buffer length: amount];
        }
      }
    }
    
  close(outputPipe[0]);
  close(errorPipe[0]);

  free(buffer);
  
  posix_spawn_file_actions_destroy(& child_fd_actions);

  return !self.timedout;
  }

@end
