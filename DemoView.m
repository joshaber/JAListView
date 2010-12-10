//
//  DemoView.m
//  JAListView
//
//  Created by Josh Abernathy on 9/29/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import "DemoView.h"

@interface DemoView ()
- (void)drawBackground;

@property (nonatomic, readonly) NSGradient *gradient;
@end


@implementation DemoView

+ (DemoView *)demoView {
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

- (void)drawRect:(NSRect)rect {
    [super drawRect:rect];
    [self drawBackground];
}


#pragma mark API

- (void)drawBackground {
    [self.gradient drawInRect:self.bounds angle:self.selected ? 270.0f : 90.0f];
    
    [[NSColor colorWithDeviceWhite:0.5f alpha:1.0f] set];
    NSRectFill(NSMakeRect(0.0f, 0.0f, self.bounds.size.width, 1.0f));
    
    [[NSColor colorWithDeviceWhite:0.93f alpha:1.0f] set];
    NSRectFill(NSMakeRect(0.0f, self.bounds.size.height - 1.0f, self.bounds.size.width, 1.0f));
}

- (NSGradient *)gradient {
    if(gradient == nil) {
        gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithDeviceWhite:0.8f alpha:1.0f] endingColor:[NSColor colorWithDeviceWhite:0.85f alpha:1.0f]];
    }
    
    return gradient;
}

- (void)setText:(NSString *)newText {
    NSString *newValue = [[newText copy] autorelease];
    [self.textField setStringValue:newValue];
    [self.shadowTextField setStringValue:newValue];
}

- (NSString *)text {
    return [self.textField stringValue];
}

- (void)setSelected:(BOOL)isSelected {
    selected = isSelected;
    
    [self setNeedsDisplay:YES];
}

@synthesize selected;
@synthesize textField;
@synthesize shadowTextField;

@end
