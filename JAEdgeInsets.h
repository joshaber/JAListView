/*
 *  JAEdgeInsets.h
 *
 *  Created by Josh Abernathy on 1/26/11.
 *  Copyright 2011 Josh Abernathy. All rights reserved.
 *
 */

typedef struct {
	CGFloat top, left, bottom, right;
} JAEdgeInsets;

static inline JAEdgeInsets JAEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right) {
	return (JAEdgeInsets) { .top = top, .left = left, .bottom = bottom, .right = right };
}
