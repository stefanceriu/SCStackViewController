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
    if(index == 0) {
        return finalFrame;
    }
    
    CGRect frame = viewController.view.frame;
    
    switch (position) {
        case SCStackViewControllerPositionTop: {
            CGFloat ratio = contentOffset.y / CGRectGetMinY(finalFrame);
            frame.origin.y = CGRectGetMaxY(finalFrame) - CGRectGetHeight(finalFrame) * MAX(0.0f, MIN(1.0f, ratio));
            break;
        }
        case SCStackViewControllerPositionLeft: {
            CGFloat ratio = contentOffset.x / CGRectGetMinX(finalFrame);
            frame.origin.x = CGRectGetMaxX(finalFrame) - CGRectGetWidth(finalFrame) * MAX(0.0f, MIN(1.0f, ratio));
            break;
        }
        case SCStackViewControllerPositionBottom: {
            CGFloat ratio = contentOffset.y / (CGRectGetMaxY(finalFrame) - CGRectGetHeight(stackController.view.bounds));
            frame.origin.y = (CGRectGetMinY(finalFrame) - CGRectGetHeight(finalFrame)) + CGRectGetHeight(finalFrame) * MAX(0.0f, MIN(1.0f, ratio));
            break;
        }
        case SCStackViewControllerPositionRight: {
            CGFloat ratio = contentOffset.x / (CGRectGetMaxX(finalFrame) - CGRectGetWidth(stackController.view.bounds));
            frame.origin.x = (CGRectGetMinX(finalFrame) - CGRectGetWidth(finalFrame)) + CGRectGetWidth(finalFrame) * MAX(0.0f, MIN(1.0f, ratio));
            break;
        }
        default:
            break;
    }
    
    return frame;
}

@end
