//
//  SCStackLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 17/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCStackLayouter.h"

@implementation SCStackLayouter
@synthesize isReversed;
@synthesize shouldStackControllersAboveRoot;

- (CGRect)finalFrameForViewController:(UIViewController *)viewController
							withIndex:(NSUInteger)index
						   atPosition:(SCStackViewControllerPosition)position
						  withinGroup:(NSArray *)viewControllers
					inStackController:(SCStackViewController *)stackController
{
	viewControllers = [viewControllers subarrayWithRange:NSMakeRange(0, [viewControllers indexOfObject:viewController] + 1)];
	
	CGRect finalFrame =  viewController.view.frame;
	switch (position) {
		case SCStackViewControllerPositionTop: {
			finalFrame.origin.y = - [[viewControllers valueForKeyPath:@"@sum.sc_viewHeight"] floatValue];
			break;
		}
		case SCStackViewControllerPositionLeft: {
			finalFrame.origin.x = - [[viewControllers valueForKeyPath:@"@sum.sc_viewWidth"] floatValue];
			break;
		}
		case SCStackViewControllerPositionBottom: {
			finalFrame.origin.y = CGRectGetHeight(stackController.view.bounds) + [[viewControllers valueForKeyPath:@"@sum.sc_viewHeight"] floatValue] - finalFrame.size.height;
			break;
		}
		case SCStackViewControllerPositionRight: {
			finalFrame.origin.x = CGRectGetWidth(stackController.view.bounds) + [[viewControllers valueForKeyPath:@"@sum.sc_viewWidth"] floatValue] - finalFrame.size.width;
			break;
		}
		default:
			break;
	}
	
	return finalFrame;
}

- (CGRect)currentFrameForViewController:(UIViewController *)viewController
							  withIndex:(NSUInteger)index
							 atPosition:(SCStackViewControllerPosition)position
							 finalFrame:(CGRect)finalFrame
						  contentOffset:(CGPoint)contentOffset
					  inStackController:(SCStackViewController *)stackController
{
	switch (position) {
		case SCStackViewControllerPositionTop:
			finalFrame.size.width = CGRectGetWidth(stackController.view.bounds);
			finalFrame.size.height = CGRectGetHeight(viewController.view.bounds);
			break;
		case SCStackViewControllerPositionLeft:
			finalFrame.size.height = CGRectGetHeight(stackController.view.bounds);
			finalFrame.size.width = CGRectGetWidth(viewController.view.bounds);
			break;
		case SCStackViewControllerPositionBottom:
			finalFrame.size.width = CGRectGetWidth(stackController.view.bounds);
			finalFrame.size.height = CGRectGetHeight(viewController.view.bounds);
			break;
		case SCStackViewControllerPositionRight:
			finalFrame.size.height = CGRectGetHeight(stackController.view.bounds);
			finalFrame.size.width = CGRectGetWidth(viewController.view.bounds);
			break;
		default:
			break;
	}
	
	return finalFrame;
}

- (CGRect)currentFrameForRootViewController:(UIViewController *)rootViewController
							  contentOffset:(CGPoint)contentOffset
						  inStackController:(SCStackViewController *)stackViewController
{
	if(self.shouldStackControllersAboveRoot) {
		return CGRectMake(contentOffset.x, contentOffset.y, rootViewController.view.bounds.size.width, rootViewController.view.bounds.size.height);
	} else {
		return stackViewController.view.bounds;
	}
}

@end
