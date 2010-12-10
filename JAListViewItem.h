//
//  JAListViewItem.h
//
//  Created by Josh Abernathy on 10/27/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class JAListView;


@interface JAListViewItem : NSView {}

- (NSImage *)draggingImage;

@property (nonatomic, assign) __weak JAListView *listView;
@property (nonatomic, assign) BOOL ignoreInListViewLayout;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign, getter=isHighlighted) BOOL highlighted;

@end
