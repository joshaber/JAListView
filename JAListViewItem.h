//
//  JAListViewItem.h
//
//  Created by Josh Abernathy on 10/27/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
	JAListViewPositionTop = 1 << 1,
	JAListViewPositionMiddle = 1 << 2,
	JAListViewPositionBottom = 1 << 3,
	JAListViewPositionNone = 0,
} JAListViewPosition;

@class JAListView;


@interface JAListViewItem : NSView {}

- (NSImage *)draggingImage;

@property (nonatomic, assign) __weak JAListView *listView;
@property (nonatomic, assign) BOOL ignoreInListViewLayout;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, readonly) JAListViewPosition listViewPosition;
@property (nonatomic, assign) BOOL ignoresListViewPadding;

@end
