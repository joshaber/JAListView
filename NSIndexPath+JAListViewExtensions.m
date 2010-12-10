//
//  NSIndexPath+JAListViewExtensions.m
//  JAListView
//
//  Created by Josh Abernathy on 11/26/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "NSIndexPath+JAListViewExtensions.h"


@implementation NSIndexPath (JAListViewExtensions)

+ (NSIndexPath *)indexPathForIndex:(NSUInteger)index inSection:(NSUInteger)section {
    NSUInteger indices[2];
    indices[0] = section;
    indices[1] = index;
    return [NSIndexPath indexPathWithIndexes:indices length:2];
}

+ (NSIndexPath *)indexPathForSection:(NSUInteger)section {
    return [NSIndexPath indexPathWithIndex:section];
}

- (NSUInteger)index {
    return [self indexAtPosition:1];
}

- (NSUInteger)section {
    return [self indexAtPosition:0];
}

@end
