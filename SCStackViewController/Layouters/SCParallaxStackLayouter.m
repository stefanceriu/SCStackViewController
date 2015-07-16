//
//  SCParallaxStackLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 16/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCParallaxStackLayouter.h"
#import "SCStackViewController.h"

@implementation SCParallaxStackLayouter

- (CGRect)currentFrameForViewController:(UIViewController *)viewController
							  withIndex:(NSUInteger)index
							 atPosition:(SCStackViewControllerPosition)position
							 finalFrame:(CGRect)finalFrame
						  contentOffset:(CGPoint)contentOffset
					  inStackController:(SCStackViewController *)stackController
{
	if(self.shouldStackControllersAboveRoot && index == 0) {
		
		switch (position) {
			case SCStackViewControllerPositionTop:
				finalFrame.size.width = CGRectGetWidth(stackController.view.bounds);
				break;
			case SCStackViewControllerPositionLeft:
				finalFrame.size.height = CGRectGetHeight(stackController.view.bounds);
				break;
			case SCStackViewControllerPositionBottom:
				finalFrame.size.width = CGRectGetWidth(stackController.view.bounds);
				break;
			case SCStackViewControllerPositionRight:
				finalFrame.size.height = CGRectGetHeight(stackController.view.bounds);
				break;
			default:
				break;
		}
		
		return finalFrame;
	}
	
	CGRect frame = viewController.view.frame;
	
	switch (position) {
		case SCStackViewControllerPositionTop: {
			CGFloat ratio = (contentOffset.y - CGRectGetHeight(finalFrame) / 2) / (CGRectGetMinY(finalFrame) - CGRectGetHeight(finalFrame) / 2);
			frame.origin.y = CGRectGetMaxY(finalFrame) - CGRectGetHeight(finalFrame) * MAX(0.0f, MIN(1.0f, ratio));
			frame.size.width = CGRectGetWidth(stackController.view.bounds);
			break;
		}
		case SCStackViewControllerPositionLeft: {
			CGFloat ratio = (contentOffset.x - CGRectGetWidth(finalFrame) / 2) / (CGRectGetMinX(finalFrame) - CGRectGetWidth(finalFrame) / 2);
			frame.origin.x = CGRectGetMaxX(finalFrame) - CGRectGetWidth(finalFrame) * MAX(0.0f, MIN(1.0f, ratio));
			frame.size.height = CGRectGetHeight(stackController.view.bounds);
			break;
		}
		case SCStackViewControllerPositionBottom: {
			CGFloat ratio = (contentOffset.y + CGRectGetHeight(finalFrame) / 2) / ((CGRectGetMaxY(finalFrame) - CGRectGetHeight(stackController.view.bounds)) + CGRectGetHeight(finalFrame) / 2);
			frame.origin.y = (CGRectGetMinY(finalFrame) - CGRectGetHeight(finalFrame)) + CGRectGetHeight(finalFrame) * MAX(0.0f, MIN(1.0f, ratio));
			frame.size.width = CGRectGetWidth(stackController.view.bounds);
			break;
		}
		case SCStackViewControllerPositionRight: {
			CGFloat ratio = (contentOffset.x + CGRectGetWidth(finalFrame) / 2) / ((CGRectGetMaxX(finalFrame) - CGRectGetWidth(stackController.view.bounds)) + CGRectGetWidth(finalFrame) / 2);
			frame.origin.x = (CGRectGetMinX(finalFrame) - CGRectGetWidth(finalFrame)) + CGRectGetWidth(finalFrame) * MAX(0.0f, MIN(1.0f, ratio));
			frame.size.height = CGRectGetHeight(stackController.view.bounds);
			break;
		}
		default:
			break;
	}
	
	return frame;
}

@end
