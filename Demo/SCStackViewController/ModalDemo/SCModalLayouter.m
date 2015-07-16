//
//  SCModalLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 5/10/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCModalLayouter.h"

@implementation SCModalLayouter

- (CATransform3D)sublayerTransformForViewController:(UIViewController *)viewController
										  withIndex:(NSUInteger)index
										 atPosition:(SCStackViewControllerPosition)position
										 finalFrame:(CGRect)finalFrame
									  contentOffset:(CGPoint)contentOffset
								  inStackController:(SCStackViewController *)stackViewController
{
	CGFloat visiblePercentage = [stackViewController visiblePercentageForViewController:viewController];
	
	CATransform3D transform = CATransform3DIdentity;
	
	CGFloat translation = (1.0f - visiblePercentage) * 400;
	transform = CATransform3DTranslate(transform, translation, translation, 0.0f);
	
	CGFloat angle = (90.0f - visiblePercentage * 90.0f) * M_PI / 180.0f;
	transform = CATransform3DRotate(transform, angle, 0.0f, 0.0f, 1.0f);
	
	return transform;
}

@end
