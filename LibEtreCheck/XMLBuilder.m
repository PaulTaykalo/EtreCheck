/***********************************************************************
 ** Etresoft, Inc.
 ** Copyright (c) 2015-2018. All rights reserved.
 **********************************************************************/

#import "XMLBuilder.h"

// An XML node.
@interface XMLBuilderNode : NSObject
  {
  XMLBuilderElement * myParent;
  }

// The node's parent.
@property (assign) XMLBuilderElement * parent;

@end

// An XML text node.
@interface XMLBuilderTextNode : XMLBuilderNode
  {
  NSString * myText;
  BOOL myIsCDATA;
  }

// The node's text.
@property (retain) NSString * text;
@property (assign) BOOL isCDATA;

// Constructor.
- (instancetype) initWithText: (NSString *) text;

@end

// Encapsulate each element.
@interface XMLBuilderElement : XMLBuilderNode
  {
  NSString * myName;
  NSMutableDictionary * myAttributes;
  NSMutableArray * myChildren;
  NSMutableArray * myOpenChildren;
  }

// The name of the element.
@property (retain) NSString * name;

// The element's attributes.
@property (retain) NSMutableDictionary * attributes;

// The stack of closed children.
@property (retain) NSMutableArray * children;

// The stack of open children.
@property (retain) NSMutableArray * openChildren;

// Constructor with name and indent.
- (instancetype) initWithName: (NSString *) name;

@end

// An XML node.
@implementation XMLBuilderNode

@synthesize parent = myParent;

// Emit a node as an XML fragment.
- (NSString *) XMLFragment
  {
  // This will never be called. It is just a placeholder for derived
  // children.
  return @"";
  }

@end

// An XML text node.
@implementation XMLBuilderTextNode

@synthesize text = myText;
@synthesize isCDATA = myIsCDATA;

// Constructor.
- (instancetype) initWithText: (NSString *) text
  {
  self = [super init];
  
  if(self != nil)
    {
    NSMutableString * escapedText = [NSMutableString new];
    
    [escapedText appendString: text];
    
    [escapedText 
      replaceOccurrencesOfString: @"&" 
      withString: @"&amp;"
      options: 0
      range: NSMakeRange(0, [escapedText length])];
    
    [escapedText 
      replaceOccurrencesOfString: @">" 
      withString: @"&gt;"
      options: 0
      range: NSMakeRange(0, [escapedText length])];

    [escapedText 
      replaceOccurrencesOfString: @"<" 
      withString: @"&lt;"
      options: 0
      range: NSMakeRange(0, [escapedText length])];

    [escapedText 
      replaceOccurrencesOfString: @"\"" 
      withString: @"&quot;"
      options: 0
      range: NSMakeRange(0, [escapedText length])];

    [escapedText 
      replaceOccurrencesOfString: @"'" 
      withString: @"&apos;"
      options: 0
      range: NSMakeRange(0, [escapedText length])];

    myText = [escapedText copy];
    
    [escapedText release];
    
    NSRange range =
      [myText
        rangeOfCharacterFromSet:
          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      
    if(range.location == 0)
      myIsCDATA = YES;
    
    range =
      [myText
        rangeOfCharacterFromSet:
          [NSCharacterSet whitespaceAndNewlineCharacterSet]
        options: NSBackwardsSearch];

    if(range.location != NSNotFound)
      if(([myText length] - range.location) == range.length)
        myIsCDATA = YES;

    range =
      [myText
        rangeOfCharacterFromSet: [NSCharacterSet newlineCharacterSet]];
    
    if(range.location != NSNotFound)
      myIsCDATA = YES;
      
    return self;
    }
    
  return nil;
  }

// Constructor.
- (instancetype) initWithCDATA: (NSString *) text
  {
  self = [super init];
  
  if(self != nil)
    {
    myText = [text copy];
    
    myIsCDATA = YES;
    
    return self;
    }
    
  return nil;
  }

// Destructor.
- (void) dealloc
  {
  [myText release];
  
  [super dealloc];
  }

// For heterogeneous children.
- (BOOL) isXMLTextNode
  {
  return YES;
  }

// Emit a text node as an XML fragment. The indent is not used for
// a text node.
- (NSString *) XMLFragment
  {
  // If I know this should be CDATA, emit as such.
  if(self.isCDATA)
    return [self XMLFragmentAsCDATA: self.text];
    
  return self.text;
  }

// Emit text as CDATA.
- (NSString *) XMLFragmentAsCDATA: (NSString *) text
  {
  // First see if the text has the CDATA ending tag. If so, that will
  // need to be split out.
  NSRange range = [text rangeOfString: @"]]>"];
  
  NSString * first = text;
  NSString * rest = nil;
  
  if(range.location != NSNotFound)
    {
    first = [text substringToIndex: range.location + 1];
    rest = [text substringFromIndex: range.location + 1];
    }
    
  return
    [NSString
      stringWithFormat:
        @"<![CDATA[%@]]>%@",
        first,
        rest ? [self XMLFragmentAsCDATA: rest] : @""];
  }

@end

// Encapsulate each element.
@implementation XMLBuilderElement

@synthesize name = myName;
@synthesize attributes = myAttributes;
@synthesize children = myChildren;
@synthesize openChildren = myOpenChildren;

// Constructor with name.
- (instancetype) initWithName: (NSString *) name
  {
  self = [super init];
  
  if(self != nil)
    {
    myName = [name copy];
    myAttributes = [NSMutableDictionary new];
    myChildren = [NSMutableArray new];
    myOpenChildren = [NSMutableArray new];
    
    return self;
    }
    
  return nil;
  }

// Constructor.
- (instancetype) init
  {
  self = [super init];
  
  if(self != nil)
    {
    myAttributes = [NSMutableDictionary new];
    myChildren = [NSMutableArray new];
    myOpenChildren = [NSMutableArray new];
    
    return self;
    }
    
  return nil;
  }

// Destructor.
- (void) dealloc
  {
  [myName release];
  [myOpenChildren release];
  [myChildren release];
  [myAttributes release];
  
  [super dealloc];
  }

// For heterogeneous children.
- (BOOL) isXMLElement
  {
  return YES;
  }

// Emit an element as an XML fragment.
- (NSString *) XMLFragment
  {
  NSMutableString * XML = [NSMutableString string];
  
  if(self.parent == nil)
    {
    // Add children.
    [XML appendString: [self XMLFragments: self.children]];
  
    // Add open children.
    [XML appendString: [self XMLFragments: self.openChildren]];
    }
  else
    {
    // Emit the start tag but room for attributes.
    [XML appendFormat: @"%@<%@", [self startingIndent], self.name];
    
    NSArray * sortedAttributes = 
      [self.attributes.allKeys 
        sortedArrayUsingSelector: @selector(compare:)];
    
    // Add any attributes.
    for(NSString * key in sortedAttributes)
      {
      NSString * value = [self.attributes objectForKey: key];
      
      if([value respondsToSelector: @selector(UTF8String)])
        [XML appendFormat: @" %@=\"%@\"", key, value];
      else
        [XML appendFormat: @" %@", key];
      }
    
    // Don't close the opening tag yet. If I don't have any children, I'll
    // just want to make a self-closing tag.
    
    // Emit children - closed or open.
    if(([self.children count] + [self.openChildren count]) > 0)
      {
      // Finish the opening tag.
      [XML appendString: @">"];
      
      // Add children.
      [XML appendString: [self XMLFragments: self.children]];
      
      // Add open children.
      [XML appendString: [self XMLFragments: self.openChildren]];
      
      // Add the closing tag.
      [XML appendFormat: @"%@</%@>", [self endingIndent], self.name];
      }
      
    // I don't have any children, so turn the opening tag into a 
    // self-closing tag.
    else
      [XML appendString: @"/>"];
    }
    
  return XML;
  }

// Get the starting indent.
- (NSString *) startingIndent
  {
  XMLBuilderNode * current = (XMLBuilderNode *)self;
  
  NSMutableString * indent = [NSMutableString string];
  
  int count = 0;
  
  while(current != nil)
    {
    if(count > 1)
      {
      if(count == 2)
        [indent appendString: @"\n"];
        
      [indent appendString: @"  "];
      }
      
    current = current.parent;
    ++count;
    }
    
  if(count == 2)
    [indent appendString: @"\n"];

  return indent;
  }

// Get the ending indent.
- (NSString *) endingIndent
  {
  BOOL onlyTextNodes = YES;
  
  for(XMLBuilderNode * child in self.children)
    if(![child respondsToSelector: @selector(isXMLTextNode)])
      onlyTextNodes = NO;
  
  if(onlyTextNodes)
    return @"";
    
  XMLBuilderNode * current = (XMLBuilderNode *)self;
  
  NSMutableString * indent = [NSMutableString string];
  
  [indent appendString: @"\n"];
  
  int count = 0;
  
  while(current != nil)
    {
    if(count > 1)
      [indent appendString: @"  "];
      
    current = current.parent;
    ++count;
    }
    
  return indent;
  }

// Emit children element as an XML fragment.
- (NSString *) XMLFragments: (NSArray *) children
  {
  NSMutableString * XML = [NSMutableString string];

  for(XMLBuilderNode * child in children)
    [XML appendString: [child XMLFragment]];
    
  return XML;
  }

// Get the last currently open child.
- (XMLBuilderElement *) openChild
  {
  // Walk down through the open children and find the last one.
  XMLBuilderElement * openElement = [self.openChildren lastObject];
  
  XMLBuilderElement * nextOpenElement = openElement;
  
  while(nextOpenElement)
    {
    openElement = nextOpenElement;
    
    nextOpenElement = [nextOpenElement.openChildren lastObject];
    }
    
  return openElement;
  }

@end

// A class for building an XML document.
@implementation XMLBuilder

@dynamic XML;
@synthesize dateFormat = myDateFormat;
@synthesize dayFormat = myDayFormat;
@synthesize dateFormatter = myDateFormatter;
@synthesize dayFormatter = myDayFormatter;
@synthesize root = myRoot;
@synthesize valid = myValid;

// Constructor.
- (instancetype) init
  {
  self = [super init];
  
  if(self != nil)
    {
    myRoot = [XMLBuilderElement new];
    myValid = YES;
    myDateFormat = @"yyyy-MM-dd HH:mm:ss";
    myDayFormat = @"yyyy-MM-dd";
    
    return self;
    }
    
  return nil;
  }

// Destructor.
- (void) dealloc
  {
  [myRoot release];
  [myDateFormatter release];
  [myDayFormatter release];
  
  [super dealloc];
  }

// Return the current state of the builder as XML.
- (NSString *) XML
  {
  NSMutableString * result = [NSMutableString string];
  
  [result appendString: @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"];

  [result appendString: [self.root XMLFragment]];
  
  return result;
  }

// Return the date formatter, creating one, if necessary.
- (NSDateFormatter *) dateFormatter
  {
  if(!myDateFormatter)
    {
    myDateFormatter = [[NSDateFormatter alloc] init];
    
    [myDateFormatter setDateFormat: self.dateFormat];
    [myDateFormatter setTimeZone: [NSTimeZone localTimeZone]];
    [myDateFormatter
      setLocale: [NSLocale localeWithLocaleIdentifier: @"en_US"]];
    }
    
  return myDateFormatter;
  }

// Return the date formatter, creating one, if necessary.
- (NSDateFormatter *) dayFormatter
  {
  if(!myDayFormatter)
    {
    myDayFormatter = [[NSDateFormatter alloc] init];
    
    [myDayFormatter setDateFormat: self.dayFormat];
    [myDayFormatter setTimeZone: [NSTimeZone localTimeZone]];
    [myDayFormatter
      setLocale: [NSLocale localeWithLocaleIdentifier: @"en_US"]];
    }
    
  return myDayFormatter;
  }

// Start a new element.
- (void) startElement: (NSString *) name
  {
  // Validate the name.
  if(![self validName: name])
    {
    NSLog(@"Invalid element name: %@", name);
    self.valid = NO;
    }
    
  // Add the new element onto the end of the last open child.
  XMLBuilderElement * openChild = [self.root openChild];
  
  // If there is no open child, use root.
  if(openChild == nil)
    openChild = self.root;
    
  // Create the element.
  XMLBuilderElement * newChild = 
    [[XMLBuilderElement alloc] initWithName: name];
  
  // Connect it to the parent.
  newChild.parent = openChild;
  
  [openChild.openChildren addObject: newChild];
  
  [newChild release];
  }
  
// Finish the current element.
- (void) endElement: (NSString *) name
  {
  // Find the currently open child.
  XMLBuilderElement * openChild = [self.root openChild];
  
  // There should be at least one.
  if(openChild == nil)
    {
    NSLog(@"Cannot close element %@, No open element.", name);
    self.valid = NO;
    }
  
  // There should be at least one.
  if(openChild.name == nil)
    {
    NSLog(@"Cannot close element %@, Invalid open element.", name);
    self.valid = NO;
    }

  // And it should be the element being closed.
  else if(![name isEqualToString: openChild.name])
    {
    NSLog(  
      @"Cannot close element %@, Current element is %@", 
      name, 
      openChild.name);
    
    self.valid = NO;
    }
    
  // Move the element being closed from its parent's open list to its
  // parent's closed list.
  XMLBuilderElement * parent = openChild.parent;
  
  [parent.children addObject: openChild];
  [parent.openChildren removeLastObject];
  }
  
// Add an empty element with attributes.
- (void) addElement: (NSString *) name 
  attributes: (NSDictionary *) attributes
  {
  [self startElement: name];
  
  for(NSString * key in attributes)
    {
    NSObject * attributeValue = [attributes objectForKey: key];
    
    if([attributeValue respondsToSelector: @selector(UTF8String)])
      [self addAttribute: key value: (NSString *)attributeValue];
    else
      [self addElement: key];
    }

  [self endElement: name];
  }

// Add an empty element.
- (void) addElement: (NSString *) name
  {
  [self startElement: name];
  
  [self endElement: name];
  }

// Add an element, value, and type.
- (void) addElement: (NSString *) name
  value: (NSString *) value attributes: (NSDictionary *) attributes
  {
  if([value respondsToSelector: @selector(UTF8String)])
    {
    if([value length] == 0)
      return;
    }
  else
    return;
    
  [self startElement: name];  
  
  for(NSString * key in attributes)
    {
    NSObject * attributeValue = [attributes objectForKey: key];
    
    if([attributeValue respondsToSelector: @selector(UTF8String)])
      [self addAttribute: key value: (NSString *)attributeValue];
    else
      [self addElement: key];
    }

  [self addString: value];

  [self endElement: name];
  }

// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name value: (NSString *) value
  {
  [self addElement: name value: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name 
  number: (NSNumber *) value attributes: (NSDictionary *) attributes
  {
  if([value respondsToSelector: @selector(doubleValue)])
    {
    if(value == nil)
      return;
    }
  else
    return;

  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"number", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name value: [value stringValue] attributes: fullAttributes];
  
  [fullAttributes release];
  }

// Add an element and value with a convenience function. Parse units out
// of the value and store as a number.
- (void) addElement: (NSString *) name valueWithUnits: (NSString *) value
  {
  if([value respondsToSelector: @selector(UTF8String)])
    {
    if([value length] == 0)
      return;
    }
  else
    return;
    
  NSArray * parts = [value componentsSeparatedByString: @" "];
  
  if([parts count] == 2)
    {
    NSString * unitlessValue = [parts objectAtIndex: 0];
    NSString * units = [parts objectAtIndex: 1];
    
    [self 
      addElement: name 
      value: unitlessValue 
      attributes: 
        [NSDictionary 
          dictionaryWithObjectsAndKeys: 
            @"number", @"type", units, @"units", nil]];
    }
  else  
    [self addElement: name value: value];
  }
  
// Add an element and value with a convenience function. 
- (void) addElement: (NSString *) name 
  valueAsCDATA: (NSString *) value attributes: (NSDictionary *) attributes
  {
  if([value respondsToSelector: @selector(UTF8String)])
    {
    if([value length] == 0)
      return;
    }
  else
    return;
        
  [self startElement: name];  
  
  for(NSString * key in attributes)
    {
    NSObject * attributeValue = [attributes objectForKey: key];
    
    if([attributeValue respondsToSelector: @selector(UTF8String)])
      [self addAttribute: key value: (NSString *)attributeValue];
    else
      [self addElement: key];
    }

  [self addCDATA: value];

  [self endElement: name];
  }
  
- (void) addElement: (NSString *) name valueAsCDATA: (NSString *) value
  {
  [self addElement: name valueAsCDATA: value attributes: nil];
  }
  
// Add an element and potentially invalid value converted to plain ASCII.
- (void) addElement: (NSString *) name safeASCII: (NSString *) value
  {
  // Make sure the string is really UTF8.
  [self 
    addElement: name 
    valueAsCDATA: [self validString: value] 
    attributes: nil];
  }
  
// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name number: (NSNumber *) value
  {
  [self addElement: name number: value attributes: nil];
  }

// Add an element to the current element.
- (void) addElement: (NSString *) name date: (NSDate *) date
  {
  [self
    addElement: name
    value: [self.dateFormatter stringFromDate: date]
    attributes: 
      [NSDictionary 
        dictionaryWithObjectsAndKeys: self.dateFormat, @"format", nil]];
  }

// Add an element to the current element.
- (void) addElement: (NSString *) name day: (NSDate *) day
  {
  [self
    addElement: name
    value: [self.dayFormatter stringFromDate: day]
    attributes: 
      [NSDictionary 
        dictionaryWithObjectsAndKeys: self.dayFormat, @"format", nil]];
  }

// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name url: (NSURL *) value;
  {
  [self 
    addElement: name 
    valueAsCDATA: value.absoluteString
    attributes: 
      [NSDictionary dictionaryWithObjectsAndKeys: @"url", @"type", nil]];
  }
  
// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name boolValue: (BOOL) value;
  {
  [self
    addElement: name 
    value: value ? @"true" : @"false" 
    attributes: 
      [NSDictionary 
        dictionaryWithObjectsAndKeys: @"boolean", @"type", nil]];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name 
  intValue: (int) value attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"integer", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%d", value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }
  
// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name intValue: (int) value
  {
  [self addElement: name intValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name 
  longValue: (long) value attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"long", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%ld", value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }
  
// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name longValue: (long) value
  {
  [self addElement: name longValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name 
  longlongValue: (long long) value attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"longlong", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%lld", value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }
  
// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name longlongValue: (long long) value
  {
  [self addElement: name longlongValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name
  unsignedIntValue: (unsigned int) value 
  attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"unsigned" @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%u", value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }
  
// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name
  unsignedIntValue: (unsigned int) value
  {
  [self addElement: name unsignedIntValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name
  unsignedLongValue: (unsigned long) value 
  attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"unsignedlong", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%lu", value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }
  
// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name
  unsignedLongValue: (unsigned long) value
  {
  [self addElement: name unsignedLongValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name
  unsignedLongLongValue: (unsigned long long) value 
  attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"unsignedlonglong", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%llu", value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }

// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name
  unsignedLongLongValue: (unsigned long long) value
  {
  [self addElement: name unsignedLongLongValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name 
  integerValue: (NSInteger) value attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"long", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%ld", (long)value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }

// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name integerValue: (NSInteger) value
  {
  [self addElement: name integerValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name
  unsignedIntegerValue: (NSUInteger) value 
  attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"unsignedlong", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%lld", (unsigned long long)value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }

// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name
  unsignedIntegerValue: (NSUInteger) value
  {
  [self addElement: name unsignedIntegerValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name 
  floatValue: (float) value attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"float", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%f", value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }

// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name floatValue: (float) value
  {
  [self addElement: name floatValue: value attributes: nil];
  }

// Add an element, value, and attributes with a convenience function.
- (void) addElement: (NSString *) name 
  doubleValue: (double) value attributes: (NSDictionary *) attributes
  {
  NSMutableDictionary * fullAttributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: @"double", @"type", nil];
    
  if(attributes != nil)
    [fullAttributes addEntriesFromDictionary: attributes];
  
  [self 
    addElement: name 
    value: [NSString stringWithFormat: @"%f", value] 
    attributes: fullAttributes];
  
  [fullAttributes release];
  }
  
// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name doubleValue: (double) value
  {
  [self addElement: name doubleValue: value attributes: nil];
  }

// Add an element and value with a convenience function.
- (void) addElement: (NSString *) name UTF8StringValue: (char *) value
  {
  [self addElement: name value: [NSString stringWithFormat: @"%s", value]];
  }

// Add a binary element with type attribute.
- (void) addElement: (NSString *) name 
  type: (NSString *) type data: (NSData *) data
  {
  NSMutableDictionary * attributes =
    [[NSMutableDictionary alloc]
      initWithObjectsAndKeys: type, @"type", @"base64", @"encoding", nil];
    
  [self addElement: name data: data attributes: attributes];

  [attributes release];
  }
  
// Add a binary element with attributes.
- (void) addElement: (NSString *) name 
  data: (NSData *) data attributes: (NSDictionary *) attributes
  {
  NSString * value = nil;
  
  if([data respondsToSelector: @selector(base64EncodedStringWithOptions:)])
    value = 
      [data 
        base64EncodedStringWithOptions: 
          NSDataBase64Encoding64CharacterLineLength 
            | NSDataBase64EncodingEndLineWithLineFeed];
  
  else
    {
    NSString * oneLine = [data base64Encoding];
    
    NSMutableString * multiLine = [NSMutableString new];
    
    NSUInteger start = 0;
    
    while(true)
      {      
      if(oneLine.length <= start)
        break;
        
      NSRange range = NSMakeRange(start, MIN(oneLine.length - start, 64));
      
      [multiLine appendString: [oneLine substringWithRange: range]];
      [multiLine appendString: @"\n"];
      
      start += range.length;
      }
      
    value = [multiLine autorelease];
    }
    
  [self addElement: name value: value attributes: attributes];
  }
  
// Add a boolean to the current element's contents.
- (void) addBool: (BOOL) value
  {
  [self addString: value ? @"true" : @"false"];
  }

// Add a string to the current element's contents.
- (void) addString: (NSString *) string
  {
  if([string respondsToSelector: @selector(UTF8String)])
    {
    if([string length] == 0)
      return;
    }
  else
    return;
    
  // Find the currently open child.
  XMLBuilderElement * openChild = [self.root openChild];
  
  // Make sure there is an open child.
  if(openChild == nil)
    {
    NSLog(@"Cannot add text %@, no open element", string);
    self.valid = NO;
    }

  if(string != nil)
    {
    XMLBuilderTextNode * textNode = 
      [[XMLBuilderTextNode alloc] initWithText: string];
    
    [openChild.children addObject: textNode];
  
    [textNode release];
    }
  }

// Add a CDATA string to the current element's contents.
- (void) addCDATA: (NSString *) string
  {
  if([string respondsToSelector: @selector(UTF8String)])
    {
    if([string length] == 0)
      return;
    }
  else
    return;
    
  // Find the currently open child.
  XMLBuilderElement * openChild = [self.root openChild];
  
  // Make sure there is an open child.
  if(openChild == nil)
    {
    NSLog(@"Cannot add text %@, no open element", string);
    self.valid = NO;
    }

  if(string != nil)
    {
    XMLBuilderTextNode * textNode = 
      [[XMLBuilderTextNode alloc] initWithCDATA: string];
    
    [openChild.children addObject: textNode];
  
    [textNode release];
    }
  }
  
// Add a null attribute.
- (void) addAttribute: (NSString *) name
  {
  // Make sure the name is valid.
  if(![self validName: name])
    {
    NSLog(@"Invalid attribute name: %@", name);
    self.valid = NO;
    }

  // Find the currently open child.
  XMLBuilderElement * openChild = [self.root openChild];

  // Make sure there is an open child.
  if(openChild == nil)
    {
    NSLog(@"Cannot add attribute %@, no open element", name);
    self.valid = NO;
    }

  // Set the value.
  [openChild.attributes setObject: [NSNull null] forKey: name];
  }
  
// Add an attribute to the current element.
- (void) addAttribute: (NSString *) name value: (NSString *) value
  {
  if([value respondsToSelector: @selector(UTF8String)])
    {
    if([value length] == 0)
      return;
    }
  else
    return;
        
  // Make sure the name is valid.
  if(![self validName: name])
    {
    NSLog(@"Invalid attribute name: %@", name);
    self.valid = NO;
    }

  // Make sure the value is valid.
  if(![self validAttributeValue: value])
    {
    NSLog(@"Invalid attribute value: %@", value);
    self.valid = NO;
    }

  // Find the currently open child.
  XMLBuilderElement * openChild = [self.root openChild];

  // Make sure there is an open child.
  if(openChild == nil)
    {
    NSLog(@"Cannot add attribute %@=%@, no open element", name, value);
    self.valid = NO;
    }

  // Set the value.
  [openChild.attributes setObject: value forKey: name];
  }

// Add an attribute to the current element.
- (void) addAttribute: (NSString *) name number: (NSNumber *) value
  {
  [self addAttribute: name value: [value stringValue]];
  }
  
// Add an attribute to the current element.
- (void) addAttribute: (NSString *) name date: (NSDate *) date
  {
  [self
    addAttribute: name value: [self.dateFormatter stringFromDate: date]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name boolValue: (BOOL) value
  {
  [self addAttribute: name value: value ? @"true" : @"false"];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name intValue: (int) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%d", value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name longValue: (long) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%ld", value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name longlongValue: (long long) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%lld", value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name
  unsignedIntValue: (unsigned int) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%d", value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name
  unsignedLongValue: (unsigned long) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%lu", value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name
  unsignedLonglongValue: (unsigned long long) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%llu", value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name integerValue: (NSInteger) value
  {
  [self
    addAttribute: name
    value: [NSString stringWithFormat: @"%ld", (long)value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name
  unsignedIntegerValue: (NSUInteger) value
  {
  [self
    addAttribute: name
    value: [NSString stringWithFormat: @"%lu", (unsigned long)value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name float: (float) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%f", value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name doubleValue: (double) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%f", value]];
  }

// Add an element and value with a convenience function.
- (void) addAttribute: (NSString *) name UTF8StringValue: (char *) value
  {
  [self
    addAttribute: name value: [NSString stringWithFormat: @"%s", value]];
  }

// Add a fragment from another XMLBuilder.
- (void) addFragment: (XMLBuilderElement *) xml
  {
  // Find the currently open child.
  XMLBuilderElement * openChild = [self.root openChild];
  
  // Make sure there is an open child.
  if(openChild == nil)
    {
    NSLog(@"Cannot add fragment %@, no open element", xml);
    self.valid = NO;
    }

  // Don't move the root node.
  if(xml.parent == nil)
    {
    XMLBuilderElement * child = [xml.openChildren lastObject];

    if(child == nil)
      child = [xml.children lastObject];
      
    if(child != nil)
      xml = child;
    }
    
  if(([xml.openChildren count] + [xml.children count]) > 0)
    {
    [openChild.children addObject: xml];
    
    [xml.parent.openChildren removeObject: xml];
    [xml.parent.children removeObject: xml];
    xml.parent = openChild;
    }
  }
  
// Add an array of XML values.
- (void) addArray: (NSString *) name values: (NSArray *) values
  {
  if(values != nil)
    if([values respondsToSelector: @selector(isEqualToArray:)])
      if(values.count > 0)
        {
        [self startElement: name];
      
        for(id<XMLValue> value in values)
          [self addFragment: value.xml];
          
        [self endElement: name];
        }
  }
  
// Add a dictionary of XML values.
- (void) addDictionary: (NSString *) name values: (NSDictionary *) values
  {
  if(values != nil)
    if([values respondsToSelector: @selector(objectForKey:)])
      if(values.count > 0)
        {
        NSArray * sortedKeys = 
          [[values allKeys] sortedArrayUsingSelector: @selector(compare:)];
          
        [self startElement: name];
      
        for(NSObject * key in sortedKeys)
          {
          id<XMLValue> value = [values objectForKey: key];
          
          [self addFragment: value.xml];
          }
          
        [self endElement: name];
        }
  }
  
// MARK: Validation

// Validate a name.
- (BOOL) validName: (NSString *) name
  {
  BOOL valid = YES;
  BOOL first = YES;
  
  NSUInteger length = [name length];
  
  unichar * characters = (unichar *)malloc(sizeof(unichar) * (length + 1));
  unichar * end = characters + length;
  
  [name getCharacters: characters range: NSMakeRange(0, length)];
  
  for(unichar * ch = characters; ch < end; ++ch)
    {
    if(*ch == ':' || *ch == '_')
      continue;
    if(((*ch >= 'A') && (*ch <= 'Z')) || ((*ch >= 'a') && (*ch <= 'z')))
      continue;
    if((*ch >= '0') && (*ch <= '9'))
      continue;
    if((*ch >= L'\u00C0') && (*ch <= L'\u00D6'))
      continue;
    if((*ch == L'\u00D8') || ((*ch >= L'\u00D9') && (*ch <= L'\u00F6')))
      continue;
    if((*ch >= L'\u00F8') && (*ch <= L'\u02FF'))
      continue;
    if((*ch >= L'\u0370') && (*ch <= L'\u037D'))
      continue;
    if((*ch >= L'\u037F') && (*ch <= L'\u1FFF'))
      continue;
    if((*ch >= L'\u200C') && (*ch <= L'\u200D'))
      continue;
    if((*ch >= L'\u2070') && (*ch <= L'\u218F'))
      continue;
    if((*ch >= L'\u2C00') && (*ch <= L'\u2FEF'))
      continue;
    if((*ch >= L'\u3001') && (*ch <= L'\uD7FF'))
      continue;
    if((*ch >= L'\uF900') && (*ch <= L'\uFDCF'))
      continue;
    if((*ch >= L'\uFDF0') && (*ch <= L'\uFFFD'))
      continue;
    //if((*ch >= L'\U00010000') && (*ch <= L'\U000EFFFF'))
    //  continue;
    if(first)
      {
      valid = NO;
      break;
      }
      
    if(![self validiateOtherCharacters: *ch])
      {
      valid = NO;
      break;
      }
      
    first = NO;
    }

  free(characters);
    
  return valid;
  }
  
// Validate other characters in a name.
- (BOOL) validiateOtherCharacters: (unichar) ch
  {
  if(ch == '-')
    return YES;
    
  if(ch == '.')
    return YES;
    
  if((ch >= '0') && (ch <= '9'))
    return YES;
    
  if(ch == L'\u00B7')
    return YES;
    
  if((ch >= L'\u0300') && (ch <= L'\u036F'))
    return YES;
    
  if((ch >= L'\u203F') && (ch <= L'\u2040'))
    return YES;
  
  return NO;
  }
  
// Validate an attribute name.
- (BOOL) validAttributeValue: (NSString *) name
  {
  NSUInteger length = [name length];
  
  unichar * characters = (unichar *)malloc(sizeof(unichar) * (length + 1));
  unichar * end = characters + length;
  
  [name getCharacters: characters range: NSMakeRange(0, length)];
  
  BOOL result = YES;
  
  for(unichar * ch = characters; ch < end; ++ch)
    {
    if(*ch == '<')
      {
      result = NO;
      break;
      }
      
    if(*ch == '&')
      {
      result = NO;
      break;
      }

    if(*ch == '"')
      {
      result = NO;
      break;
      }
    }

  free(characters);

  return result;
  }

// Validate a string.
- (NSString *) validString: (NSString *) string
  {
  NSUInteger length = [string length];
  
  unichar * characters = (unichar *)malloc(sizeof(unichar) * (length + 1));
  unichar * end = characters + length;
  
  [string getCharacters: characters range: NSMakeRange(0, length)];
  
  unichar * output = (unichar *)malloc(sizeof(unichar) * (length + 1));
  unichar * p = output;

  NSCharacterSet * whitespace = [NSCharacterSet whitespaceCharacterSet];
  
  for(unichar * ch = characters; ch < end; ++ch)
    {
    if(((*ch >= 'A') && (*ch <= 'Z')) || ((*ch >= 'a') && (*ch <= 'z')))
      *p++ = *ch;
    else if((*ch >= '0') && (*ch <= '9'))
      *p++ = *ch;
    else if(*ch == ':' || *ch == '_')
      *p++ = *ch;
    else if(*ch == '-' || *ch == '.')
      *p++ = *ch;
    else if(*ch == '~' || *ch == '!' || *ch == '@' || *ch == '#')
      *p++ = *ch;
    else if(*ch == '$' || *ch == '%' || *ch == '^' || *ch == '&')
      *p++ = *ch;
    else if(*ch == '*' || *ch == '(' || *ch == ')' || *ch == '+')
      *p++ = *ch;
    else if(*ch == '=' || *ch == '[' || *ch == ']' || *ch == '?')
      *p++ = *ch;
    else if(*ch == '|' || *ch == '\\' || *ch == '{' || *ch == '}')
      *p++ = *ch;
    else if(*ch == '"' || *ch == '\'' || *ch == '`')
      *p++ = *ch;
    else if(*ch == '/' || *ch == ',' || *ch == ':' || *ch == ';')
      *p++ = *ch;
    else if(*ch == '<' || *ch == '>' || *ch == 13 || *ch == 10)
      *p++ = *ch;
    else if([whitespace characterIsMember: *ch])
      *p++ = *ch;
    else if((*ch >= L'\u00C0') && (*ch <= L'\u00D6'))
      *p++ = *ch;
    else if((*ch == L'\u00D8') || ((*ch >= L'\u00D9') && (*ch <= L'\u00F6')))
      *p++ = *ch;
    else if((*ch >= L'\u00F8') && (*ch <= L'\u02FF'))
      *p++ = *ch;
    else if((*ch >= L'\u0370') && (*ch <= L'\u037D'))
      *p++ = *ch;
    else if((*ch >= L'\u037F') && (*ch <= L'\u1FFF'))
      *p++ = *ch;
    else if((*ch >= L'\u200C') && (*ch <= L'\u200D'))
      *p++ = *ch;
    else if((*ch >= L'\u2070') && (*ch <= L'\u218F'))
      *p++ = *ch;
    else if((*ch >= L'\u2C00') && (*ch <= L'\u2FEF'))
      *p++ = *ch;
    else if((*ch >= L'\u3001') && (*ch <= L'\uD7FF'))
      *p++ = *ch;
    else if((*ch >= L'\uF900') && (*ch <= L'\uFDCF'))
      *p++ = *ch;
    else if((*ch >= L'\uFDF0') && (*ch <= L'\uFFFD'))
      *p++ = *ch;
    else if((*ch >= L'\u0300') && (*ch <= L'\u036F'))
      *p++ = *ch;
    else if((*ch >= L'\u203F') && (*ch <= L'\u2040'))
      *p++ = *ch;
    //if((*ch >= L'\U00010000') && (*ch <= L'\U000EFFFF'))
    //  continue;      
    }

  free(characters);
    
  NSString * valid = 
    [NSString stringWithCharacters: output length: p - output];
  
  free(output);
  
  if(valid == nil)
    return @"";
    
  return valid;
  }

@end
