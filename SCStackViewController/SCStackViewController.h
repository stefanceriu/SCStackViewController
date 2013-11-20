//
//  SCStackViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import <QuartzCore/CAMediaTimingFunction.h>

typedef enum {
    SCStackViewControllerPositionTop,
    SCStackViewControllerPositionLeft,
    SCStackViewControllerPositionBottom,
    SCStackViewControllerPositionRight
} SCStackViewControllerPosition;


@protocol SCStackLayouterProtocol;
@protocol SCStackViewControllerDelegate;


/** SCStackViewController is a container view controller which allows you to 
 * stack other view controllers on the top/left/bottom/right of the root and 
 * build custom transitions between them while providing correct physics and 
 * appearance calls.
 *
 * @warning One should not attempt to use the stack with both vertical and
 * horizontal layouters at the same time. The behavior is undefined.
 */

@interface SCStackViewController : UIViewController

/**-----------------------------------------------------------------------------
 * @name Properties
 * -----------------------------------------------------------------------------
 */

/** Returns the absolute path of the Homebrew executable. */
@property (nonatomic, strong, readonly) UIViewController *rootViewController;


/** Stack Delegate */
@property (nonatomic, weak) id<SCStackViewControllerDelegate> delegate;


/** UIBezierPath inside which the stack's scrollView doesn't respond to touch 
 *events 
 */
@property (nonatomic, strong) UIBezierPath *touchRefusalArea;

/** BOOL value to enable/disable multiple touch. Default is NO;
 *events
 */
@property (nonatomic, assign) BOOL enableMultipleTouch;

/** Boolean value that controls whether the Stack's scrollView bounces past the
 *  edge of content and back again
 *
 * Default value is set to true
 */
@property (nonatomic, assign) BOOL bounces;


/** A Boolean value that determines whether paging is enabled for the Stack's
 * scrollView.
 *
 * Default value is set to true
 */
@property (nonatomic, assign) BOOL pagingEnabled;


/** A Boolean value that determines whether the user can freely scroll between 
 * pages
 *
 * When set to true the Stack's scrollView bounces on every page. Navigating 
 * through more than 1 page will require multiple swipes.
 * 
 * Default value is set to true
 */
@property (nonatomic, assign) BOOL continuousNavigationEnabled;


/** A Boolean value that controls whether the Stack's scrollView indicators are 
 * visible.
 *
 * Default value is set to false
 */
@property (nonatomic, assign) BOOL showsScrollIndicators;


/** Timing function used in push/pop/navigate operations
 *
 * Default value is set to kCAMediaTimingFunctionEaseInEaseOut
 */
@property (nonatomic, strong) CAMediaTimingFunction *timingFunction;


/** Animation duration for push/pop/navigate operations
 *
 * Default value is set to 0.25f
 */
@property (nonatomic, assign) NSTimeInterval animationDuration;


/**-----------------------------------------------------------------------------
 * @name Initializing the Stack
 * -----------------------------------------------------------------------------
 */

/** Creates and returns a new SCStackVieController
 *
 * @param rootViewController The view controller which provides the view for the
 * center area of the Stack.
 */
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;


/** Registers a layouter for the given position
 *
 * The Stack uses the layouters to get view frames and calculate contentInsets,
 * pagination etc.
 *
 * @param layouter Object that adopts the SCStackLayouterProtocol and provides
 * final and intermediate view frames.
 * @param position The SCStackViewControllerPosition for which the given
 * layouter is responsible
 */
- (void)registerLayouter:(id<SCStackLayouterProtocol>)layouter
             forPosition:(SCStackViewControllerPosition)position;


/**-----------------------------------------------------------------------------
 * @name Performing an Operation
 * -----------------------------------------------------------------------------
 */

/** Pushes a new view controller on the stack at the given position
 *
 * During the animation the layouters will be called and effects will be used
 *
 * @param viewController The view controller to be pushed
 * @param position The position at which to push the view cotroller
 * @param unfold Controls whether the Stack should navigate to the newly pushed
 * view controller
 * @param animated Controls whether the unfold will be animated
 * @param completion Completion block called when the push is done
 */
- (void)pushViewController:(UIViewController *)viewController
                atPosition:(SCStackViewControllerPosition)position
                    unfold:(BOOL)unfold
                  animated:(BOOL)animated
                completion:(void(^)())completion;


/** Pops the last pushed view controller from the given position
 *
 * During the animation the layouters will be called and effects will be used
 *
 * @param position The position from which to pop the view cotroller
 * @param animated Controls whether the pop will be animated
 * @param completion Completion block called when the pop is done
 */
- (void)popViewControllerAtPosition:(SCStackViewControllerPosition)position
                           animated:(BOOL)animated
                         completion:(void(^)())completion;


/** Pops all the view controllers from the given position
 *
 * During the animation the layouters will be called and effects will be used
 *
 * @param position The position from which to pop the view cotrollers
 * @param animated Controls whether the pop will be animated
 * @param completion Completion block called when the pop is done
 */
- (void)popToRootViewControllerFromPosition:(SCStackViewControllerPosition)position
                                   animated:(BOOL)animated
                                 completion:(void(^)())completion;


/** Unfolds to the given view controller
 *
 * The root view controller may be passed in order to hide all the side views. 
 * During the animation the layouters will be called and effects will be used
 *
 * @param viewController The view controller to displayed
 * @param animated Controls whether the navigation will be animated
 * @param completion Completion block called when the action is finished
 */
- (void)navigateToViewController:(UIViewController *)viewController
                        animated:(BOOL)animated
                      completion:(void(^)())completion;

/**-----------------------------------------------------------------------------
 * @name Querying the Stack state
 * -----------------------------------------------------------------------------
 */


/**
 * @return An NSArray of view controllers that the Stack holds for the given
 * position
 * @param position The position for which to return the view controllers array
 */
- (NSArray *)viewControllersForPosition:(SCStackViewControllerPosition)position;


/**
 * @return BOOL value representing the visibility of the passed view controller
 * @param @param viewController The view controller for which to check the
 * visibility
 *
 * A view controller is visible when any part of it is visible (within the
 * Stack's scrollView bounds and not covered by any other view)
 *
 */
- (BOOL)isViewControllerVisible:(UIViewController *)viewController;

@end


/**-----------------------------------------------------------------------------
 * @name Stack delegate
 * -----------------------------------------------------------------------------
 */

@protocol SCStackViewControllerDelegate <NSObject>

@optional

/** Delegate method that the Stack calls when a view controller becomes visible
 *
 * @param stackViewController The calling StackViewController
 * @param controller The view controller that became visible
 * @param position The position where the view controller resides
 *
 * A view controller is visible when any part of it is visible (within the 
 * Stack's scrollView bounds and not covered by any other view)
 *
 */
- (void)stackViewController:(SCStackViewController *)stackViewController
      didShowViewController:(UIViewController *)controller
                   position:(SCStackViewControllerPosition)position;


/** Delegate method that the Stack calls when a view controller is hidden
 * @param stackViewController The calling StackViewController
 * @param controller The view controller that was hidden
 * @param position The position where the view controller resides
 *
 * A view controller is hidden when it view's frame rests outside the Stack's
 * scrollView bounds or when it is fully overlapped by other views
 *
 */
- (void)stackViewController:(SCStackViewController *)stackViewController
      didHideViewController:(UIViewController *)controller
                   position:(SCStackViewControllerPosition)position;


/** Delegate method that the Stack calls when its scrollView scrolls
 * @param stackViewController The calling StackViewController
 * @param offset The current offset in the Stack's scrollView
 *
 */
- (void)stackViewController:(SCStackViewController *)stackViewController
        didNavigateToOffset:(CGPoint)offset;

@end



/**-----------------------------------------------------------------------------
 * @name UIViewController Additions
 * -----------------------------------------------------------------------------
 */

@interface UIViewController (SCStackViewController)


/**
 * @return First SCStackViewController instance found by looking up the
 * responder chain
 */
- (SCStackViewController *)stackViewController;


/**
 * @return ViewController's view width
 */
- (CGFloat)viewWidth;


/**
 * @return ViewController's view height
 */
- (CGFloat)viewHeight;

@end
