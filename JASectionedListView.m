//
//  JASectionedListView.m
//  DemoApp
//
//  Created by Josh Abernathy on 11/26/10.
//  Copyright 2010 Maybe Apps, LLC. All rights reserved.
//

#import "JASectionedListView.h"
#import "JAListViewItem.h"

@interface JASectionedListView ()
- (NSUInteger)numberOfTotalViews;
@end


@implementation JASectionedListView


#pragma mark JAListView

- (void)setup {
    [super setup];
    
    self.dataSource = self;
}

- (void)setDataSource:(id<JAListViewDataSource>)newDataSource {
    NSAssert1([newDataSource isKindOfClass:[self class]], @"Please use sectionDataSource for %@.", NSStringFromClass([self class]));
    
    [super setDataSource:newDataSource];
}


#pragma mark JAListViewDataSource

- (NSUInteger)numberOfItemsInListView:(JAListView *)listView {
    return [self numberOfTotalViews];
}

- (JAListViewItem *)listView:(JAListView *)listView viewAtIndex:(NSUInteger)index {
    NSUInteger relativeIndex;
    NSUInteger section;
    
    [self getSection:&section andIndex:&relativeIndex fromAbsoluteIndex:index];
    
    if(relativeIndex == JASectionedListViewHeaderIndex) {
        return [self.sectionDataSource listView:self sectionHeaderViewForSection:section];
    }
    
    return [self.sectionDataSource listView:self viewForSection:section index:relativeIndex];
}


#pragma mark API

@synthesize sectionDataSource;

- (void)getSection:(NSUInteger *)section andIndex:(NSUInteger *)index fromAbsoluteIndex:(NSUInteger)absoluteIndex {
    *index = absoluteIndex;
    for(NSUInteger sectionIndex = 0; sectionIndex < [self numberOfSections]; sectionIndex++) {
        NSUInteger numberOfViews = [self numberOfViewsInSection:sectionIndex] + 1;
        if(*index < numberOfViews) {
            *section = sectionIndex;
            break;
        } else {
            *index -= numberOfViews;
        }
    }
    
    // We want index 0 to be the first row, not the header view, so we reinterpret that as JASectionedListViewHeaderIndex.
    if(*index == 0) {
        *index = JASectionedListViewHeaderIndex;
    } else {
        *index -= 1;
    }
}

- (NSIndexPath *)indexPathFromAbsoluteIndex:(NSUInteger)absoluteIndex {
    NSUInteger section;
    NSUInteger index;
    [self getSection:&section andIndex:&index fromAbsoluteIndex:absoluteIndex];
    return [NSIndexPath indexPathForIndex:index inSection:section];
}

- (NSUInteger)absoluteIndexFromSection:(NSUInteger)section index:(NSUInteger)index {
    NSUInteger absoluteIndex = 0;
    for(NSUInteger sectionIndex = 0; sectionIndex < section; sectionIndex++) {
        NSUInteger numberOfViews = [self numberOfViewsInSection:sectionIndex] + 1;
        absoluteIndex += numberOfViews;
    }
    
    absoluteIndex += index + 1;
    return absoluteIndex;
}

- (NSUInteger)absoluteIndexFromIndexPath:(NSIndexPath *)indexPath {
    return [self absoluteIndexFromSection:indexPath.section index:indexPath.index];
}

- (NSIndexPath *)indexPathForView:(JAListViewItem *)view {
    return [self indexPathFromAbsoluteIndex:(NSUInteger) [self indexForView:view]];
}

- (BOOL)isViewSectionHeaderView:(JAListViewItem *)view {
    return [self indexPathForView:view].index == JASectionedListViewHeaderIndex;
}

- (JAListViewItem *)viewInSection:(NSUInteger)section atIndex:(NSUInteger)index {
    return [self viewAtIndex:[self absoluteIndexFromSection:section index:index]];
}

- (JAListViewItem *)viewAtIndexPath:(NSIndexPath *)indexPath {
    return [self viewInSection:indexPath.section atIndex:indexPath.index];
}

- (NSUInteger)numberOfSections {
    return [self.sectionDataSource numberOfSectionsInListView:self];
}

- (NSUInteger)numberOfViewsInSection:(NSUInteger)section {
    return [self.sectionDataSource listView:self numberOfViewsInSection:section];
}

- (NSUInteger)numberOfTotalViews {
    // one section header view per section
    NSUInteger totalCount = [self numberOfSections];
    for(NSUInteger sectionIndex = 0; sectionIndex < [self numberOfSections]; sectionIndex++) {
        totalCount += [self numberOfViewsInSection:sectionIndex];
    }
    
    return totalCount;
}

- (void)setSectionDataSource:(id <JASectionedListViewDataSource>)newDataSource {
    sectionDataSource = newDataSource;
    
    [self reloadData];
}

@end
