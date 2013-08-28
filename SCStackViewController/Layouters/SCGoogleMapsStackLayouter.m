//
//  SCGoogleMapsStackLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 24/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCGoogleMapsStackLayouter.h"
#import <QuartzCore/QuartzCore.h>

@implementation SCGoogleMapsStackLayouter

- (CGRect)currentFrameForViewController:(UIViewController *)viewController
                              withIndex:(NSUInteger)index
                             atPosition:(SCStackViewControllerPosition)position
                             finalFrame:(CGRect)finalFrame
                          contentOffset:(CGPoint)contentOffset
                      inStackController:(SCStackViewController *)stackController
{
    CGRect frame = [super currentFrameForViewController:viewController
                                              withIndex:index
                                             atPosition:position
                                             finalFrame:finalFrame
                                          contentOffset:contentOffset
                                      inStackController:stackController];
    
    CGFloat ratio = 1.0f;
    
    switch (position) {
        case SCStackViewControllerPositionTop: {
            ratio = contentOffset.y / CGRectGetMinY(finalFrame);
            break;
        }
        case SCStackViewControllerPositionLeft: {
            ratio = contentOffset.x / CGRectGetMinX(finalFrame);
            break;
        }
        case SCStackViewControllerPositionBottom: {
            ratio = contentOffset.y / (CGRectGetMaxY(finalFrame) - CGRectGetHeight(stackController.view.bounds));
            break;
        }
        case SCStackViewControllerPositionRight: {
            ratio = contentOffset.x / (CGRectGetMaxX(finalFrame) - CGRectGetWidth(stackController.view.bounds));
            break;
        }
        default:
            break;
    }
    
    ratio = MAX(0.0f, MIN(ratio, 1.0f));

    viewController.view.layer.sublayerTransform = CATransform3DMakeScale(ratio, ratio, 1.0f);
    
    return frame;
}

@end
