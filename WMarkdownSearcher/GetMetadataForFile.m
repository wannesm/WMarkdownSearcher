//
//  GetMetadataForFile.m
//  WMarkdownSearcher
//
//  Indexes a Markdown file and (naively) parses the YAML frontmatter.
//
//  Supported YAML keys:
//  - title
//  - keywords, tags (split on comma)
//  - project, projects
//  - attendees, participants
//  - date (parses using NSDataDetector)
//
//  Values:
//  Fields can be a single line after the key or multiple lines all starting with a hyphen.
//
//  Testing:
//      mdimport -L
//      mdimport -d2 test.md
//      mdimport -n -d2 -g /Library/Spotlight/WMarkdownSearcher.mdimporter test.md
//
//  https://www.objc.io/issues/9-strings/string-parsing/
//
//
//  Created by Wannes Meert on 24/04/16.
//  Copyright © 2016 Wannes Meert. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#import <CoreData/CoreData.h>

void ParseFrontmatter(NSString *frontmatter, CFMutableDictionaryRef attributes);
Boolean ParseField(NSString *line, NSString **key, NSArray **values, CFMutableDictionaryRef attributes);
Boolean SaveField(NSString *key, NSArray *values, CFMutableDictionaryRef attributes);
Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile);

//==============================================================================
//
//	Get metadata attributes from document files
//
//	The purpose of this function is to extract useful information from the
//	file formats for your document, and set the values into the attribute
//  dictionary for Spotlight to include.
//
//==============================================================================

void ParseFrontmatter(NSString *frontmatter, CFMutableDictionaryRef attributes) {
    NSArray *lines = [frontmatter componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
//    NSInteger length = [lines count];
    NSString *key;
    NSMutableArray *values = [NSMutableArray array];
    for (NSString *line in lines) {
        if (!ParseField(line, &key, &values, attributes)) {
            return;
        }
    }
    SaveField(key, values, attributes);
}

Boolean ParseField(NSString *line, NSString **key, NSMutableArray **values, CFMutableDictionaryRef attributes) {
    NSScanner *scanner = [NSScanner scannerWithString:line];
    NSString *currentLine = nil;
    
    NSCharacterSet *setIdentifierChars = [NSCharacterSet characterSetWithCharactersInString:@":-"];
    NSMutableCharacterSet *trimChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"-:"];
    [trimChars formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    while (![scanner isAtEnd]) {
        if([scanner scanUpToCharactersFromSet:setIdentifierChars intoString:&currentLine]) {
            if ([scanner scanLocation] == [line length]) {
                // Not recognized, exit
                return false;
            }
            NSString *last = [line substringWithRange:NSMakeRange([scanner scanLocation], 1)];
            if ([last isEqualToString:@":"]) {
                // It is a field definition
                SaveField(*key, *values, attributes);
                *key = [currentLine stringByTrimmingCharactersInSet:trimChars];
                *values = [NSMutableArray array];
            } else if ([last isEqualToString:@"-"]) {
                // It is a list
            }
        }
       
        if([scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&currentLine]) {
            NSString *value = [currentLine stringByTrimmingCharactersInSet:trimChars];
            if (![value isEqualToString:@""]) {
                [*values addObject:value];
            }
        }
    }
    return true;
}

Boolean SaveField(NSString *key, NSMutableArray *values, CFMutableDictionaryRef attributes) {
    if (key == NULL) {
        return false;
    }
    key = [key lowercaseString];
    NSObject *value;
    NSMutableArray *forKeys = [NSMutableArray array];
    NSMutableArray* new_values;
    if ([key isEqualToString:@"title"]) {
        [forKeys addObject:(NSString *)kMDItemTitle];
        [forKeys addObject:(NSString *)kMDItemSubject];
        [forKeys addObject:(NSString *)kMDItemDisplayName];
        value = [values objectAtIndex:0];
    } else if ([key isEqualToString:@"keywords"] || [key isEqualToString:@"tags"]) {
        [forKeys addObject:(NSString *)kMDItemKeywords];
        new_values = [NSMutableArray array];
        for (NSString *old_value in values) {
            // Split all entries on comma
            for (NSString *old_value_i in [old_value componentsSeparatedByString:@","]) {
                [new_values addObject:[old_value_i stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            }
        }
        value = new_values;
    } else if ([key isEqualToString:@"project"] || [key isEqualToString:@"projects"]) {
        [forKeys addObject:(NSString *)kMDItemProjects];
        value = values;
    } else if ([key isEqualToString:@"attendees"] || [key isEqualToString:@"participants"]) {
        [forKeys addObject:(NSString *)kMDItemParticipants];
        value = values;
    } else if ([key isEqualToString:@"date"]) {
        [forKeys addObject:(NSString *)kMDItemDueDate];
        [forKeys addObject:(NSString *)kMDItemContentCreationDate];
        // Parse the string to a date object
        NSError *error = nil;
        NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate
                                                                   error:&error];
        NSArray *matches = [detector matchesInString:[values objectAtIndex:0]
                                             options:0
                                               range:NSMakeRange(0, [[values objectAtIndex:0] length])];
        if (error != nil) {
            NSLog(@"Data detector error: %@", error);
        }
        if ([matches count] > 0) {
            NSTextCheckingResult *result = [matches objectAtIndex:0];
            value = [result.date copy];
        }
    } else {
        return false;
    }
    for (NSString *forKey in forKeys) {
        [(__bridge NSMutableDictionary *)attributes setObject:value
                                                       forKey:forKey];
    }
    return true;
}

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile)
{
    // Pull any available metadata from the file at the specified path
    // Return the attribute keys and attribute values in the dict
    // Return TRUE if successful, FALSE if there was no data provided
	// The path could point to either a Core Data store file in which
	// case we import the store's metadata, or it could point to a Core
	// Data external record file for a specific record instances

    Boolean ok = FALSE;
    @autoreleasepool {
        NSError *error = nil;
//        NSLog(@"UTI: %@", contentTypeUTI);
//        NSLog(@"Starting Wannesm Note importer for %@", pathToFile);
        NSURL *url = [NSURL fileURLWithPath:(__bridge NSString *)pathToFile];
        NSString *note = [[NSString alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        if (note) {
            NSScanner *scanner = [NSScanner scannerWithString:note];
            NSString *line;
            
            // Check YAML frontmatter
            [scanner scanUpToString:@"\n" intoString:&line];
            if ([line isEqualToString:@"---"]) {
                if ([scanner scanUpToString:@"---" intoString:&line]) {
                    ParseFrontmatter(line, attributes);
                }
            } else {
                [scanner setScanLocation:0];
            }
            
            // Search for title
            if ([scanner scanUpToString:@"# " intoString:&line] && ![scanner isAtEnd]) {
                [scanner scanString:@"# " intoString:&line];
                [scanner scanUpToString:@"\n" intoString:&line];
                NSArray *values = @[line];
                SaveField(@"title", values, attributes);
            }
            
            // Store entire note
            ((__bridge NSMutableDictionary *)attributes)[(NSString *)kMDItemTextContent] = note;
            ok = YES;
        }
    }
    return ok;
}
