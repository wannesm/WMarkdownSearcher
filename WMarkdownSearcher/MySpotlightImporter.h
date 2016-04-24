//
//  MySpotlightImporter.h
//  WMarkdownSearcher
//
//  Created by Wannes Meert on 24/04/16.
//  Copyright © 2016 Wannes Meert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define YOUR_STORE_TYPE NSXMLStoreType

@interface MySpotlightImporter : NSObject

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (BOOL)importFileAtPath:(NSString *)filePath attributes:(NSMutableDictionary *)attributes error:(NSError **)error;

@end
