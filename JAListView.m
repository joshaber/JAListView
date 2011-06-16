//
//  JAListView.m
//  JAListView
//
//  Created by Josh Abernathy on 9/29/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "JAListView.h"
#import "JAListViewItem.h"
#import <QuartzCore/QuartzCore.h>

static NSArray *viewsCurrentlyBeingDraggedGlobal = nil;

static const NSTimeInterval defaultAnimationDuration = 0.25f;

NSString * const JAListViewDraggingPasteboardType = @"JAListViewDraggingPasteboardType";

@interface JAListView ()
- (void)viewBoundsDidChange:(NSNotification *)notification;
- (void)viewFrameDidChange:(NSNotification *)notification;
- (void)sizeToFitIfNeeded;
- (void)reloadAllViews;
- (void)recacheAllLocations;
- (void)showVisibleViewsAnimated:(BOOL)animated;
- (void)updateCachedVisibleViews;
- (void)clearCachedLocations;
- (void)seriouslyShowVisibleViewsWithAnimation;
- (void)getSelectionMinimumIndex:(NSUInteger *)minIndex maximumIndex:(NSUInteger *)maxIndex;
- (JAListViewItem *)nextSelectableView;
- (JAListViewItem *)nextSelectableViewFromIndex:(NSUInteger)startingIndex;
- (JAListViewItem *)previousSelectableView;
- (JAListViewItem *)previousSelectableViewFromIndex:(NSUInteger)startingIndex;
- (void)standardLayoutRemoveViews:(NSArray *)viewsToRemove addViews:(NSArray *)viewsToAdd moveViews:(NSArray *)viewsToMove;
- (void)standardLayoutAnimated:(BOOL)animated removeViews:(NSArray *)viewsToRemove addViews:(NSArray *)viewsToAdd moveViews:(NSArray *)viewsToMove;

@property (readonly) NSMutableArray *cachedViews;
@property (nonatomic, readonly) CGFloat *cachedLocations;
@property (nonatomic, retain) NSArray *cachedVisibleViews;
@property (nonatomic, assign) __weak JAListViewItem *viewBeingSelected;
@property (nonatomic, retain) NSArray *viewsCurrentlyBeingDragged;
@property (nonatomic, retain) NSMutableArray *currentlySelectedViews;
@property (nonatomic, retain) NSTrackingArea *currentTrackingArea;
@property (nonatomic, copy) void (^currentAnimationBlock)(NSView *newSuperview, NSArray *viewsToAdd, NSArray *viewsToRemove, NSArray *viewsToMove);
@property (nonatomic, retain) NSMutableArray *viewsBeingUsedForInertialScrolling;
@property (nonatomic, assign) NSUInteger minIndexForReLayout;
@end


@implementation JAListView

- (void)finalize {
    if(cachedLocations != NULL) {
        free(cachedLocations);
        cachedLocations = NULL;
    }
    
    [super finalize];
}

- (void)dealloc {
    if(cachedLocations != NULL) {
        free(cachedLocations);
        cachedLocations = NULL;
    }
    
    self.backgroundColor = nil;
    self.cachedVisibleViews = nil;
    self.currentlySelectedViews = nil;
    self.currentTrackingArea = nil;
    self.currentAnimationBlock = nil;
	self.viewsBeingUsedForInertialScrolling = nil;
    
    [super dealloc];
}


#pragma mark NSView

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if(self == nil) return nil;
    
    [self setup];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if(self == nil) return nil;
    
    [self setup];

    return self;
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview {
    if(self.superview != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewBoundsDidChangeNotification object:self.superview];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:self.superview];
    }
}

- (void)viewDidMoveToSuperview {
    if(self.superview == nil) return;
    
	if(self.scrollView == nil) {
		NSLog(@"%@ is not in a scroll view. Unless you know what you're doing, this is a mistake.", self);
	}
	
    [self.scrollView.contentView setPostsBoundsChangedNotifications:YES];
    [self.scrollView.contentView setPostsFrameChangedNotifications:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:self.scrollView.contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewFrameDidChange:) name:NSViewFrameDidChangeNotification object:self.scrollView.contentView];
    
    [self sizeToFitIfNeeded];
    
    [self.scrollView setBackgroundColor:self.backgroundColor];
}

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [self.backgroundColor set];
    NSRectFillUsingOperation(dirtyRect, NSCompositeSourceOver);
}


#pragma mark NSResponder

- (void)rightMouseDown:(NSEvent *)event {    
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    JAListViewItem *view = [self viewAtPoint:location];

    if([self.delegate respondsToSelector:@selector(listView:rightMouseDownOnView:withEvent:)]) {
        [self.delegate listView:self rightMouseDownOnView:view withEvent:event];
    }
}

- (void)rightMouseUp:(NSEvent *)event {
	[self rightMouseDown:event];
}

- (void)mouseDown:(NSEvent *)event {    
    if(([event modifierFlags] & NSControlKeyMask) != 0 && [event clickCount] == 1) {
        [self rightMouseDown:event];
        return;
    }
    
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    JAListViewItem *view = [self viewAtPoint:location];    
    if(view == nil) return;
    
    if([self.delegate respondsToSelector:@selector(listView:mouseDownOnView:withEvent:)]) {
        [self.delegate listView:self mouseDownOnView:view withEvent:event];
    }
    
    BOOL shouldSelect = YES;
    if([self.delegate respondsToSelector:@selector(listView:shouldSelectView:)]) {
        shouldSelect = [self.delegate listView:self shouldSelectView:view];
    }
    
    if(!shouldSelect) {
        return;
    }
    
    if(self.currentTrackingArea != nil) {
        [self removeTrackingArea:self.currentTrackingArea];
    }
    
    self.currentTrackingArea = [[[NSTrackingArea alloc] initWithRect:view.frame options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingEnabledDuringMouseDrag owner:self userInfo:nil] autorelease];
    [self addTrackingArea:self.currentTrackingArea];
    
    self.viewBeingSelected = view;
    self.viewBeingSelected.highlighted = YES;
    
    if([self.delegate respondsToSelector:@selector(listView:willSelectView:)]) {
        [self.delegate listView:self willSelectView:view];
    }
}

- (void)mouseUp:(NSEvent *)event {
	// this is to fix a nasty AppKit bug where the event after a contexual menu gets routed oddly and we end up with a mouseUp event that doesn't really belong to us
	if(!NSPointInRect([self convertPoint:[event locationInWindow] fromView:nil], self.frame)) {
		return;
	}
	
    [self removeTrackingArea:self.currentTrackingArea];
    self.currentTrackingArea = nil;
    
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    JAListViewItem *view = [self viewAtPoint:location];
    BOOL respondsToUnSelect = [self.delegate respondsToSelector:@selector(listView:didDeselectView:)];
    if(view == nil) {
        if(self.viewBeingSelected != nil) {
            if(respondsToUnSelect) {
                [self.delegate listView:self didDeselectView:self.viewBeingSelected];
            }
            
            self.viewBeingSelected.highlighted = NO;
            self.viewBeingSelected = nil;
        } else {
			if(self.allowNoSelection) {
				for(JAListViewItem *selectedView in [[self.currentlySelectedViews copy] autorelease]) {
					selectedView.selected = NO;
					[self.currentlySelectedViews removeObject:selectedView];
					
					if(respondsToUnSelect) {
						[self.delegate listView:self didDeselectView:selectedView];
					}
				}
			}
        }
    } else {
        if([self.delegate respondsToSelector:@selector(listView:mouseUpOnView:withEvent:)]) {
            [self.delegate listView:self mouseUpOnView:view withEvent:event];
        }
                
        self.viewBeingSelected.highlighted = NO;
        
        BOOL shouldSelect = YES;
        if([self.delegate respondsToSelector:@selector(listView:shouldSelectView:)]) {
            shouldSelect = [self.delegate listView:self shouldSelectView:view];
        }
        
        if(!shouldSelect) {
            return;
        }
        
        if([event modifierFlags] & NSCommandKeyMask) {
            if([self.currentlySelectedViews containsObject:view]) {
				if(!self.allowNoSelection && self.currentlySelectedViews.count < 2) return;
				
                [[view retain] autorelease];
                view.selected = NO;
                [self.currentlySelectedViews removeObject:view];
                
                if(respondsToUnSelect) {
                    [self.delegate listView:self didDeselectView:view];
                }
            } else {
                view.selected = YES;
                [self.currentlySelectedViews addObject:view];
                
                if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
                    [self.delegate listView:self didSelectView:view];
                }
            }
        } else if([event modifierFlags] & NSShiftKeyMask) {
            JAListViewItem *lastSelectedView = [self.currentlySelectedViews lastObject];
            NSInteger lastIndex = [self indexForView:lastSelectedView];
            NSInteger indexOfView = [self indexForView:view];
            
            if(lastIndex == NSNotFound || indexOfView == NSNotFound) return;
            
            if(indexOfView < lastIndex) {
                JAListViewItem *previousView = [self previousSelectableViewFromIndex:(NSUInteger) lastIndex];
                NSInteger currentIndex = [self indexForView:previousView];
                while(previousView != nil && currentIndex > indexOfView) {
                    previousView.selected = YES;
                    [self.currentlySelectedViews addObject:previousView];
                    
                    if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
                        [self.delegate listView:self didSelectView:previousView];
                    }
                    
                    previousView = [self previousSelectableView];
                    currentIndex = [self indexForView:previousView];
                }
            } else {
                JAListViewItem *nextView = [self nextSelectableViewFromIndex:(NSUInteger) lastIndex];
                NSInteger currentIndex = [self indexForView:nextView];
                while(nextView != nil && currentIndex < indexOfView) {
                    nextView.selected = YES;
                    [self.currentlySelectedViews addObject:nextView];
                    
                    if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
                        [self.delegate listView:self didSelectView:nextView];
                    }
                    
                    nextView = [self nextSelectableView];
                    currentIndex = [self indexForView:nextView];
                }
            }
            
            view.selected = YES;
            [self.currentlySelectedViews addObject:view];
            
            if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
                [self.delegate listView:self didSelectView:view];
            }
        } else {
            for(JAListViewItem *selectedView in [[self.currentlySelectedViews copy] autorelease]) {
                selectedView.selected = NO;
                [self.currentlySelectedViews removeObject:selectedView];
                
                if(respondsToUnSelect) {
                    [self.delegate listView:self didDeselectView:selectedView];
                }
            }
            
            view.selected = YES;
            [self.currentlySelectedViews addObject:view];
            [self.window makeFirstResponder:view];
            
            if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
                [self.delegate listView:self didSelectView:view];
            }
        }
        
        self.viewBeingSelected = nil;
    }
}

- (void)mouseExited:(NSEvent *)event {
    if(self.viewBeingSelected != nil && [self.delegate respondsToSelector:@selector(listView:didDeselectView:)]) {
        [self.delegate listView:self didDeselectView:self.viewBeingSelected];
        self.viewBeingSelected = nil;
        
        [self removeTrackingArea:self.currentTrackingArea];
        self.currentTrackingArea = nil;
    }
}

- (void)swipeWithEvent:(NSEvent *)event {
    JAListViewItem *newView = nil;
    if([event deltaY] < 0.0f && [self nextSelectableView] != nil) {
        newView = [self nextSelectableView];
    } else if([event deltaY] > 0.0f && [self previousSelectableView] != nil) {
        newView = [self previousSelectableView];
    } else {
        [super swipeWithEvent:event];
    }
    
    if(newView != nil) {
        for(JAListViewItem *view in [[self.currentlySelectedViews copy] autorelease]) {
            [[view retain] autorelease];
            view.selected = NO;
            [self.currentlySelectedViews removeObject:view];
            
            if([self.delegate respondsToSelector:@selector(listView:didDeselectView:)]) {
                [self.delegate listView:self didDeselectView:view];
            }
        }
        
        newView.selected = YES;
        [self.window makeFirstResponder:newView];
        [self.currentlySelectedViews addObject:newView];
        
        if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
            [self.delegate listView:self didSelectView:newView];
        }
        
        NSRect viewFrame = newView.frame;
        viewFrame.origin.y = self.cachedLocations[[self indexForView:newView]];
        [(NSView *) self.scrollView.documentView scrollRectToVisible:viewFrame];
    }
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSView *viewUnderMouse = [self viewAtPoint:location];
    if(viewUnderMouse == nil || ![viewUnderMouse isKindOfClass:[JAListViewItem class]]) {
        return;
    }
    
    JAListViewItem *listItemView = (JAListViewItem *) viewUnderMouse;
    if(![self.currentlySelectedViews containsObject:listItemView]) {
        BOOL shouldSelect = YES;
        if([self.delegate respondsToSelector:@selector(listView:shouldSelectView:)]) {
            shouldSelect = [self.delegate listView:self shouldSelectView:listItemView];
        }
        
        if(!shouldSelect) return;
        
        [self deselectAllViews];
        [self selectView:listItemView];
    }
    
    NSMutableArray *viewsToDrag = [NSMutableArray array];
    
    for(JAListViewItem *view in self.currentlySelectedViews) {
        BOOL shouldDrag = NO;
        if([self.draggingSourceDelegate respondsToSelector:@selector(listView:shouldDragView:)]) {
            shouldDrag = [self.draggingSourceDelegate listView:self shouldDragView:view];
        }
        
        if(shouldDrag) {
            [viewsToDrag addObject:view];
        }
    }
    
    if(viewsToDrag.count < 1) {
        return;
    }
        
    [[NSPasteboard pasteboardWithName:NSDragPboard] declareTypes:[NSArray arrayWithObject:JAListViewDraggingPasteboardType] owner:self];
    [[NSPasteboard pasteboardWithName:NSDragPboard] setString:JAListViewDraggingPasteboardType forType:JAListViewDraggingPasteboardType];
    
    self.viewsCurrentlyBeingDragged = viewsToDrag;
    
    NSMutableArray *images = [NSMutableArray array];
    CGFloat height = 0.0f;
    CGFloat width = 0.0f;
    for(JAListViewItem *view in self.viewsCurrentlyBeingDragged) {
        NSImage *image = [view draggingImage];
        height += image.size.height;
        width = MAX(width, image.size.width);
        [images addObject:image];
    }
    
    NSImage *masterImage = [[[NSImage alloc] initWithSize:NSMakeSize(width, height)] autorelease];
    [masterImage lockFocus];
    NSUInteger index = 0;
    for(NSImage *image in images) {
        JAListViewItem *view = [self.viewsCurrentlyBeingDragged objectAtIndex:index];
        CGFloat y = height - ((index + 1) * view.frame.size.height);
        [image drawAtPoint:NSMakePoint(0.0f, y) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
        
        index++;
    }
    [masterImage unlockFocus];
    
    NSPoint dragPoint = viewUnderMouse.frame.origin;
    dragPoint.y += viewUnderMouse.bounds.size.height;
    [self dragImage:masterImage at:dragPoint offset:NSZeroSize event:event pasteboard:[NSPasteboard pasteboardWithName:NSDragPboard] source:self slideBack:YES];
}

- (void)keyDown:(NSEvent *)event {
    JAListViewItem *newView = nil;
    BOOL isShiftDown = ([event modifierFlags] & NSShiftKeyMask) != 0;
	BOOL areUnhandledKeys = NO;
    NSString *characters = [event characters];
    for(NSUInteger characterIndex = 0; characterIndex < characters.length; characterIndex++) {
        unichar character = [characters characterAtIndex:characterIndex];
        if(character == NSUpArrowFunctionKey) {
            newView = [self previousSelectableView];
            
            if(!isShiftDown && newView != nil) {
                for(JAListViewItem *view in [[self.currentlySelectedViews copy] autorelease]) {
                    [[view retain] autorelease];
                    view.selected = NO;
                    [self.currentlySelectedViews removeObject:view];
                    
                    if([self.delegate respondsToSelector:@selector(listView:didDeselectView:)]) {
                        [self.delegate listView:self didDeselectView:view];
                    }
                }
            }
        } else if(character == NSDownArrowFunctionKey) {
            newView = [self nextSelectableView];
            
            if(!isShiftDown && newView != nil) {
                for(JAListViewItem *view in [[self.currentlySelectedViews copy] autorelease]) {
                    [[view retain] autorelease];
                    view.selected = NO;
                    [self.currentlySelectedViews removeObject:view];
                    
                    if([self.delegate respondsToSelector:@selector(listView:didDeselectView:)]) {
                        [self.delegate listView:self didDeselectView:view];
                    }
                }
            }
        } else {
			areUnhandledKeys = YES;
		}
    }
    
    if(newView != nil) {
        newView.selected = YES;
        [self.window makeFirstResponder:newView];
        [self.currentlySelectedViews addObject:newView];
        
        if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
            [self.delegate listView:self didSelectView:newView];
        }
        
        NSRect viewFrame = newView.frame;
        viewFrame.origin.y = self.cachedLocations[[self indexForView:newView]];
        [(NSView *) self.scrollView.documentView scrollRectToVisible:viewFrame];
    }
	
	if(areUnhandledKeys) {
		[super keyDown:event];
	}
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (BOOL)resignFirstResponder {
    return YES;
}


#pragma mark NSDraggingSource

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return isLocal ? NSDragOperationMove : NSDragOperationNone;
}

- (void)draggedImage:(NSImage *)image movedTo:(NSPoint)screenPoint {
    
}

- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)operation {
    
}


#pragma mark NSDraggingDestination

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {    
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if([pasteboard.types containsObject:JAListViewDraggingPasteboardType]) {
        NSPoint location = [self convertPoint:[sender draggingLocation] fromView:nil];
        [self.draggingDestinationDelegate listView:self dragEntered:self.viewsCurrentlyBeingDragged location:location];
        
        return NSDragOperationMove;
    }
    
    return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {    
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if([pasteboard.types containsObject:JAListViewDraggingPasteboardType]) {
        NSPoint location = [self convertPoint:[sender draggingLocation] fromView:nil];
        [self.draggingDestinationDelegate listView:self dragUpdated:self.viewsCurrentlyBeingDragged location:location];
        
        return NSDragOperationMove;
    }
    
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if([pasteboard.types containsObject:JAListViewDraggingPasteboardType]) {
        NSPoint location = [self convertPoint:[sender draggingLocation] fromView:nil];
        [self.draggingDestinationDelegate listView:self dragEnded:self.viewsCurrentlyBeingDragged location:location];

         self.viewsCurrentlyBeingDragged = nil;
         
        return YES;
    }
    
    return NO;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    NSPoint location = [self convertPoint:[sender draggingLocation] fromView:nil];
    [self.draggingDestinationDelegate listView:self dragExited:self.viewsCurrentlyBeingDragged location:location];
    
    self.viewsCurrentlyBeingDragged = nil;
}


#pragma mark API

- (void)setup {
    canCallDataSourceInParallel = NO;
    margin = NSZeroPoint;
    self.backgroundColor = [NSColor darkGrayColor];
    [self registerForDraggedTypes:[NSArray arrayWithObject:JAListViewDraggingPasteboardType]];
    self.currentlySelectedViews = [NSMutableArray array];
	self.viewsBeingUsedForInertialScrolling = [NSMutableArray array];
	self.allowNoSelection = YES;
}

- (void)viewBoundsDidChange:(NSNotification *)notification {
    if(isResizingManually) return;
    
    [self reloadLayout];
}

- (void)viewFrameDidChange:(NSNotification *)notification {
    if(isResizingManually) return;
    
    [self reloadLayout];
}

- (JAListViewItem *)viewAtPoint:(NSPoint)point {
    for(JAListViewItem *view in self.cachedVisibleViews) {
        if(NSPointInRect(point, view.frame)) {
            return view;
        }
    }
    
    return nil;
}

- (void)sizeToFitIfNeeded {
    CGFloat currentScrollOffset = self.scrollView.contentView.bounds.origin.y;
    
    CGFloat previousHeight = self.frame.size.height;
    CGFloat newHeight = self.heightForAllContent;
    if(previousHeight != newHeight) {
        [self setFrameSize:NSMakeSize(self.superview.bounds.size.width, MAX(newHeight, self.superview.bounds.size.height))];
        
        NSPoint newScrollPoint = self.scrollView.contentView.bounds.origin;
        newScrollPoint.y = currentScrollOffset;
        [self.scrollView.documentView scrollPoint:newScrollPoint];
    }
}

- (void)reloadData {
    [self reloadDataAnimated:NO];
}

- (void)reloadDataAnimated:(BOOL)animated {
    [self reloadDataWithAnimation:animated ? ^(NSView *newSuperview, NSArray *viewsToAdd, NSArray *viewsToRemove, NSArray *viewsToMove) {
        [self standardLayoutAnimated:YES removeViews:viewsToRemove addViews:viewsToAdd moveViews:viewsToMove];
    } : nil];
}

- (void)reloadDataWithAnimation:(void (^)(NSView *newSuperview, NSArray *viewsToAdd, NSArray *viewsToRemove, NSArray *viewsToMove))animationBlock {
    self.currentAnimationBlock = animationBlock;
    
    if(self.currentAnimationBlock != nil && self.conditionallyUseLayerBacking) {
        [self setWantsLayer:YES];
    }
    
    [self reloadAllViews];
    [self reloadLayoutWithAnimation:animationBlock];
}

- (void)reloadAllViews {
    [self.cachedViews removeAllObjects];
    
    NSUInteger numberOfViews = [self numberOfViews];
    NSMutableArray *views = [NSMutableArray arrayWithCapacity:numberOfViews];
    
    // fill the array with dummy values so that the data source can be called in parallel
    for(NSUInteger index = 0; index < numberOfViews; index++) {
        [views addObject:[NSNull null]];
    }
    
    if(self.canCallDataSourceInParallel) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_apply(numberOfViews, queue, ^(size_t index) {
            [views replaceObjectAtIndex:index withObject:[self viewAtIndex:index]];
        });
    } else {
        for(NSUInteger index = 0; index < numberOfViews; index++) {
            [views replaceObjectAtIndex:index withObject:[self viewAtIndex:index]];
        }
    }
	
	for(JAListViewItem *viewItem in views) {
		viewItem.listView = self;
	}
    
    [self.cachedViews addObjectsFromArray:views];
    [self clearCachedLocations];
}

- (void)showVisibleViewsAnimated:(BOOL)animated {
    [self updateCachedVisibleViews];
    
    NSArray *newViews = self.cachedVisibleViews;
    NSArray *existingViews = [[self.subviews copy] autorelease];
    NSMutableArray *viewsToAdd = [NSMutableArray arrayWithArray:newViews];
    NSMutableArray *viewsToRemove = [NSMutableArray arrayWithArray:existingViews];
    // don't do any unnecessary adding/removing otherwise layer-backed views feel the pain
    for(JAListViewItem *view in newViews) {
        if([existingViews containsObject:view]) {
            [viewsToAdd removeObject:view];
        }
    }
    
    for(NSView *view in existingViews) {
        if([newViews containsObject:view]) {
            [viewsToRemove removeObject:view];
        }
    }
		    
    [viewsToAdd removeObjectsInArray:self.viewsBeingUsedForInertialScrolling];
    [viewsToRemove removeObjectsInArray:self.viewsBeingUsedForInertialScrolling];
	
    if(animated) {
        CFTimeInterval duration = ([self.window currentEvent].modifierFlags & NSShiftKeyMask) ? 10.0f : defaultAnimationDuration;
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:duration];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];

        if(self.conditionallyUseLayerBacking) {
            [CATransaction setCompletionBlock:^{
                [self setWantsLayer:NO];
            }];
        }
    }
    
    CGFloat minY = CGFLOAT_MAX;
    for(NSView *view in [[viewsToRemove copy] autorelease]) {
        if([view isKindOfClass:[JAListViewItem class]]) {
            minY = MIN(view.frame.origin.y, minY);
        } else {
            [viewsToRemove removeObject:view];
        }
    }
    
    for(JAListViewItem *view in [[viewsToAdd copy] autorelease]) {
        if(view.ignoreInListViewLayout) {
            [viewsToAdd removeObject:view];
            continue;
        }
        
        view.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
        
        CGFloat y = self.cachedLocations[[self.cachedViews indexOfObject:view]];
        minY = MIN(y, minY);
    }
    
    NSMutableArray *viewsToMove = [NSMutableArray array];
	NSUInteger index = 0;
    for(NSView *view in existingViews) {
        if([view isKindOfClass:[JAListViewItem class]]) {
            JAListViewItem *listItemView = (JAListViewItem *) view;
            // only layout views after the first new view
            if((listItemView.frame.origin.y >= minY || index >= self.minIndexForReLayout) && !listItemView.ignoreInListViewLayout) {
                [viewsToMove addObject:listItemView];
            }
        }
		
		index++;
    }
    
    if(self.currentAnimationBlock != nil) {
        self.currentAnimationBlock(self, viewsToAdd, viewsToRemove, viewsToMove);
    } else {
        [self standardLayoutRemoveViews:viewsToRemove addViews:viewsToAdd moveViews:viewsToMove];
    }
	
	if([self.delegate respondsToSelector:@selector(listView:didRemoveView:)]) {
		for(JAListViewItem *viewItem in viewsToRemove) {
			[self.delegate listView:self didRemoveView:viewItem];
		}
	}
	
	self.minIndexForReLayout = NSUIntegerMax;
    
    self.currentAnimationBlock = nil;
    
    if(animated) {        
        [CATransaction commit];
    }
}

- (CGFloat)cachedYLocationForView:(JAListViewItem *)view {
    NSUInteger index = [self.cachedViews indexOfObject:view];
    if(index == NSNotFound) {
        return 0.0f;
    }
    
    return self.cachedLocations[index];
}

- (void)standardLayoutRemoveViews:(NSArray *)viewsToRemove addViews:(NSArray *)viewsToAdd moveViews:(NSArray *)viewsToMove {
    [self standardLayoutAnimated:NO removeViews:viewsToRemove addViews:viewsToAdd moveViews:viewsToMove];
}

- (void)standardLayoutAnimated:(BOOL)animated removeViews:(NSArray *)viewsToRemove addViews:(NSArray *)viewsToAdd moveViews:(NSArray *)viewsToMove {
    for(JAListViewItem *view in viewsToRemove) {		
        id viewOrProxy = animated ? [view animator] : view;
        [viewOrProxy removeFromSuperview];
    }
    
    for(JAListViewItem *view in viewsToAdd) {
        CGFloat y = self.cachedLocations[[self.cachedViews indexOfObject:view]];
        CGFloat height = [self heightForView:view proposedHeight:view.bounds.size.height];
		NSRect viewFrame = NSMakeRect(view.ignoresListViewPadding ? 0.0f : self.padding.left, y, view.ignoresListViewPadding ? self.bounds.size.width : self.bounds.size.width - (self.padding.left + self.padding.right), height);
        view.frame = NSIntegralRect(viewFrame);
        
        id viewOrProxy = animated ? [self animator] : self;
        [viewOrProxy addSubview:view];
    }
    
    for(JAListViewItem *view in viewsToMove) {
		NSUInteger indexOfView = [self.cachedViews indexOfObject:view];		
		if (indexOfView == NSNotFound) {
			continue;
		}
        CGFloat y = self.cachedLocations[indexOfView]; //!!!: boom - bad access
        id viewOrProxy = animated ? [view animator] : view;
        [viewOrProxy setFrame:NSMakeRect(view.ignoresListViewPadding ? 0.0f : self.padding.left, y, view.bounds.size.width, view.bounds.size.height)];
    }
}

- (void)reloadLayout {
    [self reloadLayoutAnimated:NO];
}

- (void)seriouslyShowVisibleViewsWithAnimation {
    [self showVisibleViewsAnimated:YES];
}

- (void)reloadLayoutAnimated:(BOOL)animated {
    [self reloadLayoutWithAnimation:animated ? ^(NSView *newSuperview, NSArray *viewsToAdd, NSArray *viewsToRemove, NSArray *viewsToMove) {
        [self standardLayoutAnimated:YES removeViews:viewsToRemove addViews:viewsToAdd moveViews:viewsToMove];
    } : nil];
}

- (void)reloadLayoutWithAnimation:(void (^)(NSView *newSuperview, NSArray *viewsToAdd, NSArray *viewsToRemove, NSArray *viewsToMove))animationBlock {
    self.currentAnimationBlock = animationBlock;
    
    [self recacheAllLocations];
    isResizingManually = YES;
    [self sizeToFitIfNeeded];
    if(self.currentAnimationBlock != nil) {
        [self performSelector:@selector(seriouslyShowVisibleViewsWithAnimation) withObject:nil afterDelay:0];
    } else {
        [self showVisibleViewsAnimated:NO];
    }
    isResizingManually = NO;
}

- (void)recacheAllLocations {
	self.minIndexForReLayout = NSUIntegerMax;
	
    CGFloat currentY = self.margin.y + self.padding.top;
    NSUInteger index = 0;
    for(JAListViewItem *view in self.cachedViews) {
        CGFloat newY = [self yForView:view proposedY:currentY];
		if(newY != self.cachedLocations[index]) {
			self.minIndexForReLayout = MIN(self.minIndexForReLayout, index);
		}
		self.cachedLocations[index] = newY;
        currentY += [self heightForView:view proposedHeight:view.bounds.size.height + self.margin.y];
        index++;
    }
    
    heightForAllContent = currentY + self.padding.bottom;
	
	self.minIndexForReLayout = 0;
}

- (CGFloat)yForView:(JAListViewItem *)view proposedY:(CGFloat)proposedY {
    return proposedY;
}

- (CGFloat)heightForView:(JAListViewItem *)view proposedHeight:(CGFloat)proposedHeight {
    return proposedHeight;
}

- (NSUInteger)numberOfViews {
    return [self.dataSource numberOfItemsInListView:self];
}

- (JAListViewItem *)viewAtIndex:(NSUInteger)index {
    JAListViewItem *view = [self.dataSource listView:self viewAtIndex:index];
    NSAssert2([view isKindOfClass:[JAListViewItem class]], @"View must be a %@, instead: %@", NSStringFromClass([JAListViewItem class]), view);
    return view;
}

- (NSInteger)indexForView:(JAListViewItem *)view {
    NSInteger index = 0;
    for(JAListViewItem *viewAtIndex in self.cachedViews) {
        if(viewAtIndex == view) {
            return index;
        }
        
        index++;
    }
    
    return NSNotFound;
}

- (BOOL)isViewVisible:(JAListViewItem *)view {
    return [self.visibleViews containsObject:view];
}

- (BOOL)containsViewItem:(JAListViewItem *)viewItem {
    return [self.cachedViews containsObject:viewItem];
}

- (NSArray *)visibleViews {
    return self.cachedVisibleViews;
}

- (void)updateCachedVisibleViews {
    NSRect visibleRect = [self.scrollView documentVisibleRect];
    NSMutableArray *newVisibleViews = [NSMutableArray array];
    NSUInteger index = 0;
    for(JAListViewItem *view in self.cachedViews) {
        if(NSIntersectsRect(visibleRect, NSMakeRect(view.frame.origin.x, self.cachedLocations[index], MAX(view.frame.size.width, 1.0f), MAX(view.frame.size.height, 1.0f)))) {
            [newVisibleViews addObject:view];
        }
        
        index++;
    }
    
    self.cachedVisibleViews = newVisibleViews;
}

- (NSScrollView *)scrollView {
    return [self enclosingScrollView];
}

- (void)clearCachedLocations {
    if(cachedLocations != NULL) {
        free(cachedLocations);
        cachedLocations = NULL;
    }
}

- (NSMutableArray *)cachedViews {
    if(cachedViews == nil) {
        cachedViews = [[NSMutableArray alloc] init];
    }
    
    return cachedViews;
}

- (CGFloat *)cachedLocations {
    if(cachedLocations == NULL) {
        cachedLocations = (CGFloat *) calloc(self.cachedViews.count, sizeof(CGFloat));
    }
    
    return cachedLocations;
}

- (void)setDataSource:(id<JAListViewDataSource>)newDataSource {
    dataSource = newDataSource;
    
    [self reloadData];
}

- (NSArray *)viewsCurrentlyBeingDragged {
    return viewsCurrentlyBeingDraggedGlobal;
}

- (void)setViewsCurrentlyBeingDragged:(NSArray *)views {
    [views retain];
    [viewsCurrentlyBeingDraggedGlobal release];
    viewsCurrentlyBeingDraggedGlobal = views;
}

- (void)setBackgroundColor:(NSColor *)newColor {
    [newColor retain];
    [backgroundColor release];
    backgroundColor = newColor;
    
    [self.scrollView setBackgroundColor:self.backgroundColor];
    
    [self setNeedsDisplay:YES];
}

- (NSArray *)selectedViews {
    return self.currentlySelectedViews;
}

- (void)getSelectionMinimumIndex:(NSUInteger *)minIndex maximumIndex:(NSUInteger *)maxIndex {
    if(minIndex != NULL) *minIndex = NSUIntegerMax;
    if(maxIndex != NULL) *maxIndex = 0;
    
    for(JAListViewItem *view in self.currentlySelectedViews) {
        NSUInteger index = (NSUInteger) [self indexForView:view];
        if(minIndex != NULL) *minIndex = MIN(index, *minIndex);
        if(maxIndex != NULL) *maxIndex = MAX(index, *maxIndex);
    }
}

- (JAListViewItem *)nextSelectableView {
    NSUInteger maxIndex = 0;
    [self getSelectionMinimumIndex:NULL maximumIndex:&maxIndex];
    
    return [self nextSelectableViewFromIndex:maxIndex];
}

- (JAListViewItem *)previousSelectableView {
    NSUInteger minIndex = 0;
    [self getSelectionMinimumIndex:&minIndex maximumIndex:NULL];
    
    return [self previousSelectableViewFromIndex:minIndex];
}

- (JAListViewItem *)nextSelectableViewFromIndex:(NSUInteger)startingIndex {
    BOOL respondsToShouldSelect = [self.delegate respondsToSelector:@selector(listView:shouldSelectView:)];
    NSUInteger numberOfViews = [self numberOfViews];
    JAListViewItem *nextView = nil;
    NSUInteger index = startingIndex + 1;
    while(nextView == nil) {
        if(index >= numberOfViews) break;
        
        JAListViewItem *potentialView = [self viewAtIndex:index];
        if(respondsToShouldSelect) {
            if([self.delegate listView:self shouldSelectView:potentialView]) {
                nextView = potentialView;
            }
        } else {
            nextView = potentialView;
        }
        
        index++;
        
    }
    
    return nextView;
}

- (JAListViewItem *)previousSelectableViewFromIndex:(NSUInteger)startingIndex {
    BOOL respondsToShouldSelect = [self.delegate respondsToSelector:@selector(listView:shouldSelectView:)];
    JAListViewItem *previousView = nil;
    NSInteger index = (NSInteger) startingIndex - 1;
    while(previousView == nil) {
        if(index < 0) break;
        
        JAListViewItem *potentialView = [self viewAtIndex:(NSUInteger) index];
        if(respondsToShouldSelect) {
            if([self.delegate listView:self shouldSelectView:potentialView]) {
                previousView = potentialView;
            }
        } else {
            previousView = potentialView;
        }
        
        index--;
        
    }
    
    return previousView;
}

- (void)selectView:(JAListViewItem *)view {
    [self.window makeFirstResponder:view];
    view.selected = YES;
    [self.currentlySelectedViews addObject:view];
    
    if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
        [self.delegate listView:self didSelectView:view];
    }
}

- (void)deselectView:(JAListViewItem *)view {
    if(![self.currentlySelectedViews containsObject:view]) return;
    
    [[view retain] autorelease];
    view.selected = NO;
    [self.currentlySelectedViews removeObject:view];
    
    if([self.delegate respondsToSelector:@selector(listView:didDeselectView:)]) {
        [self.delegate listView:self didDeselectView:view];
    }
}

- (void)deselectAllViews {
    for(JAListViewItem *view in [[self.currentlySelectedViews copy] autorelease]) {
        [self deselectView:view];
    }
}

- (void)markViewBeingUsedForInertialScrolling:(JAListViewItem *)newView {
	// This value is fairly arbitrary. I've seen it use 2 different views so we'll go one over that for now.
	static const NSUInteger maxNumberOfViewsForInertialScrolling = 3;
	
	NSAssert(newView != nil, @"Cannot mark a nil view as being used for inertial scrolling.");
	
	[self.viewsBeingUsedForInertialScrolling addObject:newView];
	while(self.viewsBeingUsedForInertialScrolling.count > maxNumberOfViewsForInertialScrolling) {
		[self.viewsBeingUsedForInertialScrolling removeObjectAtIndex:0];
	}
}

- (void)unmarkViewBeingUsedForInertialScrolling:(JAListViewItem *)view {
	[self.viewsBeingUsedForInertialScrolling removeObject:view];
}

- (void)clearViewsBeingUsedForInertialScrolling {
	[self.viewsBeingUsedForInertialScrolling removeAllObjects];
}

@synthesize dataSource;
@synthesize delegate;
@synthesize draggingSourceDelegate;
@synthesize draggingDestinationDelegate;
@synthesize cachedVisibleViews;
@synthesize canCallDataSourceInParallel;
@synthesize margin;
@synthesize padding;
@synthesize viewBeingSelected;
@synthesize backgroundColor;
@synthesize heightForAllContent;
@synthesize conditionallyUseLayerBacking;
@synthesize currentlySelectedViews;
@synthesize currentTrackingArea;
@synthesize currentAnimationBlock;
@synthesize viewsBeingUsedForInertialScrolling;
@synthesize minIndexForReLayout;
@synthesize allowNoSelection;

@end
