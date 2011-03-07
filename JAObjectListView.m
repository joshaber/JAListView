//
//  JAObjectListView.m
//  JAListView
//
//  Created by Josh Abernathy on 12/6/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "JAObjectListView.h"
#import "JAObjectListViewItem.h"

@interface JAListView (Private)
- (NSArray *)cachedViews;
@end

@interface JAObjectListView ()
- (void)reallyAddListViewItem:(JAObjectListViewItem *)view inSection:(NSUInteger)section atIndex:(NSUInteger)index;

@property (nonatomic, retain) NSMutableArray *sectionRowViews;
@end


@implementation JAObjectListView

- (void)dealloc {
    self.sectionRowViews = nil;
    
    [super dealloc];
}


#pragma mark JAListView

- (void)setup {
    [super setup];
    
    self.sectionDataSource = self;
    self.sectionRowViews = [NSMutableArray array];
}


#pragma mark JASectionedListView

- (void)setSectionDataSource:(id<JASectionedListViewDataSource>)newDataSource {
    NSAssert([newDataSource isKindOfClass:[self class]], @"Do not set the sectionedDataSource manually.");
    
    [super setSectionDataSource:newDataSource];
}


#pragma mark JASectionedListViewDataSource

- (NSUInteger)numberOfSectionsInListView:(JASectionedListView *)listView {
    return [self numberOfSections];
}

- (NSUInteger)listView:(JASectionedListView *)listView numberOfViewsInSection:(NSUInteger)section {
    return [self viewsInSection:section].count;
}

- (JAListViewItem *)listView:(JAListView *)listView sectionHeaderViewForSection:(NSUInteger)section {
    return [[self.sectionRowViews objectAtIndex:section] objectAtIndex:0];
}

- (JAListViewItem *)listView:(JAListView *)listView viewForSection:(NSUInteger)section index:(NSUInteger)index {
    return [[self viewsInSection:section] objectAtIndex:index];
}


#pragma mark API

@synthesize sectionRowViews;

- (void)addListViewItem:(JAObjectListViewItem *)view inSection:(NSUInteger)section atIndex:(NSUInteger)index {
    [self reallyAddListViewItem:view inSection:section atIndex:index + 1];
}

- (void)reallyAddListViewItem:(JAObjectListViewItem *)view inSection:(NSUInteger)section atIndex:(NSUInteger)index {
    NSMutableArray *sectionViews = nil;
    if(section < self.sectionRowViews.count) {
        sectionViews = [self.sectionRowViews objectAtIndex:section];
    } else if(section != NSNotFound) {
        sectionViews = [NSMutableArray array];
        [self.sectionRowViews insertObject:sectionViews atIndex:section];
    } else {
        NSAssert1(NO, @"Tried to insert view into a non-existent section: %@", view);
    }
    
    if(index != NSNotFound) {
        [sectionViews insertObject:view atIndex:index];
    } else {
        NSAssert1(NO, @"Tried to insert view into a non-existent row: %@", view);
    }
}

- (void)addListViewItem:(JAObjectListViewItem *)view inSection:(NSUInteger)section {
    [self addListViewItem:view inSection:section atIndex:[self viewsInSection:section].count];
}

- (void)removeListViewItemInSection:(NSUInteger)section atIndex:(NSUInteger)index {
    NSMutableArray *sectionViews = [self.sectionRowViews objectAtIndex:section];
    
    NSUInteger trueIndex = index + 1;
    JAObjectListViewItem *view = [sectionViews objectAtIndex:trueIndex];
	[self unmarkViewBeingUsedForInertialScrolling:view];
    
    [self deselectView:view];
    
    [sectionViews removeObjectAtIndex:trueIndex];
}

- (void)addListViewItem:(JAObjectListViewItem *)view forHeaderForSection:(NSUInteger)section {
    NSMutableArray *sectionViews = [NSMutableArray array];
    [self.sectionRowViews insertObject:sectionViews atIndex:section];
    [sectionViews insertObject:view atIndex:0];
}

- (void)removeListViewItemForHeaderForSection:(NSUInteger)section {
    NSArray *views = [self.sectionRowViews objectAtIndex:section];    
    for(JAObjectListViewItem *item in views) {
        [self unmarkViewBeingUsedForInertialScrolling:item];
        
        [self deselectView:item];
    }
    
    [self.sectionRowViews removeObjectAtIndex:section];
}

- (void)removeListViewItem:(JAListViewItem *)view {
    [self unmarkViewBeingUsedForInertialScrolling:view];
    
    [self deselectView:view];
    
    for(NSUInteger sectionIndex = 0; sectionIndex < self.sectionRowViews.count; sectionIndex++) {
        NSMutableArray *sectionViews = [self.sectionRowViews objectAtIndex:sectionIndex];
        NSUInteger index = [sectionViews indexOfObject:view];
        if(index != NSNotFound) {
            if(index == 0) {
                [self removeListViewItemForHeaderForSection:sectionIndex];
            } else {
                [sectionViews removeObjectAtIndex:index];
            }
        }
    }
}

- (void)removeAllListViewItems {
    [self clearViewsBeingUsedForInertialScrolling];
    [self deselectAllViews];
    [self.sectionRowViews removeAllObjects];
}

- (NSArray *)viewsInSection:(NSUInteger)section {
    NSParameterAssert(section < self.sectionRowViews.count);
    
    NSMutableArray *views = [[[self.sectionRowViews objectAtIndex:section] mutableCopy] autorelease];
    if(views.count < 1) return nil;
    
    [views removeObjectAtIndex:0];
    return views;
}

- (NSUInteger)numberOfSections {
    return self.sectionRowViews.count;
}

- (JAObjectListViewItem *)viewItemForObject:(id)object {
    for(NSArray *views in self.sectionRowViews) {
        for(JAObjectListViewItem *item in views) {
            if([item.object isEqual:object]) {
                return item;
            }
        }
    }
    
    return nil;
}

- (NSIndexPath *)indexPathForObject:(id)object {
	NSAssert(object != nil, @"Invalid to look for the index path of a nil object.");
	
    NSUInteger section = 0;
    for(NSArray *views in self.sectionRowViews) {
        
        NSUInteger index = 0;
        for(JAObjectListViewItem *item in views) {
            if([item.object isEqual:object]) {
                if(index == 0) {
                    return [NSIndexPath indexPathForIndex:JASectionedListViewHeaderIndex inSection:section];
                } else {
                    return [NSIndexPath indexPathForIndex:index - 1 inSection:section];
                }
            }
            
            index++;
        }
        
        section++;
    }
    
    return nil;
}

- (JAListViewItem *)headerForSection:(NSUInteger)section {
	return [[self.sectionRowViews objectAtIndex:section] objectAtIndex:0];
}

- (void)removeListViewItemForObject:(id)object {
    [self removeListViewItem:[self viewItemForObject:object]];
}

- (NSArray *)allObjects {
	NSMutableArray *objects = [NSMutableArray array];
	for(NSArray *views in self.sectionRowViews) {
		for(JAObjectListViewItem *item in views) {
			if(item.object != nil) [objects addObject:item.object];
		}
	}
	
	return objects;
}

- (NSString *)debugString {
	return [NSString stringWithFormat:@"%@", self.sectionRowViews];
}

@end
