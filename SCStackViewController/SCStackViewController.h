//
//  SCStackViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

@import UIKit;

/** Sides on which view controllers may be stacked */
typedef NS_ENUM(NSUInteger, SCStackViewControllerPosition) {
	SCStackViewControllerPositionTop,
	SCStackViewControllerPositionLeft,
	SCStackViewControllerPositionBottom,
	SCStackViewControllerPositionRight
};


/** Navigation contraint types that can be used used when continuous
 * navigation is disabled
 */
typedef NS_OPTIONS(NSUInteger, SCStackViewControllerNavigationContraintType) {
	SCStackViewControllerNavigationContraintTypeForward = 1 << 0, /** Scroll view bounces on steps only when unfolding the stack*/
	SCStackViewControllerNavigationContraintTypeReverse = 1 << 1  /** Scroll view bounces on steps only when folding the stack*/
};


@protocol SCStackLayouterProtocol;
@protocol SCEasingFunctionProtocol;

@protocol SCStackViewControllerDelegate;

@class SCScrollView;

@class SCStackNavigationStep;

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

/** The stack's root view controller. */
@property (nonatomic, strong, nonnull, readonly) UIViewController *rootViewController;


/** Stack Delegate */
@property (nonatomic, nullable, weak) IBOutlet id<SCStackViewControllerDelegate> delegate;


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
 * Default value is set to false
 */
@property (nonatomic, assign) BOOL continuousNavigationEnabled;


/** A bitmask determining whether the stack's scroll bounces when folding and
 * unfolding view controllers
 *
 * Only used when continuous navigation is disabled
 *
 * Defaults to Forward and Reverse
 */
@property (nonatomic, assign) SCStackViewControllerNavigationContraintType navigationContaintType;


/** Timing function used in push/pop/navigate operations
 *
 * Default value is set to SCEasingFunctionTypeSineEaseInOut
 */
@property (nonatomic, strong, nonnull) id<SCEasingFunctionProtocol> easingFunction;


/** Animation duration for push/pop/navigate operations
 *
 * Default value is set to 0.25f
 */
@property (nonatomic, assign) NSTimeInterval animationDuration;


/** The stack's internal scroll view */
@property (nonatomic, strong, nonnull, readonly) SCScrollView *scrollView;


/**
 * @return Blocks interaction while animations are running
 *
 */
@property (nonatomic, assign) BOOL shouldBlockInteractionWhileAnimating;


/** Whether the stack's view is visible or not */
@property (nonatomic, readonly) BOOL visible;


/**-----------------------------------------------------------------------------
 * @name Initializing the Stack
 * -----------------------------------------------------------------------------
 */

/** Creates and returns a new SCStackVieController
 *
 * @param rootViewController The view controller which provides the view for the
 * center area of the Stack.
 */
- (nullable instancetype)initWithRootViewController:(nonnull UIViewController *)rootViewController;


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
- (void)registerLayouter:(nonnull id<SCStackLayouterProtocol>)layouter
			 forPosition:(SCStackViewControllerPosition)position __attribute((deprecated(" Use -registerLayouter:forPosition:animated: instead.")));


/** Registers a layouter for the given position
 *
 * The Stack uses the layouters to get view frames and calculate contentInsets,
 * pagination etc.
 *
 * @param layouter Object that adopts the SCStackLayouterProtocol and provides
 * final and intermediate view frames.
 * @param position The SCStackViewControllerPosition for which the given
 * layouter is responsible
 * @param animated Controls whether the change will be animated
 */
- (void)registerLayouter:(nonnull id<SCStackLayouterProtocol>)layouter
			 forPosition:(SCStackViewControllerPosition)position
				animated:(BOOL)animated;

/** Retrieve the layouter for the given position
 *
 * @param position The SCStackViewControllerPosition to fetch the layouter for
 */
- (nullable id<SCStackLayouterProtocol>)layouterForPosition:(SCStackViewControllerPosition)position;


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
- (void)pushViewController:(nonnull UIViewController *)viewController
				atPosition:(SCStackViewControllerPosition)position
					unfold:(BOOL)unfold
				  animated:(BOOL)animated
				completion:(nullable void(^)(void))completion;


- (void)registerNavigationSteps:(nullable NSArray *)navigationSteps forViewController:(nonnull UIViewController *)viewController;


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
						 completion:(nullable void(^)(void))completion;

/** Pops the given view controller
 *
 * @param viewController The view controller to top
 * @param animated Controls whether the pop will be animated
 * @param completion Completion block called when the pop is done
 */
- (void)popViewController:(nonnull UIViewController *)viewController
				 animated:(BOOL)animated
			   completion:(nullable void(^)(void))completion;


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
								 completion:(nullable void(^)(void))completion;


/** Unfolds to the given view controller
 *
 * The root view controller may be passed in order to hide all the side views.
 * During the animation the layouters will be called and effects will be used
 *
 * @param viewController The view controller to displayed
 * @param animated Controls whether the navigation will be animated
 * @param completion Completion block called when the action is finished
 */
- (void)navigateToViewController:(nonnull UIViewController *)viewController
						animated:(BOOL)animated
					  completion:(nullable void(^)(void))completion;


/** Unfolds to the given step
 *
 * The root view controller may be passed in order to hide all the side views.
 * During the animation the layouters will be called and effects will be used
 *
 * @param step The step to be displayed
 * @param viewController The view controller owning the step
 * @param animated Controls whether the navigation will be animated
 * @param completion Completion block called when the action is finished
 */
- (void)navigateToStep:(nonnull SCStackNavigationStep *)step
	  inViewController:(nonnull UIViewController *)viewController
			  animated:(BOOL)animated
			completion:(nullable void(^)(void))completion;

/**-----------------------------------------------------------------------------
 * @name Querying the Stack state
 * -----------------------------------------------------------------------------
 */


/**
 * @return An NSArray of view controllers that the Stack holds for the given
 * position
 * @param position The position for which to return the view controllers array
 */
- (nonnull NSArray *)viewControllersForPosition:(SCStackViewControllerPosition)position;

/**
 * @return An NSArray of view controllers that are currently visible. Includes
 * root view controller.
 *
 */
- (nonnull NSArray *)visibleViewControllers;


/**
 * @return BOOL value representing the visibility of the passed view controller
 * @param viewController The view controller for which to check the
 * visibility
 *
 * A view controller is visible when any part of it is visible (within the
 * Stack's scrollView bounds and not covered by any other view)
 *
 */
- (BOOL)isViewControllerVisible:(nonnull UIViewController *)viewController;

/**
 * @return Float value representing the visible percentage
 * @param viewController The view controller for which to fetch the
 * visible percentage
 *
 * A view controller is visible when any part of it is visible (within the
 * Stack's scrollView bounds and not covered by any other view)
 *
 * Ranges from 0.0f to 1.0f
 */
- (CGFloat)visiblePercentageForViewController:(nonnull UIViewController *)viewController;

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
- (void)stackViewController:(nonnull SCStackViewController *)stackViewController
	  didShowViewController:(nonnull UIViewController *)controller
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
- (void)stackViewController:(nonnull SCStackViewController *)stackViewController
	  didHideViewController:(nonnull UIViewController *)controller
				   position:(SCStackViewControllerPosition)position;


/** Delegate method that the Stack calls when its scrollView scrolls
 * @param stackViewController The calling StackViewController
 * @param offset The current offset in the Stack's scrollView
 *
 */
- (void)stackViewController:(nonnull SCStackViewController *)stackViewController
		didNavigateToOffset:(CGPoint)offset;


/** Delegate method that the Stack calls when its scrollView rests on a predefined step
 * @param stackViewController The calling StackViewController
 * @param step The step it stopped on
 * @param controller The view controller that own the step
 *
 */
- (void)stackViewController:(nonnull SCStackViewController *)stackViewController
		  didNavigateToStep:(nonnull SCStackNavigationStep *)step
		   inViewController:(nonnull UIViewController *)controller;

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
- (nonnull SCStackViewController *)sc_stackViewController;


/**
 * @return ViewController's view width
 */
- (CGFloat)sc_viewWidth;


/**
 * @return ViewController's view height
 */
- (CGFloat)sc_viewHeight;

@end
