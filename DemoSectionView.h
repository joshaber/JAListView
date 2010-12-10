//
//  DemoSectionView.h
//  JAListView
//
//  Created by Josh Abernathy on 11/26/10.
//  Copyright 2010 Maybe Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JAListViewItem.h"


@interface DemoSectionView : JAListViewItem {}

+ (DemoSectionView *)demoSectionView;

@property (assign) IBOutlet NSTextField *textField;
@property (assign) IBOutlet NSTextField *shadowTextField;
@property (nonatomic, copy) NSString *text;

@end
