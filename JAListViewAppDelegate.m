//
//  JAListViewAppDelegate.m
//  JAListView
//
//  Created by Josh Abernathy on 9/29/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "JAListViewAppDelegate.h"
#import "DemoView.h"
#import "DemoSectionView.h"


@implementation JAListViewAppDelegate


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {    
    self.listView.canCallDataSourceInParallel = YES;
    self.sectionedListView.canCallDataSourceInParallel = YES;
    
    [self.listView reloadData];
    [self.sectionedListView reloadData];
    
    [self.window makeKeyAndOrderFront:nil];
}


#pragma mark JAListViewDelegate

- (void)listView:(JAListView *)list willSelectView:(JAListViewItem *)view {
    if(list == self.listView) {
        DemoView *demoView = (DemoView *) view;
        demoView.selected = YES;
    }
}

- (void)listView:(JAListView *)list didSelectView:(JAListViewItem *)view {
    if(list == self.listView) {
        DemoView *demoView = (DemoView *) view;
        demoView.selected = NO;
    }
}

- (void)listView:(JAListView *)list didUnSelectView:(JAListViewItem *)view {
    if(list == self.listView) {
        DemoView *demoView = (DemoView *) view;
        demoView.selected = NO;
    }
}


#pragma mark JAListViewDataSource

- (NSUInteger)numberOfItemsInListView:(JAListView *)listView {
    return 100;
}

- (JAListViewItem *)listView:(JAListView *)listView viewAtIndex:(NSUInteger)index {
    DemoView *view = [DemoView demoView];
    view.text = [NSString stringWithFormat:@"Row %d", index + 1];
    return view;
}


#pragma mark JASectionedListViewDataSource

- (NSUInteger)numberOfSectionsInListView:(JASectionedListView *)listView {
    return 3;
}

- (NSUInteger)listView:(JASectionedListView *)listView numberOfViewsInSection:(NSUInteger)section {
    if(section == 0) {
        return 10;
    } else if(section == 1) {
        return 2;
    } else if(section == 2) {
        return 7;
    }
    
    return 0;
}

- (JAListViewItem *)listView:(JAListView *)listView sectionHeaderViewForSection:(NSUInteger)section {
    DemoSectionView *view = [DemoSectionView demoSectionView];
    view.text = [NSString stringWithFormat:@"Section %d", section + 1];
    return view;
}

- (JAListViewItem *)listView:(JAListView *)listView viewForSection:(NSUInteger)section index:(NSUInteger)index {
    DemoView *view = [DemoView demoView];
    view.text = [NSString stringWithFormat:@"Section %d: Row %d", section + 1, index + 1];
    return view;
}


#pragma mark API

@synthesize window;
@synthesize listView;
@synthesize sectionedListView;

@end
