//
//  JAListView.h
//  JAListView
//
//  Created by Josh Abernathy on 9/29/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JAEdgeInsets.h"

@class JAListView;
@class JAListViewItem;

extern NSString * const JAListViewDraggingPasteboardType;

@protocol JAListViewDataSource <NSObject>
- (NSUInteger)numberOfItemsInListView:(JAListView *)listView;
- (JAListViewItem *)listView:(JAListView *)listView viewAtIndex:(NSUInteger)index;
@end

@protocol JAListViewDelegate <NSObject>
@optional
/**
 * Mouse down/up doesn't necessarily mean the view will be selected. These methods will always get called regardless of the return value of -listView:shouldSelectView:.
 */
- (void)listView:(JAListView *)listView mouseDownOnView:(JAListViewItem *)view withEvent:(NSEvent *)event;
- (void)listView:(JAListView *)listView mouseUpOnView:(JAListViewItem *)view withEvent:(NSEvent *)event;

- (void)listView:(JAListView *)listView rightMouseDownOnView:(JAListViewItem *)view withEvent:(NSEvent *)event;

/**
 * A view being selected doesn't necessarily mean it was selected by a click. For instance, keyboard selection will also trigger these events. If the selection is coming from a click, then -listView:willSelectView: gets called on mouse down and -listView:didSelectView: will get called on mouse up while still inside the view.
 */
- (BOOL)listView:(JAListView *)listView shouldSelectView:(JAListViewItem *)view;
- (void)listView:(JAListView *)listView willSelectView:(JAListViewItem *)view;
- (void)listView:(JAListView *)listView didSelectView:(JAListViewItem *)view;
- (void)listView:(JAListView *)listView didDeselectView:(JAListViewItem *)view;

- (void)listView:(JAListView *)listView didRemoveView:(JAListViewItem *)view;
@end

@protocol JAListViewDraggingSourceDelegate <NSObject>
- (BOOL)listView:(JAListView *)listView shouldDragView:(JAListViewItem *)view;
- (void)listView:(JAListView *)listView didStartDraggingView:(JAListViewItem *)view;
- (void)listView:(JAListView *)listView didEndDraggingView:(JAListViewItem *)view;
@end

@protocol JAListViewDraggingDestinationDelegate <NSObject>
- (BOOL)listView:(JAListView *)listView shouldAcceptViews:(NSArray *)draggedViews location:(NSPoint)location;
- (void)listView:(JAListView *)listView dragEntered:(NSArray *)draggedViews location:(NSPoint)location;
- (void)listView:(JAListView *)listView dragUpdated:(NSArray *)draggedViews location:(NSPoint)location;
- (void)listView:(JAListView *)listView dragEnded:(NSArray *)draggedViews location:(NSPoint)location;
- (void)listView:(JAListView *)listView dragExited:(NSArray *)draggedViews location:(NSPoint)location;
@end


@interface JAListView : NSView {
    NSMutableArray *cachedViews;
    NSArray *cachedVisibleViews;
    CGFloat heightForAllContent;
    id<JAListViewDataSource> dataSource;
    id<JAListViewDelegate> delegate;
    id<JAListViewDraggingSourceDelegate> draggingSourceDelegate;
    id<JAListViewDraggingDestinationDelegate> draggingDestinationDelegate;
    BOOL canCallDataSourceInParallel;
    NSPoint margin;
    CGFloat *cachedLocations;
    __weak JAListViewItem *viewBeingSelected;
    NSColor *backgroundColor;
    BOOL isResizingManually;
    BOOL conditionallyUseLayerBacking;
}

- (void)setup;

- (void)reloadData;
- (void)reloadDataAnimated:(BOOL)animated;
- (void)reloadDataWithAnimation:(void (^)(NSView *newSuperview, NSArray *viewsToAdd, NSArray *viewsToRemove, NSArray *viewsToMove))animationBlock;

- (void)reloadLayout;
- (void)reloadLayoutAnimated:(BOOL)animated;
- (void)reloadLayoutWithAnimation:(void (^)(NSView *newSuperview, NSArray *viewsToAdd, NSArray *viewsToRemove, NSArray *viewsToMove))animationBlock;

- (NSUInteger)numberOfViews;
- (JAListViewItem *)viewAtIndex:(NSUInteger)index;
- (NSInteger)indexForView:(JAListViewItem *)view;
- (BOOL)isViewVisible:(JAListViewItem *)view;

- (BOOL)containsViewItem:(JAListViewItem *)viewItem;

- (JAListViewItem *)viewAtPoint:(NSPoint)point;

/*
 * Default implementation returns proposedY. Subclasses could implement this to adjust the Y location for the view.
 */
- (CGFloat)yForView:(JAListViewItem *)view proposedY:(CGFloat)proposedY;

/**
 * Default implementation returns proposedHeight. Subclasses could implement this to adjust the height of the view.
 */
- (CGFloat)heightForView:(JAListViewItem *)view proposedHeight:(CGFloat)proposedHeight;

- (CGFloat)cachedYLocationForView:(JAListViewItem *)view;

/**
 * Will call the delegate's listView:didSelectView: but not listView:shouldSelectView: or listView:willSelectView:.
 */
- (void)selectView:(JAListViewItem *)view;

/**
 * Will call the delegate's listView:didDeselectView:.
 */
- (void)deselectView:(JAListViewItem *)view;

/**
 * Will call the delegate's listView:didDeselectView: for each of the selected views.
 */
- (void)deselectAllViews;

- (void)markViewBeingUsedForInertialScrolling:(JAListViewItem *)newView;
- (void)unmarkViewBeingUsedForInertialScrolling:(JAListViewItem *)view;
- (void)clearViewsBeingUsedForInertialScrolling;

@property (nonatomic, readonly) NSScrollView *scrollView;
@property (nonatomic, assign) IBOutlet id<JAListViewDataSource> dataSource;
@property (nonatomic, assign) IBOutlet id<JAListViewDelegate> delegate;
@property (nonatomic, assign) IBOutlet id<JAListViewDraggingSourceDelegate> draggingSourceDelegate;
@property (nonatomic, assign) IBOutlet id<JAListViewDraggingDestinationDelegate> draggingDestinationDelegate;
@property (nonatomic, assign) BOOL canCallDataSourceInParallel;
@property (nonatomic, readonly) NSArray *visibleViews;
@property (nonatomic, assign) NSPoint margin;
@property (nonatomic, assign) JAEdgeInsets padding;
@property (nonatomic, retain) NSColor *backgroundColor;
@property (nonatomic, readonly) CGFloat heightForAllContent;
@property (nonatomic, assign) BOOL conditionallyUseLayerBacking;
@property (nonatomic, readonly) NSArray *selectedViews;
@property (nonatomic, assign) BOOL allowNoSelection;

@end
