//
//  JAObjectListView.m
//  JAListView
//
//  Created by Josh Abernathy on 12/6/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "JAObjectListView.h"

@interface JAObjectListView ()
- (void)reallyAddListViewItem:(JAListViewItem *)view inSection:(NSUInteger)section atIndex:(NSUInteger)index;

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

- (void)addListViewItem:(JAListViewItem *)view inSection:(NSUInteger)section atIndex:(NSUInteger)index {
    [self reallyAddListViewItem:view inSection:section atIndex:index + 1];
}

- (void)reallyAddListViewItem:(JAListViewItem *)view inSection:(NSUInteger)section atIndex:(NSUInteger)index {
    NSMutableArray *sectionViews = nil;
    if(section < self.sectionRowViews.count) {
        sectionViews = [self.sectionRowViews objectAtIndex:section];
    } else if(section != NSNotFound) { // added NSNotFound check
        sectionViews = [NSMutableArray array];
        [self.sectionRowViews insertObject:sectionViews atIndex:section]; //!!! boom - bounds
    }
    
    if(index < sectionViews.count) {
        [sectionViews replaceObjectAtIndex:index withObject:view];
    } else if(index != NSNotFound) { // added NSNotFound check
        [sectionViews insertObject:view atIndex:index]; //!!! boom - bounds
    }
}

- (void)addListViewItem:(JAListViewItem *)view inSection:(NSUInteger)section {
    [self addListViewItem:view inSection:section atIndex:[self viewsInSection:section].count];
}

- (void)removeListViewItemInSection:(NSUInteger)section atIndex:(NSUInteger)index {
    NSMutableArray *sectionViews = [self.sectionRowViews objectAtIndex:section];
    [sectionViews removeObjectAtIndex:index + 1];
}

- (void)addListViewItem:(JAListViewItem *)view forHeaderForSection:(NSUInteger)section {
    NSMutableArray *sectionViews = [NSMutableArray array];
    [self.sectionRowViews insertObject:sectionViews atIndex:section];
    [sectionViews insertObject:view atIndex:0];
}

- (void)removeListViewItemForHeaderForSection:(NSUInteger)section {
    [self.sectionRowViews removeObjectAtIndex:section];
}

- (void)removeListViewItem:(JAListViewItem *)view {
    [self deselectView:view];
    
    for(NSUInteger sectionIndex = 0; sectionIndex < self.sectionRowViews.count; sectionIndex++) {
        NSMutableArray *sectionViews = [self.sectionRowViews objectAtIndex:sectionIndex];
        NSUInteger index = [sectionViews indexOfObject:view];
        if(index == 0) {
            [self.sectionRowViews removeObjectAtIndex:sectionIndex];
        } else if(index != NSNotFound) {
            [sectionViews removeObjectAtIndex:index];
        }
    }
}

- (void)removeAllListViewItems {
    [self deselectAllViews];
    [self.sectionRowViews removeAllObjects];
}

- (NSArray *)viewsInSection:(NSUInteger)section {
    if(section >= self.sectionRowViews.count) return nil;
    
    NSMutableArray *views = [[[self.sectionRowViews objectAtIndex:section] mutableCopy] autorelease];
    if(views.count < 1) return nil;
    
    [views removeObjectAtIndex:0];
    return views;
}

- (NSUInteger)numberOfSections {
    return self.sectionRowViews.count;
}

@end
