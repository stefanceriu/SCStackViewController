//
//  SCPlainResizingLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 23/01/2014.
//  Copyright (c) 2014 Stefan Ceriu. All rights reserved.
//

#import "SCResizingStackLayouter.h"

@implementation SCResizingStackLayouter

- (id)init
{
	if(self = [super init]) {
		self.shouldStackControllersAboveRoot =  YES;
	}
	
	return self;
}

- (CGRect)currentFrameForRootViewController:(UIViewController *)rootViewController
							  contentOffset:(CGPoint)contentOffset
						  inStackController:(SCStackViewController *)stackController
{
	return CGRectMake(MAX(0,contentOffset.x), MAX(0,contentOffset.y), MAX(0, CGRectGetWidth(stackController.view.bounds) - ABS(contentOffset.x)), MAX(0, CGRectGetHeight(stackController.view.bounds) - ABS(contentOffset.y)));
}

@end
