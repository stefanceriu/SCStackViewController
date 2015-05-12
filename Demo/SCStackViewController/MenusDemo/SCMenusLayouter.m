//
//  SCMenusLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 5/10/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCMenusLayouter.h"

@implementation SCMenusLayouter

- (CATransform3D)sublayerTransformForRootViewController:(UIViewController *)rootViewController
										  contentOffset:(CGPoint)contentOffset
									  inStackController:(SCStackViewController *)stackViewController
{
	CGFloat visiblePercentage = [stackViewController visiblePercentageForViewController:rootViewController];
	CATransform3D transform = CATransform3DIdentity;
	
	transform = CATransform3DScale(transform, visiblePercentage, visiblePercentage, 1.0f);
	
	CGFloat translation = (1.0f - visiblePercentage) * 1000;
	if(contentOffset.x > 0) {
		translation = -translation;
	}
	
	transform = CATransform3DTranslate(transform, translation, 0.0f, 0.0f);
	
	return transform;
}

@end
