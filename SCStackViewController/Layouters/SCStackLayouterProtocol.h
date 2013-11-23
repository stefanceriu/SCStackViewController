//
//  SCStackLayouterProtocol.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 16/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCStackViewController.h"

/** An object adopting the SCStackLayouter protocol is responsible for returning
 * the itermediate and final frames for the Stack's children when called. They 
 * have access the the actual children so that they can customize the navigation
 * effects at each point of the transition.
 */

@protocol SCStackLayouterProtocol <NSObject>

/** Returns the final frame for the given view controller
 *
 * @param viewController The view controller for which to calculate the frame
 * @param index The index of the view controller in the Stack's children array
 * @param position The position in the stack
 * @param viewController The full children array for the given position
 * @param stackController The calling StackViewController
 *
 * @return The frame for the viewController's view
 *
 */
- (CGRect)finalFrameForViewController:(UIViewController *)viewController
                            withIndex:(NSUInteger)index
                           atPosition:(SCStackViewControllerPosition)position
                          withinGroup:(NSArray *)viewControllers
                    inStackController:(SCStackViewController *)stackController;

/** Returns the intermediate frame for the given view controller and current
 * offset
 *
 * @param viewController The view controller for which to calculate the frame
 * @param index The index of the view controller in the Stack's children array
 * @param position The position in the stack
 * @param finalFrame previously calculate final frame for this view controller
 * @param contentOffset current offset in the Stack's scrollView
 * @param stackController The calling StackViewController
 *
 * @return The frame for the viewController's view
 *
 */
- (CGRect)currentFrameForViewController:(UIViewController *)viewController
                              withIndex:(NSUInteger)index
                             atPosition:(SCStackViewControllerPosition)position
                             finalFrame:(CGRect)finalFrame
                          contentOffset:(CGPoint)contentOffset
                      inStackController:(SCStackViewController *)stackController;

@optional

/**
 * @return BOOL value that controls whether this layouter reverses the
 * arrangement the children (from the bounds of the screen towards the rootView
 * and not the other way around)
 */
@property (nonatomic, assign) BOOL isReversed;


@property (nonatomic, assign) BOOL shouldStackControllersAboveRoot;

- (CGRect)currentFrameForRootViewController:(UIViewController *)rootViewController
                              contentOffset:(CGPoint)contentOffset
                          inStackController:(SCStackViewController *)stackController;

@end
