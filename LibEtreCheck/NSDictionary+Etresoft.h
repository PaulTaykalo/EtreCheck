/***********************************************************************
 ** Etresoft, Inc.
 ** John Daniel
 ** Copyright (c) 2012-2017. All rights reserved.
 **********************************************************************/

#import <Foundation/Foundation.h>

@interface NSDictionary (Etresoft)

// Read from a property list file or data and make sure it is a dictionary.
+ (NSDictionary *) readPropertyList: (NSString *) path;
+ (NSDictionary *) readPropertyListData: (NSData *) data;

// Is this a valid object?
+ (BOOL) isValid: (NSDictionary *) dictionary;

@end