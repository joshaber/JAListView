//
//  JAListViewAppDelegate.h
//  JAListView
//
//  Created by Josh Abernathy on 9/29/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JAListView.h"
#import "JASectionedListView.h"


@interface JAListViewAppDelegate : NSObject <NSApplicationDelegate, NSSplitViewDelegate, JAListViewDataSource, JAListViewDelegate, JASectionedListViewDataSource> {
    NSWindow *window;
    JAListView *listView;
    JASectionedListView *sectionedListView;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet JAListView *listView;
@property (assign) IBOutlet JASectionedListView *sectionedListView;

@end
