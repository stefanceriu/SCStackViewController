//
//  SCStackLayouterProtocol.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 16/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCStackViewController.h"

@protocol SCStackLayouterProtocol <NSObject>

- (CGRect)finalFrameForViewController:(UIViewController *)viewController
                            withIndex:(NSUInteger)index
                           atPosition:(SCStackViewControllerPosition)position
                          withinGroup:(NSArray *)viewControllers
                    inStackController:(SCStackViewController *)stackController;

- (CGRect)currentFrameForViewController:(UIViewController *)viewController
                              withIndex:(NSUInteger)index
                             atPosition:(SCStackViewControllerPosition)position
                             finalFrame:(CGRect)finalFrame
                          contentOffset:(CGPoint)contentOffset
                      inStackController:(SCStackViewController *)stackController;

@optional

- (BOOL)isReversed;

@end
