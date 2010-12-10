//
//  JASectionedListView.h
//  DemoApp
//
//  Created by Josh Abernathy on 11/26/10.
//  Copyright 2010 Maybe Apps, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JAListView.h"
#import "NSIndexPath+JAListViewExtensions.h"

enum { JASectionedListViewHeaderIndex = NSUIntegerMax };

@class JASectionedListView;

@protocol JASectionedListViewDataSource <NSObject>
- (NSUInteger)numberOfSectionsInListView:(JASectionedListView *)listView;
- (NSUInteger)listView:(JASectionedListView *)listView numberOfViewsInSection:(NSUInteger)section;
- (JAListViewItem *)listView:(JAListView *)listView sectionHeaderViewForSection:(NSUInteger)section;
- (JAListViewItem *)listView:(JAListView *)listView viewForSection:(NSUInteger)section index:(NSUInteger)index;
@end


@interface JASectionedListView : JAListView <JAListViewDataSource> {}

- (NSUInteger)numberOfSections;
- (NSUInteger)numberOfViewsInSection:(NSUInteger)section;

- (JAListViewItem *)viewInSection:(NSUInteger)section atIndex:(NSUInteger)index;
- (JAListViewItem *)viewAtIndexPath:(NSIndexPath *)indexPath;

- (NSUInteger)absoluteIndexFromSection:(NSUInteger)section index:(NSUInteger)index;
- (NSUInteger)absoluteIndexFromIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForView:(JAListViewItem *)view;

- (BOOL)isViewSectionHeaderView:(JAListViewItem *)view;

/*
 * If the absolute index is a header view, index will be set to JASectionedListViewHeaderIndex.
 */
- (void)getSection:(NSUInteger *)section andIndex:(NSUInteger *)index fromAbsoluteIndex:(NSUInteger)absoluteIndex;
- (NSIndexPath *)indexPathFromAbsoluteIndex:(NSUInteger)absoluteIndex;

@property (nonatomic, assign) IBOutlet id<JASectionedListViewDataSource> sectionDataSource;

@end
