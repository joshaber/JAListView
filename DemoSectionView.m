//
//  DemoSectionView.m
//  JAListView
//
//  Created by Josh Abernathy on 11/26/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "DemoSectionView.h"


@implementation DemoSectionView

+ (DemoSectionView *)demoSectionView {
    static NSNib *nib = nil;
    if(nib == nil) {
        nib = [[NSNib alloc] initWithNibNamed:NSStringFromClass(self) bundle:nil];
    }
    
    NSArray *objects = nil;
    [nib instantiateNibWithOwner:nil topLevelObjects:&objects];
    for(id object in objects) {
        if([object isKindOfClass:self]) {
            return object;
        }
    }
    
    NSAssert1(NO, @"No view of class %@ found.", NSStringFromClass(self));
    return nil;
}


#pragma mark NSView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [[NSColor lightGrayColor] set];
    NSRectFill(dirtyRect);
}


#pragma mark API

@synthesize textField;
@synthesize shadowTextField;

- (void)setText:(NSString *)text {
    [self.textField setStringValue:[[text copy] autorelease]];
    [self.shadowTextField setStringValue:[[text copy] autorelease]];
}

- (NSString *)text {
    return [self.textField stringValue];
}

@end
