//
//  SCSlidingStackLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 17/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCSlidingStackLayouter.h"
#import <QuartzCore/QuartzCore.h>

@implementation SCSlidingStackLayouter

- (CGRect)currentFrameForViewController:(UIViewController *)viewController
							  withIndex:(NSUInteger)index
							 atPosition:(SCStackViewControllerPosition)position
							 finalFrame:(CGRect)finalFrame
						  contentOffset:(CGPoint)contentOffset
					  inStackController:(SCStackViewController *)stackController
{
	CGRect frame = finalFrame;
	
	switch (position) {
		case SCStackViewControllerPositionTop:
			frame.size.width = CGRectGetWidth(stackController.view.bounds);
			break;
		case SCStackViewControllerPositionLeft:
			frame.size.height = CGRectGetHeight(stackController.view.bounds);
			break;
		case SCStackViewControllerPositionBottom:
			frame.size.width = CGRectGetWidth(stackController.view.bounds);
			break;
		case SCStackViewControllerPositionRight:
			frame.size.height = CGRectGetHeight(stackController.view.bounds);
			break;
		default:
			break;
	}
 
	if(self.shouldStackControllersAboveRoot && index == 0) {
		return frame;
	}
	
	switch (position) {
		case SCStackViewControllerPositionTop:
			frame.origin.y =  MIN(finalFrame.origin.y + finalFrame.size.height, MAX(CGRectGetMinY(finalFrame), contentOffset.y));
			break;
		case SCStackViewControllerPositionLeft:
			frame.origin.x =  MIN(finalFrame.origin.x + finalFrame.size.width, MAX(CGRectGetMinX(finalFrame), contentOffset.x));
			break;
		case SCStackViewControllerPositionBottom:
			frame.origin.y = MAX(finalFrame.origin.y - finalFrame.size.height, MIN(CGRectGetMaxY(finalFrame) - CGRectGetHeight(finalFrame), CGRectGetHeight(stackController.view.bounds) - CGRectGetHeight(finalFrame) + contentOffset.y));
			break;
		case SCStackViewControllerPositionRight:
			frame.origin.x = MAX(finalFrame.origin.x - finalFrame.size.width, MIN(CGRectGetMaxX(finalFrame) - CGRectGetWidth(finalFrame), CGRectGetWidth(stackController.view.bounds) - CGRectGetWidth(finalFrame) + contentOffset.x));
			break;
		default:
			break;
	}
	
	return frame;
}

@end
