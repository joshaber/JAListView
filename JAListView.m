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
- (id)keyForObject:(id)object;
- (void)getSelectionMinimumIndex:(NSUInteger *)minIndex maximumIndex:(NSUInteger *)maxIndex;
- (JAListViewItem *)nextSelectableView;
- (JAListViewItem *)previousSelectableView;

@property (readonly) NSMutableArray *cachedViews;
@property (nonatomic, readonly) CGFloat *cachedLocations;
@property (nonatomic, retain) NSArray *cachedVisibleViews;
@property (nonatomic, assign) __weak JAListViewItem *viewBeingSelected;
@property (nonatomic, retain) NSArray *viewsCurrentlyBeingDragged;
@property (nonatomic, retain) NSMutableDictionary *viewStorage;
@property (nonatomic, retain) NSMutableArray *currentlySelectedViews;
@property (nonatomic, retain) NSTrackingArea *currentTrackingArea;
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
    
    self.viewBeingUsedForInertialScroll = nil;
    self.backgroundColor = nil;
    self.cachedVisibleViews = nil;
    self.viewStorage = nil;
    self.currentlySelectedViews = nil;
    self.currentTrackingArea = nil;
    
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
    NSRectFill(dirtyRect);
}


#pragma mark NSResponder

- (void)rightMouseUp:(NSEvent *)event {    
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    JAListViewItem *view = [self viewAtPoint:location];

    if([self.delegate respondsToSelector:@selector(listView:rightMouseDownOnView:withEvent:)]) {
        [self.delegate listView:self rightMouseDownOnView:view withEvent:event];
    }
}

- (void)mouseDown:(NSEvent *)event {
    if(([event modifierFlags] & NSControlKeyMask) != 0 && [event clickCount] == 1) {
        [self rightMouseUp:event];
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
            for(JAListViewItem *selectedView in [[self.currentlySelectedViews copy] autorelease]) {
                [[selectedView retain] autorelease];
                selectedView.selected = NO;
                [self.currentlySelectedViews removeObject:selectedView];
                
                if(respondsToUnSelect) {
                    [self.delegate listView:self didDeselectView:selectedView];
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
            NSUInteger currentMin = 0;
            NSUInteger currentMax = 0;
            [self getSelectionMinimumIndex:&currentMin maximumIndex:&currentMax];
            
            NSUInteger indexOfView = [self indexForView:view];
            if(indexOfView < currentMin) {
                JAListViewItem *previousView = [self previousSelectableView];
                NSUInteger currentIndex = [self indexForView:previousView];
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
                JAListViewItem *nextView = [self nextSelectableView];
                NSUInteger currentIndex = [self indexForView:nextView];
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
                [[selectedView retain] autorelease];
                selectedView.selected = NO;
                [self.currentlySelectedViews removeObject:selectedView];
                
                if(respondsToUnSelect) {
                    [self.delegate listView:self didDeselectView:selectedView];
                }
            }
            
            view.selected = YES;
            [self.currentlySelectedViews addObject:view];
            
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

- (void)mouseDragged:(NSEvent *)event {
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSView *view = [self viewAtPoint:location];
    if(view == nil || ![view isKindOfClass:[JAListViewItem class]]) {
        return;
    }
    
    JAListViewItem *listItemView = (JAListViewItem *) view;
    BOOL shouldDrag = YES;
    if([self.draggingSourceDelegate respondsToSelector:@selector(listView:shouldDragView:)]) {
        shouldDrag = [self.draggingSourceDelegate listView:self shouldDragView:listItemView];
    }
    
    if(!shouldDrag) {
        return;
    }
        
    [[NSPasteboard pasteboardWithName:NSDragPboard] declareTypes:[NSArray arrayWithObject:JAListViewDraggingPasteboardType] owner:self];
    [[NSPasteboard pasteboardWithName:NSDragPboard] setString:JAListViewDraggingPasteboardType forType:JAListViewDraggingPasteboardType];
    
    self.viewsCurrentlyBeingDragged = [NSArray arrayWithObject:listItemView];
    
    NSPoint dragPoint = view.frame.origin;
    dragPoint.y += view.bounds.size.height;
    [self dragImage:[listItemView draggingImage] at:dragPoint offset:NSZeroSize event:event pasteboard:[NSPasteboard pasteboardWithName:NSDragPboard] source:self slideBack:YES];
}

- (void)keyDown:(NSEvent *)event {
    JAListViewItem *newView = nil;
    BOOL isShiftDown = ([event modifierFlags] & NSShiftKeyMask) != 0;
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
        }
    }
    
    if(newView != nil) {
        newView.selected = YES;
        [self.currentlySelectedViews addObject:newView];
        
        if([self.delegate respondsToSelector:@selector(listView:didSelectView:)]) {
            [self.delegate listView:self didSelectView:newView];
        }
        
        NSRect viewFrame = newView.frame;
        viewFrame.origin.y = self.cachedLocations[[self indexForView:newView]];
        [(NSView *) self.scrollView.documentView scrollRectToVisible:viewFrame];
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
    self.viewStorage = [NSMutableDictionary dictionary];
    self.currentlySelectedViews = [NSMutableArray array];
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
    if(animated && self.conditionallyUseLayerBacking) {
        [self setWantsLayer:YES];
    }
    
    [self reloadAllViews];
    [self reloadLayoutAnimated:animated];
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
    
    [viewsToAdd removeObject:self.viewBeingUsedForInertialScroll];
    [viewsToRemove removeObject:self.viewBeingUsedForInertialScroll];
    
    if(animated) {
        CFTimeInterval duration = ([self.window currentEvent].modifierFlags & NSShiftKeyMask) ? 10.0f : 0.25f;
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:duration];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];

        if(self.conditionallyUseLayerBacking) {
            [CATransaction setCompletionBlock:^() {
                [self setWantsLayer:NO];
            }];
        }
    }
    
    CGFloat minY = CGFLOAT_MAX;
    for(NSView *view in viewsToRemove) {
        if([view isKindOfClass:[JAListViewItem class]]) {
            minY = MIN(view.frame.origin.y, minY);
            
            id viewOrProxy = animated ? [view animator] : view;
            [viewOrProxy removeFromSuperview];
            
            JAListViewItem *itemView = (JAListViewItem *) view;
            itemView.listView = nil;
        }
    }
    
    for(JAListViewItem *view in viewsToAdd) {
        if(view.ignoreInListViewLayout) continue;
        
        CGFloat y = self.cachedLocations[[self.cachedViews indexOfObject:view]];
        view.frame = NSMakeRect(self.margin.x, y, self.bounds.size.width - self.margin.x*2, view.bounds.size.height);
        view.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
        
        view.listView = self;
        
        id viewOrProxy = animated ? [self animator] : self;
        [viewOrProxy addSubview:view];
        
        minY = MIN(y, minY);
    }
    
    for(NSView *view in existingViews) {
        if([view isKindOfClass:[JAListViewItem class]]) {
            JAListViewItem *listItemView = (JAListViewItem *) view;
            // only layout views after the first new view
            if(listItemView.frame.origin.y >= minY && !listItemView.ignoreInListViewLayout) {
                CGFloat y = self.cachedLocations[[self.cachedViews indexOfObject:listItemView]];
                
                id viewOrProxy = animated ? [listItemView animator] : listItemView;
                [viewOrProxy setFrameOrigin:NSMakePoint(self.margin.x, y)];
            }
        }
    }
    
    if(animated) {        
        [CATransaction commit];
    }
}

- (void)reloadLayout {
    [self reloadLayoutAnimated:NO];
}

- (void)seriouslyShowVisibleViewsWithAnimation {
    [self showVisibleViewsAnimated:YES];
}

- (void)reloadLayoutAnimated:(BOOL)animated {
    [self recacheAllLocations];
    isResizingManually = YES;
    [self sizeToFitIfNeeded];
    if(animated) {
        [self performSelector:@selector(seriouslyShowVisibleViewsWithAnimation) withObject:nil afterDelay:0];
    } else {
        [self showVisibleViewsAnimated:animated];
    }
    isResizingManually = NO;
}

- (void)recacheAllLocations {
    CGFloat currentY = self.margin.y;
    NSUInteger index = 0;
    for(JAListViewItem *view in self.cachedViews) {
        self.cachedLocations[index] = [self yForView:view proposedY:currentY];
        currentY += [self heightForView:view proposedHeight:view.bounds.size.height + self.margin.y];
        index++;
    }
    
    heightForAllContent = currentY;
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
    NSUInteger numberOfViews = [self numberOfViews];
    NSAssert2(index < numberOfViews, @"Index (%d) must be less than %d.", index, numberOfViews);
    
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

- (NSArray *)visibleViews {
    return self.cachedVisibleViews;
}

- (void)updateCachedVisibleViews {
    NSRect visibleRect = [self.scrollView documentVisibleRect];
    NSMutableArray *newVisibleViews = [NSMutableArray array];
    NSUInteger index = 0;
    for(JAListViewItem *view in self.cachedViews) {
        if(NSIntersectsRect(visibleRect, NSMakeRect(view.frame.origin.x, self.cachedLocations[index], view.frame.size.width, view.frame.size.height))) {
            [newVisibleViews addObject:view];
        }
        
        index++;
    }
    
    self.cachedVisibleViews = newVisibleViews;
}

- (void)setView:(JAListViewItem *)view forKey:(id)key {
    [self.viewStorage setObject:view forKey:key];
}

- (id)viewForKey:(id)key {
    return [self.viewStorage objectForKey:key];
}

- (void)removeViewForKey:(id)key {
    [self.viewStorage removeObjectForKey:key];
}

- (id)keyForView:(JAListViewItem *)view {
    for(id key in self.viewStorage) {
        if([[self.viewStorage objectForKey:key] isEqualTo:view]) {
            return key;
        }
    }
    
    return nil;
}

- (void)setView:(JAListViewItem *)view forObject:(id)object {
    [self setView:view forKey:[self keyForObject:object]];
}

- (id)viewForObject:(id)object {
    return [self viewForKey:[self keyForObject:object]];
}

- (void)removeViewForObject:(id)object {
    [self removeViewForKey:[self keyForObject:object]];
}

- (void)removeAllStoredViews {
    [self.viewStorage removeAllObjects];
}

- (id)keyForObject:(id)object {
    // keys are copied when put into a dictionary, so if they object isn't copyable then we need to just use its pointer address as the key
    if([object conformsToProtocol:@protocol(NSCopying)]) {
        return object;
    } else if([object respondsToSelector:@selector(hash)]) {
        return [NSNumber numberWithUnsignedInteger:[object hash]];
    } else {
        return [NSString stringWithFormat:@"%p", object];
    }
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
        NSUInteger index = [self indexForView:view];
        if(minIndex != NULL) *minIndex = MIN(index, *minIndex);
        if(maxIndex != NULL) *maxIndex = MAX(index, *maxIndex);
    }
}

- (JAListViewItem *)nextSelectableView {
    NSUInteger maxIndex = 0;
    [self getSelectionMinimumIndex:NULL maximumIndex:&maxIndex];
    
    BOOL respondsToShouldSelect = [self.delegate respondsToSelector:@selector(listView:shouldSelectView:)];
    NSUInteger numberOfViews = [self numberOfViews];
    JAListViewItem *nextView = nil;
    NSUInteger index = maxIndex + 1;
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

- (JAListViewItem *)previousSelectableView {
    NSUInteger minIndex = 0;
    [self getSelectionMinimumIndex:&minIndex maximumIndex:NULL];
    
    BOOL respondsToShouldSelect = [self.delegate respondsToSelector:@selector(listView:shouldSelectView:)];
    JAListViewItem *previousView = nil;
    NSInteger index = minIndex - 1;
    while(previousView == nil) {
        if(index < 0) break;
        
        JAListViewItem *potentialView = [self viewAtIndex:index];
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

@synthesize dataSource;
@synthesize delegate;
@synthesize draggingSourceDelegate;
@synthesize draggingDestinationDelegate;
@synthesize cachedVisibleViews;
@synthesize canCallDataSourceInParallel;
@synthesize margin;
@synthesize viewBeingSelected;
@synthesize viewBeingUsedForInertialScroll;
@synthesize backgroundColor;
@synthesize heightForAllContent;
@synthesize conditionallyUseLayerBacking;
@synthesize viewStorage;
@synthesize currentlySelectedViews;
@synthesize currentTrackingArea;

@end
