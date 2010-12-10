//
//  NSIndexPath+JAListViewExtensions.h
//  JAListView
//
//  Created by Josh Abernathy on 11/26/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSIndexPath (JAListViewExtensions)
+ (NSIndexPath *)indexPathForIndex:(NSUInteger)index inSection:(NSUInteger)section;
+ (NSIndexPath *)indexPathForSection:(NSUInteger)section;

@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, readonly) NSUInteger section;
@end
