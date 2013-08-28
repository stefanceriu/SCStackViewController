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
            frame.origin.y =  MIN(0, MAX(CGRectGetMinY(finalFrame), contentOffset.y));
            break;
        case SCStackViewControllerPositionLeft:
            frame.origin.x =  MIN(0, MAX(CGRectGetMinX(finalFrame), contentOffset.x));
            break;
        case SCStackViewControllerPositionBottom:
            frame.origin.y = MAX(0, MIN(CGRectGetMaxY(finalFrame) - CGRectGetHeight(finalFrame), CGRectGetHeight(stackController.view.bounds) - CGRectGetHeight(finalFrame) + contentOffset.y));
            break;
        case SCStackViewControllerPositionRight:
            frame.origin.x = MAX(0, MIN(CGRectGetMaxX(finalFrame) - CGRectGetWidth(finalFrame), CGRectGetWidth(stackController.view.bounds) - CGRectGetWidth(finalFrame) + contentOffset.x));
            break;
        default:
            break;
    }

    return frame;
}

@end
