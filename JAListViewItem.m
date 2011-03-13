//
//  JAListViewItem.m
//
//  Created by Josh Abernathy on 10/27/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "JAListViewItem.h"
#import "JAListView.h"
#import "JASectionedListView.h"


@implementation JAListViewItem


#pragma mark NSView

- (void)scrollWheel:(NSEvent *)event {    
	[self.listView markViewBeingUsedForInertialScrolling:self];
    [super scrollWheel:event];
}


#pragma mark NSResponder

- (BOOL)acceptsFirstResponder {
    return YES;
}


#pragma mark API

@synthesize ignoreInListViewLayout;
@synthesize listView;
@synthesize selected;
@synthesize highlighted;
@synthesize listViewPosition;
@synthesize ignoresListViewPadding;

- (NSImage *)draggingImage {
    NSBitmapImageRep *bitmap = [self bitmapImageRepForCachingDisplayInRect:self.bounds];
    [self cacheDisplayInRect:self.bounds toBitmapImageRep:bitmap];
    
    NSSize imageSize = [bitmap size];
    NSImage *image = [[[NSImage alloc] initWithSize:imageSize] autorelease];
    [image addRepresentation:bitmap];
    
    NSImage *result = [[[NSImage alloc] initWithSize:imageSize] autorelease];
    [result lockFocus];
    NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
    NSImageInterpolation savedInterpolation = [currentContext imageInterpolation];
    [currentContext setImageInterpolation:NSImageInterpolationHigh];
    [image drawInRect:NSMakeRect(0, 0, imageSize.width, imageSize.height) fromRect:NSMakeRect(0, 0, imageSize.width, imageSize.height) operation:NSCompositeSourceOver fraction:.5];
    [currentContext setImageInterpolation:savedInterpolation];
    [result unlockFocus];
    
    return result;
}

- (JAListViewPosition)listViewPosition {
	JAListViewPosition position = JAListViewPositionNone;
	NSUInteger index = (NSUInteger) [self.listView indexForView:self];
	NSUInteger numberOfViews = [self.listView numberOfViews];
	
	if([self.listView isKindOfClass:[JASectionedListView class]]) {
		JASectionedListView *sectionedListView = (JASectionedListView *) self.listView;
		NSUInteger section = 0;
		NSUInteger newIndex = index;
		[sectionedListView getSection:&section andIndex:&newIndex fromAbsoluteIndex:index];
		index = newIndex;
		numberOfViews = [sectionedListView numberOfViewsInSection:section];
	}
	
	if(index == numberOfViews - 1) {
		position |= JAListViewPositionBottom;
	}
	
	if(index == 0) {
		position |= JAListViewPositionTop;
	}
	
	if(position == JAListViewPositionNone) {
		position = JAListViewPositionMiddle;
	}
	
	return position;
}

- (void)setSelected:(BOOL)newValue {
    selected = newValue;
    
    [self setNeedsDisplay:YES];
}

- (void)setHighlighted:(BOOL)newValue {
    highlighted = newValue;
    
    [self setNeedsDisplay:YES];
}

@end
