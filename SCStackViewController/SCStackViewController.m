//
//  SCStackViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCStackViewController.h"
#import "SCStackViewControllerView.h"

#import "SCScrollView.h"
#import "SCEasingFunction.h"
#import "SCStackNavigationStep.h"
#import "SCStackLayouterProtocol.h"

@interface SCStackViewController () <SCStackViewControllerViewDelegate, UIScrollViewDelegate>

@property (nonatomic, strong) IBOutlet UIViewController *rootViewController;

@property (nonatomic, strong) SCScrollView *scrollView;

@property (nonatomic, strong) NSDictionary *loadedControllers;
@property (nonatomic, strong) NSMutableArray *visibleControllers;

@property (nonatomic, strong) NSMutableDictionary *layouters;
@property (nonatomic, strong) NSMutableDictionary *finalFrames;

@property (nonatomic, strong) NSMutableDictionary *navigationSteps;
@property (nonatomic, strong) NSMutableDictionary *previousNavigationSteps;
@property (nonatomic, strong) NSMutableDictionary *stepsForOffsets;

@property (nonatomic, strong) NSMutableDictionary *visiblePercentages;

@property (nonatomic, assign) BOOL isViewVisible;
@property (nonatomic, assign) BOOL isRootViewControllerVisible;

@property (nonatomic, assign) BOOL didIgnoreNavigationalConstraints;

@property (nonatomic, strong) id<SCStackLayouterProtocol> lastUsedLayouter;

@end

@implementation SCStackViewController

- (void)dealloc
{
	[self.scrollView setDelegate:nil];
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
	if(self = [super init]) {
		self.rootViewController = rootViewController;
		[self setup];
	}
	
	return self;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	[self setup];
}

- (void)setup
{
	self.loadedControllers = (@{@(SCStackViewControllerPositionTop)   : [NSMutableArray array],
								@(SCStackViewControllerPositionLeft)  : [NSMutableArray array],
								@(SCStackViewControllerPositionBottom): [NSMutableArray array],
								@(SCStackViewControllerPositionRight) : [NSMutableArray array]});
	
	self.visibleControllers = [NSMutableArray array];
	
	self.layouters = [NSMutableDictionary dictionary];
	self.finalFrames = [NSMutableDictionary dictionary];
	self.navigationSteps = [NSMutableDictionary dictionary];
	self.previousNavigationSteps = [NSMutableDictionary dictionary];
	self.stepsForOffsets = [NSMutableDictionary dictionary];
	self.visiblePercentages = [NSMutableDictionary dictionary];
	
	self.easingFunction = [SCEasingFunction easingFunctionWithType:SCEasingFunctionTypeSineEaseInOut];
	self.animationDuration = 0.25f;
	
	self.navigationContaintType = SCStackViewControllerNavigationContraintTypeForward | SCStackViewControllerNavigationContraintTypeReverse;
	
	self.scrollView = [[SCScrollView alloc] init];
	[self.scrollView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[self.scrollView setDirectionalLockEnabled:YES];
	[self.scrollView setDecelerationRate:UIScrollViewDecelerationRateFast];
	[self.scrollView setDelegate:self];
	
	[self setPagingEnabled:YES];
	[self.scrollView setShowsHorizontalScrollIndicator:NO];
	[self.scrollView setShowsVerticalScrollIndicator:NO];
	
	[self.scrollView setContentOffset:CGPointZero]; // Overrides whatever _adjustContentOffsetIfNecessary might do
}

#pragma mark - Public Methods

- (void)registerLayouter:(id<SCStackLayouterProtocol>)layouter
			 forPosition:(SCStackViewControllerPosition)position
				animated:(BOOL)animated
{
	[self.layouters setObject:layouter forKey:@(position)];
	
	if (!self.isViewLoaded) {
		return;
	}
	
	if(animated) {
		[UIView animateWithDuration:self.animationDuration animations:^{
			[self updateFramesAndTriggerAppearanceCallbacks];
		}];
	} else {
		[self updateFramesAndTriggerAppearanceCallbacks];
	}
}

- (void)registerLayouter:(id<SCStackLayouterProtocol>)layouter
			 forPosition:(SCStackViewControllerPosition)position
{
	[self registerLayouter:layouter forPosition:position animated:YES];
}

- (id<SCStackLayouterProtocol>)layouterForPosition:(SCStackViewControllerPosition)position
{
	return self.layouters[@(position)];
}

- (void)registerNavigationSteps:(NSArray *)navigationSteps forViewController:(UIViewController *)viewController
{
	if(navigationSteps == nil) {
		[self.navigationSteps removeObjectForKey:@([viewController hash])];
		return;
	}
	
	navigationSteps = [navigationSteps sortedArrayUsingComparator:^NSComparisonResult(SCStackNavigationStep *obj1, SCStackNavigationStep *obj2) {
		return obj1.percentage > obj2.percentage;
	}];
	
	[self.navigationSteps setObject:navigationSteps forKey:@([viewController hash])];
}


- (void)pushViewController:(UIViewController *)viewController
				atPosition:(SCStackViewControllerPosition)position
					unfold:(BOOL)unfold
				  animated:(BOOL)animated
				completion:(void(^)(void))completion
{
	if(self.scrollView.isRunningAnimation && self.shouldBlockInteractionWhileAnimating) {
		return;
	}
	
	NSAssert(viewController != nil, @"Trying to push a nil view controller");
	
	if([[self.loadedControllers.allValues valueForKeyPath:@"@unionOfArrays.self"] containsObject:viewController]) {
		NSLog(@"Trying to push an already pushed view controller");
		
		if(unfold) {
			[self navigateToViewController:viewController animated:animated completion:completion];
		} else if(completion) {
			completion();
		}
		return;
	}
	
	NSMutableArray *viewControllers = self.loadedControllers[@(position)];
	[viewControllers addObject:viewController];
	
	[self updateFinalFramesForPosition:position];
	
	id<SCStackLayouterProtocol> layouter = self.layouters[@(position)];
	
	viewController.view.frame = [self.finalFrames[@(viewController.hash)] CGRectValue];
	
	BOOL shouldStackAboveRoot = NO;
	if([layouter respondsToSelector:@selector(shouldStackControllersAboveRoot)]) {
		shouldStackAboveRoot = [layouter shouldStackControllersAboveRoot];
	}
	
	[viewController willMoveToParentViewController:self];
	if(shouldStackAboveRoot) {
		[self.scrollView insertSubview:viewController.view aboveSubview:self.rootViewController.view];
	} else {
		[self.scrollView insertSubview:viewController.view atIndex:0];
	}
	
	[self addChildViewController:viewController];
	[viewController didMoveToParentViewController:self];
	
	[self updateBoundsIgnoringNavigationContraints];
	
	__weak typeof(self) weakSelf = self;
	if(unfold) {
		
		void(^cleanup)(void) = ^{
			[weakSelf updateBoundsUsingNavigationContraints];
			if(completion) {
				completion();
			}
		};
		
		if(animated) {
			[self.scrollView setContentOffset:[self maximumInsetForPosition:position] easingFunction:self.easingFunction duration:self.animationDuration completion:cleanup];
		} else {
			[self.scrollView setContentOffset:[self maximumInsetForPosition:position]];
			cleanup();
		}
		
	} else {
		
		[self updateBoundsUsingNavigationContraints];
		if(completion) {
			completion();
		}
	}
}

- (void)popViewControllerAtPosition:(SCStackViewControllerPosition)position
						   animated:(BOOL)animated
						 completion:(void(^)(void))completion
{
	if(self.scrollView.isRunningAnimation && self.shouldBlockInteractionWhileAnimating) {
		return;
	}
	
	UIViewController *lastViewController = [self.loadedControllers[@(position)] lastObject];
	
	if(lastViewController == nil) {
		if(completion) {
			completion();
		}
		
		return;
	}
	
	[self popViewController:lastViewController
				   animated:animated
				 completion:completion];
}

- (void)popViewController:(UIViewController *)viewController
				 animated:(BOOL)animated
			   completion:(void(^)(void))completion
{
	if(self.scrollView.isRunningAnimation && self.shouldBlockInteractionWhileAnimating) {
		return;
	}
	
	if(viewController == nil) {
		return;
	}
	
	SCStackViewControllerPosition position = [self positionForViewController:viewController];
	
	UIViewController *previousViewController;
	if([self.loadedControllers[@(position)] indexOfObject:viewController] == 0) {
		previousViewController = self.rootViewController;
	} else {
		previousViewController = [self.loadedControllers[@(position)] objectAtIndex:[self.loadedControllers[@(position)] indexOfObject:viewController] - 1];
	}
	
	void(^cleanup)(void) = ^{
		[self.loadedControllers[@(position)] removeObject:viewController];
		[self.finalFrames removeObjectForKey:@([viewController hash])];
		[self.visiblePercentages removeObjectForKey:@([viewController hash])];
		[self updateFinalFramesForPosition:position];
		[self updateBoundsIgnoringNavigationContraints];
		
		if([self.visibleControllers containsObject:viewController]) {
			[viewController beginAppearanceTransition:NO animated:animated];
		}
		
		[viewController willMoveToParentViewController:nil];
		[viewController.view removeFromSuperview];
		[viewController removeFromParentViewController];
		
		if([self.visibleControllers containsObject:viewController]) {
			[viewController endAppearanceTransition];
			[self.visibleControllers removeObject:viewController];
		}
		
		[self updateBoundsUsingNavigationContraints];
		
		if(completion) {
			completion();
		}
	};
	
	if([self.visibleControllers containsObject:viewController]) {
		[self navigateToViewController:previousViewController animated:animated completion:cleanup];
	} else {
		cleanup();
	}
}

- (void)popToRootViewControllerFromPosition:(SCStackViewControllerPosition)position
								   animated:(BOOL)animated
								 completion:(void(^)(void))completion
{
	[self navigateToViewController:self.rootViewController
						  animated:animated
						completion:^{
							NSMutableArray *viewControllers = self.loadedControllers[@(position)];
							
							for(int i=0; viewControllers.count; i++) {
								[self popViewControllerAtPosition:position animated:NO completion:nil];
							}
							
							[viewControllers removeAllObjects];
							
							if(completion) {
								completion();
							}
						}];
}

- (void)navigateToViewController:(UIViewController *)viewController
						animated:(BOOL)animated
					  completion:(void(^)(void))completion
{
	[self navigateToStep:[SCStackNavigationStep navigationStepWithPercentage:1.0f] inViewController:viewController animated:animated completion:completion];
}

- (void)navigateToStep:(SCStackNavigationStep *)step
	  inViewController:(UIViewController *)viewController
			  animated:(BOOL)animated
			completion:(void(^)(void))completion
{
	if(self.scrollView.isRunningAnimation && self.shouldBlockInteractionWhileAnimating) {
		return;
	}
	
	CGPoint offset = CGPointZero;
	CGRect finalFrame = CGRectZero;
	
	[self updateBoundsIgnoringNavigationContraints];
	
	// Save the original navigation steps and just use the given one
	if(self.previousNavigationSteps[@([viewController hash])] == nil) {
		NSArray *previousSteps = self.navigationSteps[@([viewController hash])];
		if(previousSteps) {
			self.previousNavigationSteps[@([viewController hash])] = previousSteps;
		}
	}
	
	[self registerNavigationSteps:(step ? @[step] : nil) forViewController:viewController];
	
	if(![viewController isEqual:self.rootViewController]) {
		
		finalFrame = [[self.finalFrames objectForKey:@(viewController.hash)] CGRectValue];
		
		SCStackViewControllerPosition position = [self positionForViewController:viewController];
		
		BOOL isReversed = NO;
		if([self.layouters[@(position)] respondsToSelector:@selector(isReversed)]) {
			isReversed = [self.layouters[@(position)] isReversed];
		}
		
		SCStackNavigationStep *currentStep = [SCStackNavigationStep navigationStepWithPercentage:[self visiblePercentageForViewController:viewController]];
		
		switch (position) {
			case SCStackViewControllerPositionTop:
			{
				CGPoint velocity = currentStep.percentage > step.percentage ? CGPointMake(0.0f, 1.0f) : CGPointMake(0.0f, -1.0f);
				
				if(velocity.y >= 0.0f) {
					offset.y = (isReversed ? ([self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame)) : CGRectGetMinY(finalFrame));
				} else {
					offset.y = (isReversed ? ([self maximumInsetForPosition:position].y - CGRectGetMinY(finalFrame)) : CGRectGetMaxY(finalFrame));
				}
				
				
				offset = [self nextStepOffsetForViewController:viewController position:position velocity:velocity reversed:isReversed contentOffset:offset paginating:NO];
				break;
			}
			case SCStackViewControllerPositionLeft:
			{
				CGPoint velocity = currentStep.percentage > step.percentage ? CGPointMake(1.0f, 0.0f) : CGPointMake(-1.0f, 0.0f);
				
				if(velocity.x >= 0.0f) {
					offset.x = (isReversed ? ([self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame)) : CGRectGetMinX(finalFrame));
				} else {
					offset.x = (isReversed ? ([self maximumInsetForPosition:position].x - CGRectGetMinX(finalFrame)) : CGRectGetMaxX(finalFrame));
				}
				
				offset = [self nextStepOffsetForViewController:viewController position:position velocity:velocity reversed:isReversed contentOffset:offset paginating:NO];
				break;
			}
			case SCStackViewControllerPositionBottom:
			{
				CGPoint velocity = currentStep.percentage > step.percentage ? CGPointMake(0.0f, -1.0f) : CGPointMake(0.0f, 1.0f);
				
				if(velocity.y >= 0.0f) {
					offset.y = (isReversed ? ([self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame) + CGRectGetHeight(self.view.bounds)) : CGRectGetMinY(finalFrame) - CGRectGetHeight(self.view.bounds));
				} else {
					offset.y = (isReversed ? ([self maximumInsetForPosition:position].y - CGRectGetMinY(finalFrame) + CGRectGetHeight(self.view.bounds)) : CGRectGetMaxY(finalFrame) - CGRectGetHeight(self.view.bounds));
				}
				
				offset = [self nextStepOffsetForViewController:viewController position:position velocity:velocity reversed:isReversed contentOffset:offset paginating:NO];
				break;
			}
			case SCStackViewControllerPositionRight:
			{
				CGPoint velocity = currentStep.percentage > step.percentage ? CGPointMake(-1.0f, 0.0f) : CGPointMake(1.0f, 0.0f);
				
				if(velocity.x >= 0.0f) {
					offset.x = (isReversed ? ([self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame) + CGRectGetWidth(self.view.bounds)) : CGRectGetMinX(finalFrame) - CGRectGetWidth(self.view.bounds));
				} else {
					offset.x = (isReversed ? ([self maximumInsetForPosition:position].x - CGRectGetMinX(finalFrame) + CGRectGetWidth(self.view.bounds)) : CGRectGetMaxX(finalFrame) - CGRectGetWidth(self.view.bounds));
				}
				
				offset = [self nextStepOffsetForViewController:viewController position:position velocity:velocity reversed:isReversed contentOffset:offset paginating:NO];
				break;
			}
			default:
				break;
		}
	}
	
	// Navigate to the determined offset, restore the previous navigation states and update navigation contraints
	__weak typeof(self) weakSelf = self;
	void(^cleanup)(void) = ^{
        
        NSArray *navigationSteps = self.previousNavigationSteps[@([viewController hash])];
        if(navigationSteps.count) {
            [weakSelf registerNavigationSteps:self.previousNavigationSteps[@([viewController hash])] forViewController:viewController];
        }
		
		if(![weakSelf.scrollView isRunningAnimation]) {
			[weakSelf.previousNavigationSteps removeObjectForKey:@([viewController hash])];
		}
		
		[weakSelf updateBoundsUsingNavigationContraints];
		
		if(completion) {
			completion();
		}
	};
	
	if(animated) {
		[self.scrollView setContentOffset:offset easingFunction:self.easingFunction duration:self.animationDuration completion:cleanup];
	} else {
		[self.scrollView setContentOffset:offset];
		cleanup();
	}
}

- (NSArray *)viewControllersForPosition:(SCStackViewControllerPosition)position
{
	return [self.loadedControllers[@(position)] copy];
}

- (NSArray *)visibleViewControllers
{
	NSArray *viewControllers = [self viewControllersForPosition:[self positionForViewController:self.visibleControllers.lastObject]];
	
	NSArray *sortedViewControllers = [self.visibleControllers sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		return [@([viewControllers indexOfObject:obj1]) compare:@([viewControllers indexOfObject:obj2])];
	}];
	
	if(self.isRootViewControllerVisible) {
		return [[NSArray arrayWithObject:self.rootViewController] arrayByAddingObjectsFromArray:sortedViewControllers];
	}
	
	return sortedViewControllers;
}

- (BOOL)isViewControllerVisible:(UIViewController *)viewController
{
	if([viewController isEqual:self.rootViewController]) {
		return self.isRootViewControllerVisible;
	}
	
	return [self.visibleViewControllers containsObject:viewController];
}

- (CGFloat)visiblePercentageForViewController:(UIViewController *)viewController
{
	if([self isViewControllerVisible:viewController] == NO) {
		return 0.0f;
	}
	
	return [self.visiblePercentages[@([viewController hash])] floatValue];
}

- (BOOL)visible
{
	return self.isViewVisible;
}

#pragma mark - UIViewController View Events

- (void)loadView
{
	SCStackViewControllerView *view = [[SCStackViewControllerView alloc] init];
	[view setDelegate:self];
	self.view = view;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
    [self.view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	
	[self.rootViewController willMoveToParentViewController:self];
	[self.scrollView addSubview:self.rootViewController.view];
	[self addChildViewController:self.rootViewController];
	[self.rootViewController didMoveToParentViewController:self];
	
	[self.scrollView setFrame:self.view.bounds];
    
    // Prevents _adjustContentOffsetIfNecessary from triggering
    UIView *scrollViewWrapper = [[UIView alloc] initWithFrame:self.view.bounds];
    [scrollViewWrapper setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [scrollViewWrapper addSubview:self.scrollView];
    
	[self.view addSubview:scrollViewWrapper];
}

- (void)viewWillLayoutSubviews
{
	[super viewWillLayoutSubviews];
	
    for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <= SCStackViewControllerPositionRight; position++) {
		[self updateFinalFramesForPosition:position];
	}
	
	[self updateBoundsIgnoringNavigationContraints];
	
	UIViewController *lastVisibleViewController = [self.visibleViewControllers lastObject];
    if(lastVisibleViewController) {
        CGFloat visiblePercentage = [self visiblePercentageForViewController:lastVisibleViewController];
        [self navigateToStep:[SCStackNavigationStep navigationStepWithPercentage:visiblePercentage] inViewController:lastVisibleViewController animated:NO completion:nil];
    }
	
	[self updateFramesAndTriggerAppearanceCallbacks];
	[self updateBoundsUsingNavigationContraints];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
    self.isViewVisible = YES;
    
    [self updateFramesAndTriggerAppearanceCallbacks];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	self.isViewVisible = NO;
	
	[self updateFramesAndTriggerAppearanceCallbacks];
}

#pragma mark - Stack Management

- (void)updateFinalFramesForPosition:(SCStackViewControllerPosition)position
{
	NSMutableArray *viewControllers = self.loadedControllers[@(position)];
	[viewControllers enumerateObjectsUsingBlock:^(UIViewController *controller, NSUInteger idx, BOOL *stop) {
		CGRect finalFrame = [self.layouters[@(position)] finalFrameForViewController:controller withIndex:idx atPosition:position withinGroup:viewControllers inStackController:self];
		[self.finalFrames setObject:[NSValue valueWithCGRect:finalFrame] forKey:@([controller hash])];
	}];
}

#pragma mark Navigation Contraints

// Sets the insets to the summed up sizes of all the participating view controllers (used before pushing and popping)
- (void)updateBoundsIgnoringNavigationContraints
{
	UIEdgeInsets insets = UIEdgeInsetsZero;
	
	for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <= SCStackViewControllerPositionRight; position++) {
		
		NSArray *viewControllerHashes = [self.loadedControllers[@(position)] valueForKeyPath:@"@distinctUnionOfObjects.hash"];
		NSArray *finalFrameKeys = [self.finalFrames.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSNumber *hash, NSDictionary *bindings) {
			return [viewControllerHashes containsObject:hash];
		}]];
		
		NSArray *frames = [self.finalFrames objectsForKeys:finalFrameKeys notFoundMarker:[NSNull null]];
		for(NSValue *value in frames) {
			switch (position) {
				case SCStackViewControllerPositionTop:
					insets.top = MAX(insets.top, ABS(CGRectGetMinY([value CGRectValue])));
					break;
				case SCStackViewControllerPositionLeft:
					insets.left = MAX(insets.left, ABS(CGRectGetMinX([value CGRectValue])));
					break;
				case SCStackViewControllerPositionBottom:
					insets.bottom = MAX(insets.bottom, CGRectGetMaxY([value CGRectValue]) - CGRectGetHeight(self.view.bounds));
					break;
				case SCStackViewControllerPositionRight:
					insets.right = MAX(insets.right, CGRectGetMaxX([value CGRectValue]) - CGRectGetWidth(self.view.bounds));
					break;
				default:
					break;
			}
		}
	}
	
	[self.scrollView setDelegate:nil];
	
	CGPoint offset = self.scrollView.contentOffset;
	[self.scrollView setContentInset:UIEdgeInsetsIntegral(insets)];
	if((self.scrollView.contentInset.left <= insets.left) || (self.scrollView.contentInset.top <= insets.top)) {
		[self.scrollView setContentOffset:offset];
	}
	
	[self.scrollView setContentSize:self.view.bounds.size];
	[self.scrollView setDelegate:self];
}

// Sets the insets to the first encountered navigation steps in all directions or full size when SCStackViewControllerNavigationContraintTypeForward is not used (when stack is centred on the root)
- (void)updateBoundsUsingDefaultNavigationContraints
{
	if(!(self.navigationContaintType & SCStackViewControllerNavigationContraintTypeForward)) {
		[self updateBoundsIgnoringNavigationContraints];
		return;
	}
	
	UIEdgeInsets insets = UIEdgeInsetsZero;
	
	for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
		NSArray *viewControllers = self.loadedControllers[@(position)];
		
		if(viewControllers.count == 0) {
			continue;
		}
		
		BOOL isReversed = NO;
		if([self.layouters[@(position)] respondsToSelector:@selector(isReversed)]) {
			isReversed = [self.layouters[@(position)] isReversed];
		}
		
		switch (position) {
			case SCStackViewControllerPositionTop:
				insets.top = ABS([self nextStepOffsetForViewController:viewControllers[0] position:position velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:CGPointZero paginating:NO].y);
				break;
			case SCStackViewControllerPositionLeft:
				insets.left = ABS([self nextStepOffsetForViewController:viewControllers[0] position:position velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:CGPointZero paginating:NO].x);
				break;
			case SCStackViewControllerPositionBottom:
				insets.bottom = ABS([self nextStepOffsetForViewController:viewControllers[0] position:position velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:CGPointZero paginating:NO].y);
				break;
			case SCStackViewControllerPositionRight:
				insets.right = ABS([self nextStepOffsetForViewController:viewControllers[0] position:position velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:CGPointZero paginating:NO].x);
				break;
		}
	}
	
	[self.scrollView setContentInset:UIEdgeInsetsIntegral(insets)];
}

// Sets the insets to the next navigation steps based on the current state
- (void)updateBoundsUsingNavigationContraints
{
	if(self.continuousNavigationEnabled) {
		return;
	}
	
	UIEdgeInsets insets = UIEdgeInsetsZero;
	UIViewController *lastVisibleController = [self.visibleViewControllers lastObject];
	
	if(CGPointEqualToPoint(self.scrollView.contentOffset, CGPointZero) || lastVisibleController == nil) {
		[self updateBoundsUsingDefaultNavigationContraints];
		self.didIgnoreNavigationalConstraints = YES;
		return;
	}
	
	SCStackViewControllerPosition lastVisibleControllerPosition = [self positionForViewController:lastVisibleController];
	NSArray *viewControllersArray = self.loadedControllers[@(lastVisibleControllerPosition)];
	NSUInteger visibleControllerIndex = [viewControllersArray indexOfObject:lastVisibleController];
	
	BOOL isReversed = NO;
	if([self.layouters[@(lastVisibleControllerPosition)] respondsToSelector:@selector(isReversed)]) {
		isReversed = [self.layouters[@(lastVisibleControllerPosition)] isReversed];
	}
	
	if(self.navigationContaintType & SCStackViewControllerNavigationContraintTypeReverse) {
		switch (lastVisibleControllerPosition) {
			case SCStackViewControllerPositionTop: {
				insets.top = -[self maximumInsetForPosition:lastVisibleControllerPosition].y;
				insets.bottom = [self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].y;
				break;
			}
			case SCStackViewControllerPositionLeft: {
				insets.left = -[self maximumInsetForPosition:lastVisibleControllerPosition].x;
				insets.right = [self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].x;
				break;
			}
			case SCStackViewControllerPositionBottom: {
				insets.bottom = [self maximumInsetForPosition:lastVisibleControllerPosition].y;
				insets.top = -[self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].y;
				break;
			}
			case SCStackViewControllerPositionRight: {
				insets.right = [self maximumInsetForPosition:lastVisibleControllerPosition].x;
				insets.left = -[self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].x;
				break;
			}
		}
	}
	
	if(self.navigationContaintType & SCStackViewControllerNavigationContraintTypeForward) {
		switch (lastVisibleControllerPosition) {
			case SCStackViewControllerPositionTop: {
				// Fetch the next step and set it as the current inset
				insets.top = ABS([self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].y);
				
				// If the next step is the upper bound of the current view controller and there are more view controllers on the stack, fetch the following view controller's first navigation step and use that
				if(ABS(self.scrollView.contentOffset.y) == insets.top && visibleControllerIndex < viewControllersArray.count - 1) {
					insets.top = ABS([self nextStepOffsetForViewController:viewControllersArray[visibleControllerIndex + 1] position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].y);
				}
				
				break;
			}
			case SCStackViewControllerPositionLeft: {
				insets.left = ABS([self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].x);
				
				if(ABS(self.scrollView.contentOffset.x) == insets.left && visibleControllerIndex < viewControllersArray.count - 1) {
					insets.left = ABS([self nextStepOffsetForViewController:viewControllersArray[visibleControllerIndex + 1] position:lastVisibleControllerPosition velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].x);
				}
				
				break;
			}
			case SCStackViewControllerPositionBottom: {
				insets.bottom = ABS([self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].y);
				
				if(ABS(self.scrollView.contentOffset.y) == insets.bottom && visibleControllerIndex < viewControllersArray.count - 1) {
					insets.bottom = ABS([self nextStepOffsetForViewController:viewControllersArray[visibleControllerIndex + 1] position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].y);
				}
				
				break;
			}
			case SCStackViewControllerPositionRight: {
				insets.right = ABS([self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].x);
				
				if(ABS(self.scrollView.contentOffset.x) == insets.right && visibleControllerIndex < viewControllersArray.count - 1) {
					insets.right = ABS([self nextStepOffsetForViewController:viewControllersArray[visibleControllerIndex + 1] position:lastVisibleControllerPosition velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset paginating:NO].x);
				}
				
				break;
			}
		}
	}
	
	[self.scrollView setContentInset:UIEdgeInsetsIntegral(insets)];
}

#pragma mark Appearance callbacks and framesetting

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
	return NO;
}

- (void)updateFramesAndTriggerAppearanceCallbacks
{
	CGPoint offset = self.scrollView.contentOffset;
	
	// Fetch the active layouter based on the current offset and use it to set the root's frame
	id<SCStackLayouterProtocol> activeLayouter;
	if(offset.y < 0.0f) {
		activeLayouter = self.layouters[@(SCStackViewControllerPositionTop)];
	} else if(offset.x < 0.0f) {
		activeLayouter = self.layouters[@(SCStackViewControllerPositionLeft)];
	} else if(offset.y > 0.0f){
		activeLayouter = self.layouters[@(SCStackViewControllerPositionBottom)];
	} else if(offset.x > 0.0f) {
		activeLayouter = self.layouters[@(SCStackViewControllerPositionRight)];
	} else {
		activeLayouter = self.lastUsedLayouter;
	}
	
	self.lastUsedLayouter = activeLayouter;
	
	CGRect newRootViewControllerFrame;
	if([activeLayouter respondsToSelector:@selector(currentFrameForRootViewController:contentOffset:inStackController:)]) {
		newRootViewControllerFrame = [activeLayouter currentFrameForRootViewController:self.rootViewController contentOffset:offset inStackController:self];
	} else {
		newRootViewControllerFrame = self.view.bounds;
	}
	
	__block CGRect rootRemainder = CGRectIntersection(self.scrollView.bounds, newRootViewControllerFrame);
	
	for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <= SCStackViewControllerPositionRight; position++) {
		
		id<SCStackLayouterProtocol> layouter = self.layouters[@(position)];
		
		BOOL shouldStackControllersAboveRoot = NO;
		if([layouter respondsToSelector:@selector(shouldStackControllersAboveRoot)]) {
			shouldStackControllersAboveRoot = [layouter shouldStackControllersAboveRoot];
		}
		
		CGRectEdge edge = [self edgeFromOffset:offset];
		__block CGRect remainder;
		
		// Determine the amount of unobstructed space the stacked view controllers might be seen through
		if(shouldStackControllersAboveRoot) {
			remainder = [self subtractRect:CGRectIntersection(self.scrollView.bounds, self.view.bounds) fromRect:self.scrollView.bounds withEdge:edge];
		} else {
			remainder = [self subtractRect:CGRectIntersection(self.scrollView.bounds, newRootViewControllerFrame) fromRect:self.scrollView.bounds withEdge:edge];
		}
		
		BOOL isReversed = NO;
		if([layouter respondsToSelector:@selector(isReversed)]) {
			isReversed = [layouter isReversed];
		}
		
		NSArray *viewControllersArray = self.loadedControllers[@(position)];
		[viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index, BOOL *stop) {
			
			CGRect nextFrame =  [layouter currentFrameForViewController:viewController withIndex:index atPosition:position finalFrame:[self.finalFrames[@(viewController.hash)] CGRectValue] contentOffset:offset inStackController:self];
			
			// If using a reversed layouter adjust the frame to normal
			CGRect adjustedFrame = nextFrame;
			
			if(index > 0) {
				if(isReversed) {
					switch (position) {
						case SCStackViewControllerPositionTop: {
							NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index + 1, viewControllersArray.count - index - 1)];
							CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.sc_viewHeight"] floatValue];
							adjustedFrame.origin.y = [self maximumInsetForPosition:position].y + totalSize;
							break;
						}
						case SCStackViewControllerPositionLeft: {
							NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index + 1, viewControllersArray.count - index - 1)];
							CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.sc_viewWidth"] floatValue];
							adjustedFrame.origin.x = [self maximumInsetForPosition:position].x + totalSize;
							break;
						}
						case SCStackViewControllerPositionBottom: {
							NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index, viewControllersArray.count - index)];
							CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.sc_viewHeight"] floatValue];
							adjustedFrame.origin.y = CGRectGetHeight(self.view.bounds) + [self maximumInsetForPosition:position].y - totalSize;
							break;
						}
						case SCStackViewControllerPositionRight: {
							NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index, viewControllersArray.count - index)];
							CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.sc_viewWidth"] floatValue];
							adjustedFrame.origin.x = CGRectGetWidth(self.view.bounds) + [self maximumInsetForPosition:position].x - totalSize;
							break;
						}
					}
				} else {
					NSArray *previousViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(0, index)];
					for(UIViewController *controller in previousViewControllers) {
						adjustedFrame = [self subtractRect:controller.view.frame fromRect:adjustedFrame withEdge:edge];
					}
				}
			}
			
			CGRect intersection = CGRectIntersection(remainder, adjustedFrame);
			
			// If a view controller's frame does intersect the remainder then it's visible
			BOOL visible = ((position == SCStackViewControllerPositionLeft || position == SCStackViewControllerPositionRight) && CGRectGetWidth(intersection) > 0.0f);
			visible = visible || ((position == SCStackViewControllerPositionTop || position == SCStackViewControllerPositionBottom) && CGRectGetHeight(intersection) > 0.0f);
			
			visible = visible && self.isViewVisible;
			
			if(visible) {
				
				switch (position) {
					case SCStackViewControllerPositionTop:
					case SCStackViewControllerPositionBottom:
					{
						[self.visiblePercentages setObject:@(roundf((CGRectGetHeight(intersection) * 1000) / CGRectGetHeight(adjustedFrame))/1000.0f) forKey:@([viewController hash])];
						break;
					}
					case SCStackViewControllerPositionLeft:
					case SCStackViewControllerPositionRight:
					{
						[self.visiblePercentages setObject:@(roundf((CGRectGetWidth(intersection) * 1000) / CGRectGetWidth(adjustedFrame))/1000.0f) forKey:@([viewController hash])];
						break;
					}
				}
				
				// And if it's visible then we prepare for the next view controller by reducing the remainder some more
				remainder = [self subtractRect:CGRectIntersection(remainder, adjustedFrame) fromRect:remainder withEdge:edge];
				
				if(shouldStackControllersAboveRoot) {
					rootRemainder = [self subtractRect:CGRectIntersection(rootRemainder, adjustedFrame) fromRect:rootRemainder withEdge:edge];
				}
			}
			
			// Finally, trigger appearance callbacks and new frame
			if(visible && ![self.visibleControllers containsObject:viewController]) {
				[self.visibleControllers addObject:viewController];
				[viewController beginAppearanceTransition:YES animated:NO];
				[viewController.view setFrame:nextFrame];
				[viewController endAppearanceTransition];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					if([self.delegate respondsToSelector:@selector(stackViewController:didShowViewController:position:)]) {
						[self.delegate stackViewController:self didShowViewController:viewController position:position];
					}
				});
				
			} else if(!visible && [self.visibleControllers containsObject:viewController]) {
				[self.visibleControllers removeObject:viewController];
				[viewController beginAppearanceTransition:NO animated:NO];
				[viewController.view setFrame:nextFrame];
				[viewController endAppearanceTransition];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					if([self.delegate respondsToSelector:@selector(stackViewController:didHideViewController:position:)]) {
						[self.delegate stackViewController:self didHideViewController:viewController position:position];
					}
				});
				
			} else {
				[viewController.view setFrame:nextFrame];
			}
			
			if([layouter respondsToSelector:@selector(sublayerTransformForViewController:withIndex:atPosition:finalFrame:contentOffset:inStackController:)]) {
				CATransform3D transform = [layouter sublayerTransformForViewController:viewController
																			 withIndex:index
																			atPosition:position
																			finalFrame:[self.finalFrames[@(viewController.hash)] CGRectValue]
																		 contentOffset:offset
																	 inStackController:self];
				[viewController.view.layer setSublayerTransform:transform];
			}
		}];
	}
	
	// Figure out if the root is still visible or not and call its appearance methods
	BOOL hasVerticalControllers = ([self.loadedControllers[@(SCStackViewControllerPositionTop)] count] || [self.loadedControllers[@(SCStackViewControllerPositionBottom)] count]);
	BOOL hasHorizontalController = ([self.loadedControllers[@(SCStackViewControllerPositionLeft)] count] || [self.loadedControllers[@(SCStackViewControllerPositionRight)] count]);
	
	BOOL visible = (hasHorizontalController && CGRectGetWidth(rootRemainder) > 0.0f);
	visible = visible || (hasVerticalControllers && CGRectGetHeight(rootRemainder) > 0.0f);
	visible = visible || (!hasHorizontalController && !hasVerticalControllers);
	
	visible = visible && self.isViewVisible;
	
	if(visible && !self.isRootViewControllerVisible) {
		self.isRootViewControllerVisible = YES;
		[self.rootViewController beginAppearanceTransition:YES animated:NO];
		[self.rootViewController.view setFrame:newRootViewControllerFrame];
		[self.rootViewController endAppearanceTransition];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if([self.delegate respondsToSelector:@selector(stackViewController:didShowViewController:position:)]) {
				[self.delegate stackViewController:self didShowViewController:self.rootViewController position:-1];
			}
		});
		
	} else if(!visible && self.isRootViewControllerVisible) {
		self.isRootViewControllerVisible = NO;
		[self.rootViewController beginAppearanceTransition:NO animated:NO];
		[self.rootViewController.view setFrame:newRootViewControllerFrame];
		[self.rootViewController endAppearanceTransition];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if([self.delegate respondsToSelector:@selector(stackViewController:didHideViewController:position:)]) {
				[self.delegate stackViewController:self didHideViewController:self.rootViewController position:-1];
			}
		});
		
	} else {
		
		[self.rootViewController.view setFrame:newRootViewControllerFrame];
		
		if(hasVerticalControllers) {
			[self.visiblePercentages setObject:@(roundf((CGRectGetHeight(rootRemainder) * 1000) / CGRectGetHeight(newRootViewControllerFrame))/1000.0f) forKey:@([self.rootViewController hash])];
		} else if(hasHorizontalController) {
			[self.visiblePercentages setObject:@(roundf((CGRectGetWidth(rootRemainder) * 1000) / CGRectGetWidth(newRootViewControllerFrame))/1000.0f) forKey:@([self.rootViewController hash])];
		}
	}
	
	if([activeLayouter respondsToSelector:@selector(sublayerTransformForRootViewController:contentOffset:inStackController:)]) {
		CATransform3D transform = [activeLayouter sublayerTransformForRootViewController:self.rootViewController
																		   contentOffset:offset
																	   inStackController:self];
		[self.rootViewController.view.layer setSublayerTransform:transform];
	}
}

#pragma mark Pagination

- (void)adjustTargetContentOffset:(inout CGPoint *)targetContentOffset withVelocity:(CGPoint)velocity
{
	if(!self.pagingEnabled && self.continuousNavigationEnabled) {
		return;
	}
	
	for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <= SCStackViewControllerPositionRight; position++) {
		
		BOOL isReversed = NO;
		if([self.layouters[@(position)] respondsToSelector:@selector(isReversed)]) {
			isReversed = [self.layouters[@(position)] isReversed];
		}
		
		CGPoint adjustedOffset = *targetContentOffset;
		
		if(isReversed) {
			if(position == SCStackViewControllerPositionLeft && targetContentOffset->x < 0.0f) {
				adjustedOffset.x = [self maximumInsetForPosition:position].x - targetContentOffset->x;
			}
			else if(position == SCStackViewControllerPositionRight && targetContentOffset->x >= 0.0f) {
				adjustedOffset.x = [self maximumInsetForPosition:position].x - targetContentOffset->x;
			}
			else if(position == SCStackViewControllerPositionTop && targetContentOffset->y < 0.0f) {
				adjustedOffset.y = [self maximumInsetForPosition:position].y - targetContentOffset->y;
			}
			else if(position == SCStackViewControllerPositionBottom && targetContentOffset->y >= 0.0f) {
				adjustedOffset.y = [self maximumInsetForPosition:position].y - targetContentOffset->y;
			}
		}
		
		NSArray *viewControllersArray = self.loadedControllers[@(position)];
		
		__block BOOL keepGoing = YES;
		
		// Enumerate through all the VCs and figure out which one contains the targeted offset
		[viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index, BOOL *stop) {
			
			CGRect frame = [self.finalFrames[@(viewController.hash)] CGRectValue];
			frame.origin.x = frame.origin.x > 0.0f ? CGRectGetMinX(frame) - CGRectGetWidth(self.view.bounds) : CGRectGetMinX(frame);
			frame.origin.y = frame.origin.y > 0.0f ? CGRectGetMinY(frame) - CGRectGetHeight(self.view.bounds) : CGRectGetMinY(frame);
			
			frame = CGRectOffset(CGRectInset(frame, -0.5f, -0.5f), 0.5f, 0.5f); //consider the maximum X and maximum Y edges
			
			if(CGRectContainsPoint(frame, adjustedOffset)) {
				
				// If the velocity is zero then jump to the closest navigation step
				if(CGPointEqualToPoint(CGPointZero, velocity)) {
					
					switch (position) {
						case SCStackViewControllerPositionTop:
						case SCStackViewControllerPositionBottom:
						{
							CGPoint previousStepOffset = [self nextStepOffsetForViewController:viewController position:position velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:*targetContentOffset paginating:YES];
							CGPoint nextStepOffset = [self nextStepOffsetForViewController:viewController position:position velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:*targetContentOffset paginating:YES];
							
							*targetContentOffset = ABS(targetContentOffset->y - previousStepOffset.y) > ABS(targetContentOffset->y - nextStepOffset.y) ? nextStepOffset : previousStepOffset;
							break;
						}
						case SCStackViewControllerPositionLeft:
						case SCStackViewControllerPositionRight:
						{
							CGPoint previousStepOffset = [self nextStepOffsetForViewController:viewController position:position velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:*targetContentOffset paginating:YES];
							CGPoint nextStepOffset = [self nextStepOffsetForViewController:viewController position:position velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:*targetContentOffset paginating:YES];
							
							*targetContentOffset = ABS(targetContentOffset->x - previousStepOffset.x) > ABS(targetContentOffset->x - nextStepOffset.x) ? nextStepOffset : previousStepOffset;
							break;
						}
					}
					
				} else {
					// Calculate the next step of the pagination (either a navigationStep or a controller edge)
					*targetContentOffset = [self nextStepOffsetForViewController:viewController position:position velocity:velocity reversed:isReversed contentOffset:*targetContentOffset paginating:YES];
				}
				
				keepGoing = NO;
				*stop = YES;
			}
		}];
		
		if(!keepGoing) {
			return;
		}
	}
}

#pragma mark Shared

- (CGPoint)nextStepOffsetForViewController:(UIViewController *)viewController
								  position:(SCStackViewControllerPosition)position
								  velocity:(CGPoint)velocity
								  reversed:(BOOL)isReversed
							 contentOffset:(CGPoint)contentOffset
								paginating:(BOOL)paginating

{
	CGPoint nextStepOffset = CGPointZero;
	
	NSArray *navigationSteps = self.navigationSteps[@([viewController hash])];
	
	CGRect finalFrame = [self.finalFrames[@(viewController.hash)] CGRectValue];
	
	// Reverse the step search when folding view controllers
	if((velocity.y > 0.0f && position == SCStackViewControllerPositionTop)    || (velocity.x > 0.0f && position == SCStackViewControllerPositionLeft) ||
	   (velocity.y < 0.0f && position == SCStackViewControllerPositionBottom) || (velocity.x < 0.0f && position == SCStackViewControllerPositionRight)) {
		navigationSteps = [[navigationSteps reverseObjectEnumerator] allObjects];
	}
	
	// Fetch the next navigation step and calculate its offset
	for(SCStackNavigationStep *nextStep in navigationSteps) {
		
		if(position == SCStackViewControllerPositionTop) {
			if(isReversed) {
				nextStepOffset.y = [self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame) + CGRectGetHeight(finalFrame) * (1.0f - nextStep.percentage);
			} else {
				nextStepOffset.y = CGRectGetMaxY(finalFrame) - CGRectGetHeight(finalFrame) * nextStep.percentage;
			}
		} else if(position == SCStackViewControllerPositionLeft) {
			if(isReversed) {
				nextStepOffset.x = [self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame) + CGRectGetWidth(finalFrame) * (1.0f - nextStep.percentage);
			} else {
				nextStepOffset.x = CGRectGetMaxX(finalFrame) - CGRectGetWidth(finalFrame) * nextStep.percentage;
			}
		} else if(position == SCStackViewControllerPositionBottom) {
			if(isReversed) {
				nextStepOffset.y = [self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame) + CGRectGetHeight(finalFrame) * nextStep.percentage + CGRectGetHeight(self.view.bounds);
			} else {
				nextStepOffset.y = CGRectGetMinY(finalFrame) + CGRectGetHeight(finalFrame) * nextStep.percentage - CGRectGetHeight(self.view.bounds);
			}
		} else if(position == SCStackViewControllerPositionRight) {
			if(isReversed) {
				nextStepOffset.x = [self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame) + CGRectGetWidth(finalFrame) * nextStep.percentage + CGRectGetWidth(self.view.bounds);
			} else {
				nextStepOffset.x = CGRectGetMinX(finalFrame) + CGRectGetWidth(finalFrame) * nextStep.percentage - CGRectGetWidth(self.view.bounds);
			}
		}
		
		nextStepOffset.x = roundf(nextStepOffset.x);
		nextStepOffset.y = roundf(nextStepOffset.y);
		
		// Cache the steps to avoid having to recalculate them later. Will clear the cache when the pagination is done.
		[self.stepsForOffsets setObject:nextStep forKey:[NSValue valueWithCGPoint:nextStepOffset]];
		
		if(!paginating) {
			// Trick the calculations into blocking
			if(nextStep.blockType == SCStackNavigationStepBlockTypeForward) {
				nextStepOffset.y -= 0.01f;
			}
			
			if(nextStep.blockType == SCStackNavigationStepBlockTypeReverse) {
				nextStepOffset.y += 0.01f;
			}
		}
		
		if((velocity.y > 0.0f && nextStepOffset.y > contentOffset.y) || (velocity.y < 0.0f && nextStepOffset.y < contentOffset.y) ||
		   (velocity.x > 0.0f && nextStepOffset.x > contentOffset.x) || (velocity.x < 0.0f && nextStepOffset.x < contentOffset.x)) {
			return nextStepOffset;
		}
	}
	
	// If no navigation step is found use the view controller's bounds
	if(velocity.y > 0.0f && isReversed) {
		nextStepOffset.y = [self maximumInsetForPosition:position].y - CGRectGetMinY(finalFrame);
	} else if(velocity.x > 0.0f && isReversed) {
		nextStepOffset.x = [self maximumInsetForPosition:position].x - CGRectGetMinX(finalFrame);
	}
	
	else if(velocity.y < 0.0f && isReversed) {
		nextStepOffset.y = [self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame);
	} else if(velocity.x < 0.0f && isReversed) {
		nextStepOffset.x = [self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame);
	}
	
	else if(velocity.y > 0.0f && !isReversed) {
		nextStepOffset.y = CGRectGetMaxY(finalFrame);
	} else if(velocity.x > 0.0f && !isReversed) {
		nextStepOffset.x = CGRectGetMaxX(finalFrame);
	}
	
	else if(velocity.y < 0.0f && !isReversed) {
		nextStepOffset.y = CGRectGetMinY(finalFrame);
	}
	else if(velocity.x < 0.0f && !isReversed) {
		nextStepOffset.x = CGRectGetMinX(finalFrame);
	}
	
	if(position == SCStackViewControllerPositionBottom) {
		nextStepOffset.y = nextStepOffset.y + (isReversed ? CGRectGetHeight(self.view.bounds) : -CGRectGetHeight(self.view.bounds));
	}
	
	if(position == SCStackViewControllerPositionRight) {
		nextStepOffset.x = nextStepOffset.x + (isReversed ? CGRectGetWidth(self.view.bounds) : -CGRectGetWidth(self.view.bounds));
	}
	
	return nextStepOffset;
}

#pragma mark - SCStackViewControllerViewDelegate

- (void)stackViewControllerViewWillChangeFrame:(SCStackViewControllerView *)stackViewControllerView
{
	[self.scrollView setDelegate:nil];
}

- (void)stackViewControllerViewDidChangeFrame:(SCStackViewControllerView *)stackViewControllerView
{
	[self.scrollView setDelegate:self];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[self updateFramesAndTriggerAppearanceCallbacks];
	
	if(self.didIgnoreNavigationalConstraints) {
		[self updateBoundsUsingNavigationContraints];
		self.didIgnoreNavigationalConstraints = NO;
	}
	
	if([self.delegate respondsToSelector:@selector(stackViewController:didNavigateToOffset:)]) {
		[self.delegate stackViewController:self didNavigateToOffset:self.scrollView.contentOffset];
	}
}

- (void)triggerNavigationStepsDelegateCalls
{
	if(!self.pagingEnabled && self.continuousNavigationEnabled) {
		return;
	}
	
	UIViewController *lastVisibleViewController = [self.visibleViewControllers lastObject];
	
	SCStackNavigationStep *step;
	if(lastVisibleViewController == nil) {
		step = [SCStackNavigationStep navigationStepWithPercentage:0.0f];
	} else {
		step = [self.stepsForOffsets objectForKey:[NSValue valueWithCGPoint:self.scrollView.contentOffset]];
		
		if(step == nil) {
			step = [SCStackNavigationStep navigationStepWithPercentage:1.0f];
		}
	}
	
	if([self.delegate respondsToSelector:@selector(stackViewController:didNavigateToStep:inViewController:)]) {
		[self.delegate stackViewController:self didNavigateToStep:step inViewController:lastVisibleViewController];
	}
	
	[self.stepsForOffsets removeAllObjects];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	//FIXME: Without this the scroll might get stuck in between pages, if setting the insets before the animation is finished. With it jumping steps is harder. Find another way of fixing it.
	if(self.scrollView.isTracking) {
		return;
	}
	
	[self updateBoundsUsingNavigationContraints];
	[self triggerNavigationStepsDelegateCalls];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
	[self updateBoundsUsingNavigationContraints];
	[self triggerNavigationStepsDelegateCalls];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if(decelerate == NO) {
		[self updateBoundsUsingNavigationContraints];
		[self triggerNavigationStepsDelegateCalls];
	}
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
	// Bouncing target content offset when fix.
	// When trying to adjust content offset while bouncing the velocity drops down to almost nothing.
	// Seems to be an internal UIScrollView issue
	if(self.scrollView.contentOffset.y < -self.scrollView.contentInset.top) {
		targetContentOffset->y = - roundf(self.scrollView.contentInset.top);
	} else if(self.scrollView.contentOffset.x < -self.scrollView.contentInset.left) {
		targetContentOffset->x = - roundf(self.scrollView.contentInset.left);
	} else if(self.scrollView.contentOffset.y > self.scrollView.contentInset.bottom) {
		targetContentOffset->y = roundf(self.scrollView.contentInset.bottom);
	} else if(self.scrollView.contentOffset.x > self.scrollView.contentInset.right) {
		targetContentOffset->x = roundf(self.scrollView.contentInset.right);
	}
	// Normal pagination
	else {
		[self adjustTargetContentOffset:targetContentOffset withVelocity:velocity];
	}
}

#pragma mark - Rotation Handling

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	// Leave enough room for the scrollView's content to adjust. Will be recalculated on layoutSubviews
	[self.scrollView setContentInset:UIEdgeInsetsMake(CGFLOAT_MAX, CGFLOAT_MAX, CGFLOAT_MAX, CGFLOAT_MAX)];
}

#pragma mark - Helpers

- (CGPoint)maximumInsetForPosition:(SCStackViewControllerPosition)position
{
	switch (position) {
		case SCStackViewControllerPositionTop:
			return CGPointMake(0, -[[self.loadedControllers[@(position)] valueForKeyPath:@"@sum.sc_viewHeight"] floatValue]);
		case SCStackViewControllerPositionLeft:
			return CGPointMake(-[[self.loadedControllers[@(position)] valueForKeyPath:@"@sum.sc_viewWidth"] floatValue], 0);
		case SCStackViewControllerPositionBottom:
			return CGPointMake(0, [[self.loadedControllers[@(position)] valueForKeyPath:@"@sum.sc_viewHeight"] floatValue]);
		case SCStackViewControllerPositionRight:
			return CGPointMake([[self.loadedControllers[@(position)] valueForKeyPath:@"@sum.sc_viewWidth"] floatValue], 0);
		default:
			return CGPointZero;
	}
}

- (SCStackViewControllerPosition)positionForViewController:(UIViewController *)viewController
{
	for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <= SCStackViewControllerPositionRight; position++) {
		if([self.loadedControllers[@(position)] containsObject:viewController]) {
			return position;
		}
	}
	
	return -1;
}

- (CGRectEdge)edgeFromOffset:(CGPoint)offset
{
	CGRectEdge edge = -1;
	
	if(offset.x > 0.0f) {
		edge = CGRectMinXEdge;
	} else if(offset.x < 0.0f) {
		edge = CGRectMaxXEdge;
	} else if(offset.y > 0.0f) {
		edge = CGRectMinYEdge;
	} else if(offset.y < 0.0f) {
		edge = CGRectMaxYEdge;
	}
	
	return edge;
}

UIEdgeInsets UIEdgeInsetsIntegral(UIEdgeInsets edgeInsets)
{
	edgeInsets.top = roundf(edgeInsets.top);
	edgeInsets.left = roundf(edgeInsets.left);
	edgeInsets.bottom = roundf(edgeInsets.bottom);
	edgeInsets.right = roundf(edgeInsets.right);
	
	return edgeInsets;
}

- (CGRect)subtractRect:(CGRect)r2 fromRect:(CGRect)r1 withEdge:(CGRectEdge)edge
{
	if(CGRectEqualToRect(r1, r2)) {
		return CGRectZero;
	}
	
	CGRect intersection = CGRectIntersection(r1, r2);
	if (CGRectIsNull(intersection)) {
		return r1;
	}
	
	float chopAmount = (edge == CGRectMinXEdge || edge == CGRectMaxXEdge) ? CGRectGetWidth(intersection) : CGRectGetHeight(intersection);
	
	CGRect remainder, throwaway;
	CGRectDivide(r1, &throwaway, &remainder, chopAmount, edge);
	return remainder;
}

@end


@implementation UIViewController (SCStackViewController)

- (SCStackViewController *)sc_stackViewController
{
	UIResponder *responder = self;
	while ((responder = [responder nextResponder])) {
		if ([responder isKindOfClass:[SCStackViewController class]])  {
			return (SCStackViewController *)responder;
		}
	}
	return nil;
}

- (CGFloat)sc_viewWidth
{
	return CGRectGetWidth(self.view.bounds);
}

- (CGFloat)sc_viewHeight
{
	return CGRectGetHeight(self.view.bounds);
}

@end
