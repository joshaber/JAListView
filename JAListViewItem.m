//
//  JAListViewItem.m
//
//  Created by Josh Abernathy on 10/27/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "JAListViewItem.h"
#import "JAListView.h"


@implementation JAListViewItem


#pragma mark NSView

- (void)scrollWheel:(NSEvent *)event {
    self.listView.viewBeingUsedForInertialScroll = self;
    
    [super scrollWheel:event];
}


#pragma mark API

@synthesize ignoreInListViewLayout;
@synthesize listView;
@synthesize selected;
@synthesize highlighted;

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

- (void)setSelected:(BOOL)newValue {
    selected = newValue;
    
    [self setNeedsDisplay:YES];
}

- (void)setHighlighted:(BOOL)newValue {
    highlighted = newValue;
    
    [self setNeedsDisplay:YES];
}

@end
