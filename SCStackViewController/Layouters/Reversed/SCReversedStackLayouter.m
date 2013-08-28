//
//  SCReversedParallaxStackLayouter.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 18/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCReversedStackLayouter.h"

@implementation SCReversedStackLayouter

- (CGRect)finalFrameForViewController:(UIViewController *)viewController
                            withIndex:(NSUInteger)index
                           atPosition:(SCStackViewControllerPosition)position
                          withinGroup:(NSArray *)viewControllers
                    inStackController:(SCStackViewController *)stackController
{
    CGRect finalFrame =  viewController.view.frame;
    switch (position) {
        case SCStackViewControllerPositionTop: {
            NSArray *previousViewControllers = [viewControllers subarrayWithRange:NSMakeRange(0, [viewControllers indexOfObject:viewController])];
            CGFloat totalSize = [[viewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
            
            finalFrame.origin.y = - totalSize + [[previousViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
            break;
        }
        case SCStackViewControllerPositionLeft: {
            NSArray *previousViewControllers = [viewControllers subarrayWithRange:NSMakeRange(0, [viewControllers indexOfObject:viewController])];
            CGFloat totalSize = [[viewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
            
            finalFrame.origin.x = - totalSize + [[previousViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
            break;
        }
        case SCStackViewControllerPositionBottom: {
            NSArray *previousViewControllers = [viewControllers subarrayWithRange:NSMakeRange(0, [viewControllers indexOfObject:viewController] + 1)];
            CGFloat totalSize = [[viewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
            
            finalFrame.origin.y = CGRectGetHeight(stackController.view.bounds) + totalSize - [[previousViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
            break;
        }
        case SCStackViewControllerPositionRight: {
            NSArray *previousViewControllers = [viewControllers subarrayWithRange:NSMakeRange(0, [viewControllers indexOfObject:viewController] + 1)];
            CGFloat totalSize = [[viewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
            
            finalFrame.origin.x = CGRectGetWidth(stackController.view.bounds) + totalSize - [[previousViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
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
//    [UIView animateWithDuration:0.25f animations:^{
//        viewController.view.frame = finalFrame;
//    }];
    
    return finalFrame;
}

- (BOOL)isReversed
{
    return YES;
}

@end
