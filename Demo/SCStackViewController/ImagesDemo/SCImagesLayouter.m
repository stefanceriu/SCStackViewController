//
//  SCImagesLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 5/10/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCImagesLayouter.h"

@implementation SCImagesLayouter

- (CATransform3D)sublayerTransformForViewController:(UIViewController *)viewController
										  withIndex:(NSUInteger)index
										 atPosition:(SCStackViewControllerPosition)position
										 finalFrame:(CGRect)finalFrame
									  contentOffset:(CGPoint)contentOffset
								  inStackController:(SCStackViewController *)stackViewController
{
	CATransform3D transform = CATransform3DIdentity;
	transform.m34 = 1.0 / -500;
	
	CGFloat visiblePercentage = [stackViewController visiblePercentageForViewController:viewController];
	CGFloat angle = (90.0f - visiblePercentage * 90.0f) * M_PI / 180.0f;
	
	switch (position) {
		case SCStackViewControllerPositionTop: {
			transform = CATransform3DRotate(transform, angle, 1.0f, 0.0f, 0.0f);
			break;
		}
		case SCStackViewControllerPositionLeft: {
			transform = CATransform3DRotate(transform, angle, 0.0f, 1.0f, 0.0f);
			break;
		}
		case SCStackViewControllerPositionBottom: {
			transform = CATransform3DRotate(transform, angle, 1.0f, 0.0f, 0.0f);
			break;
		}
		case SCStackViewControllerPositionRight: {
			transform = CATransform3DRotate(transform, angle, 0.0f, 1.0f, 0.0f);
			break;
		}
	}
		
	return transform;
}

@end
