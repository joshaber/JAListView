//
//  DemoView.h
//  JAListView
//
//  Created by Josh Abernathy on 9/29/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JAListViewItem.h"


@interface DemoView : JAListViewItem {
    NSGradient *gradient;
    BOOL selected;
    NSTextField *textField;
    NSTextField *shadowTextField;
}

+ (DemoView *)demoView;

@property (nonatomic, copy) NSString *text;
@property (retain) IBOutlet NSTextField *textField;
@property (retain) IBOutlet NSTextField *shadowTextField;

@end
