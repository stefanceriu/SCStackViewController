//
//  SCViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCRootViewController.h"

#import "SCStackViewController.h"
#import "SCScrollView.h"

#import "SCStackNavigationStep.h"
#import "SCEasingFunction.h"

#import "SCMainViewController.h"
#import "SCOverlayView.h"

#import "SCStackLayouter.h"
#import "SCParallaxStackLayouter.h"
#import "SCSlidingStackLayouter.h"
#import "SCReversedStackLayouter.h"
#import "SCResizingStackLayouter.h"

#import "SCImageViewController.h"
#import "SCImagesLayouter.h"

#import "SCMenuViewController.h"
#import "SCMenusLayouter.h"

#import "SCTitleBarViewController.h"

#import "SCModalViewController.h"
#import "SCModalLayouter.h"

@interface SCRootViewController () <SCStackViewControllerDelegate, SCOverlayViewDelegate, SCStackedViewControllerDelegate, SCMainViewControllerDelegate>

@property (nonatomic, strong) IBOutlet SCStackViewController *stackViewController;
@property (nonatomic, strong) IBOutlet SCMainViewController *mainViewController;
@property (nonatomic, strong) SCOverlayView *overlayView;

@property (nonatomic, strong) UIButton *leftMenuButton;
@property (nonatomic, strong) UIButton *rightMenuButton;

@property (nonatomic, assign) SCStackDemoType currentDemoType;

@end

@implementation SCRootViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.overlayView = [SCOverlayView overlayView];
	[self.overlayView setDelegate:self];
	[self.overlayView setAlpha:0.0f];
	[self.mainViewController.view addSubview:self.overlayView];
	[self.overlayView setFrame:self.mainViewController.view.bounds];
	
	
	[self.stackViewController willMoveToParentViewController:self];
	
	[self.view addSubview:self.stackViewController.view];
	[self.stackViewController.view setFrame:self.view.bounds];
	
	[self addChildViewController:self.stackViewController];
	[self.stackViewController didMoveToParentViewController:self];
}

- (void)viewDidAppear:(BOOL)animated
{
	[self _setupImagesDemo];
}

- (void)setCurrentDemoType:(SCStackDemoType)currentDemoType
{
	_currentDemoType = currentDemoType;
	
	for(NSUInteger i=SCStackViewControllerPositionTop; i<=SCStackViewControllerPositionRight; i++) {
		[self.stackViewController popToRootViewControllerFromPosition:(SCStackViewControllerPosition)i
															 animated:YES
														   completion:nil];
	}
	
	switch (currentDemoType) {
		case SCStackDemoTypeVerticalImages: {
			[self _setupImagesDemo];
			break;
		}
		case SCStackDemoTypeSideMenus: {
			[self _setupSideMenusDemo];
			break;
		}
		case SCStackDemoTypeTitleBar: {
			[self _setupTitleBarDemo];
			break;
		}
		case SCStackDemoTypeModal: {
			[self _setupModalDemo];
			break;
		}
		case SCStackDemoTypeGeneric: {
			[self _setupGenericDemo];
			break;
		}
	}
}

#pragma mark - SCMainViewControllerDelegate

- (void)mainViewController:(SCMainViewController *)mainViewController didChangeDemoType:(SCStackDemoType)type
{
	self.currentDemoType = type;
}

- (void)mainViewController:(SCMainViewController *)mainViewController didChangeLayouterType:(SCStackLayouterType)type
{
	static NSDictionary *typeToLayouter;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		typeToLayouter = (@{
							@(SCStackLayouterTypePlain)         : [SCStackLayouter class],
							@(SCStackLayouterTypeSliding)       : [SCSlidingStackLayouter class],
							@(SCStackLayouterTypeParallax)      : [SCParallaxStackLayouter class],
							@(SCStackLayouterTypeReversed)      : [SCReversedStackLayouter class],
							@(SCStacklayouterTypePlainResizing) : [SCResizingStackLayouter class]
							});
	});
	
	id<SCStackLayouterProtocol> layouter = [[typeToLayouter[@(type)] alloc] init];
	[layouter setShouldStackControllersAboveRoot:YES];
	[self _registerLayouter:layouter];
}

- (void)mainViewController:(SCMainViewController *)mainViewController didChangeAnimationType:(SCEasingFunctionType)type
{
	[self.stackViewController setEasingFunction:[SCEasingFunction easingFunctionWithType:type]];
}

- (void)mainViewController:(SCMainViewController *)mainViewController didChangeAnimationDuration:(NSTimeInterval)duration
{
	[self.stackViewController setAnimationDuration:duration];
}

#pragma mark - SCStackedViewControllerDelegate

- (void)stackedViewControllerDidRequestPush:(SCImageViewController *)menuViewController
{
	UIViewController<SCStackedViewControllerProtocol> *newViewController;
	
	switch (self.currentDemoType) {
		case SCStackDemoTypeVerticalImages: {
			newViewController = [[SCImageViewController alloc] initWithPosition:menuViewController.position];
			break;
		}
		case SCStackDemoTypeSideMenus: {
			newViewController = [[SCMenuViewController alloc] initWithPosition:menuViewController.position];
			break;
		}
		case SCStackDemoTypeGeneric: {
			newViewController = [[SCMenuViewController alloc] initWithPosition:menuViewController.position];
			break;
		}
		default: {
			break;
		}
	}
	
	[newViewController setDelegate:self];
	
	[self.stackViewController pushViewController:newViewController
									  atPosition:menuViewController.position
										  unfold:YES
										animated:YES
									  completion:nil];
}

- (void)stackedViewControllerDidRequestPop:(SCImageViewController *)menuViewController
{
	[self.stackViewController popViewControllerAtPosition:menuViewController.position
												 animated:YES
											   completion:nil];
}

#pragma mark - SCStackViewControllerDelegate

- (void)stackViewController:(SCStackViewController *)stackViewController didNavigateToOffset:(CGPoint)offset
{
	[self.overlayView setAlpha:ABS((offset.x ?: offset.y) / 300.0f)];
	
	for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <= SCStackViewControllerPositionRight; position++) {
		for(SCImageViewController *viewController in [self.stackViewController viewControllersForPosition:position]) {
			[viewController setVisiblePercentage:[stackViewController visiblePercentageForViewController:viewController]];
		}
	}
	
	[self.mainViewController setVisiblePercentage:[stackViewController visiblePercentageForViewController:self.mainViewController]];
	
	
	[self _updateMenuButtonsWithContentOffset:offset];
}

#pragma mark - SCOverlayViewDelegate

- (void)overlayViewDidReceiveTap:(SCOverlayView *)overlayView
{
	[self.stackViewController navigateToViewController:self.stackViewController.rootViewController animated:YES completion:nil];
}

#pragma mark - Private

- (void)_setupImagesDemo
{
	SCImagesLayouter *imagesLayouter = [[SCImagesLayouter alloc] init];
	[imagesLayouter setShouldStackControllersAboveRoot:YES];
	[self _registerLayouter:imagesLayouter];
	
	[self.stackViewController setAnimationDuration:1.25f];
	[self.stackViewController setEasingFunction:[SCEasingFunction easingFunctionWithType:SCEasingFunctionTypeElasticEaseOut]];
	
	SCImageViewController *topViewController = [[SCImageViewController alloc] initWithPosition:SCStackViewControllerPositionTop];
	[topViewController setDelegate:self];
	
	[self.stackViewController pushViewController:topViewController
									  atPosition:SCStackViewControllerPositionTop
										  unfold:YES
										animated:YES
									  completion:nil];
	
	[self _hideMenuButtons];
	[self _enableOverlayView];
	[self.mainViewController hideAnimationOptionsAnimated:YES];
}

- (void)_setupSideMenusDemo
{
	SCMenusLayouter *menusLayouter = [[SCMenusLayouter alloc] init];
	[menusLayouter setShouldStackControllersAboveRoot:YES];
	[self _registerLayouter:menusLayouter];
	
	[self.stackViewController setAnimationDuration:0.75f];
	[self.stackViewController setEasingFunction:[SCEasingFunction easingFunctionWithType:SCEasingFunctionTypeExponentialEaseOut]];
	
	SCMenuViewController *leftViewController = [[SCMenuViewController alloc] initWithPosition:SCStackViewControllerPositionLeft];
	[leftViewController setDelegate:self];
	
	[self.stackViewController pushViewController:leftViewController
									  atPosition:SCStackViewControllerPositionLeft
										  unfold:YES
										animated:YES
									  completion:nil];
	
	SCMenuViewController *rightViewController = [[SCMenuViewController alloc] initWithPosition:SCStackViewControllerPositionRight];
	[rightViewController setDelegate:self];
	
	[self.stackViewController pushViewController:rightViewController
									  atPosition:SCStackViewControllerPositionRight
										  unfold:NO
										animated:NO
									  completion:nil];
	
	[self _showMenuButtons];
	[self _enableOverlayView];
	[self.mainViewController hideAnimationOptionsAnimated:YES];
}

- (void)_setupTitleBarDemo
{
	SCStackLayouter *titleBarLayouter = [[SCStackLayouter alloc] init];
	[titleBarLayouter setShouldStackControllersAboveRoot:YES];
	[self _registerLayouter:titleBarLayouter];
	
	[self.stackViewController setAnimationDuration:1.0f];
	[self.stackViewController setEasingFunction:[SCEasingFunction easingFunctionWithType:SCEasingFunctionTypeBounceEaseOut]];
	
	SCTitleBarViewController *topViewController = [[SCTitleBarViewController alloc] initWithPosition:SCStackViewControllerPositionTop];
	[topViewController setDelegate:self];
	
	[self.stackViewController pushViewController:topViewController atPosition:SCStackViewControllerPositionTop unfold:NO animated:NO completion:^{
		
		SCStackNavigationStep *minimizedStep = [SCStackNavigationStep navigationStepWithPercentage:0.1f blockType:SCStackNavigationStepBlockTypeReverse];
		SCStackNavigationStep *intermediateStep = [SCStackNavigationStep navigationStepWithPercentage:0.3f];
		
		[self.stackViewController registerNavigationSteps:@[minimizedStep,intermediateStep] forViewController:topViewController];
		
		[self.stackViewController navigateToStep:minimizedStep inViewController:topViewController animated:YES completion:nil];
	}];
	
	[self _hideMenuButtons];
	[self _disableOverlayView];
	[self.mainViewController hideAnimationOptionsAnimated:YES];
}

- (void)_setupModalDemo
{
	SCModalLayouter *modalLayouter = [[SCModalLayouter alloc] init];
	[modalLayouter setShouldStackControllersAboveRoot:YES];
	[self _registerLayouter:modalLayouter];
	
	[self.stackViewController setAnimationDuration:1.5f];
	[self.stackViewController setEasingFunction:[SCEasingFunction easingFunctionWithType:SCEasingFunctionTypeElasticEaseOut]];
	
	SCModalViewController *modalViewController = [[SCModalViewController alloc] initWithPosition:SCStackViewControllerPositionBottom];
	[modalViewController setDelegate:self];
	
	[self.stackViewController pushViewController:modalViewController
									  atPosition:SCStackViewControllerPositionBottom
										  unfold:YES
										animated:YES
									  completion:nil];
	
	[self _hideMenuButtons];
	[self _disableOverlayView];
	[self.mainViewController hideAnimationOptionsAnimated:YES];
}

- (void)_setupGenericDemo
{
	SCStackLayouter *plainLayouter = [[SCStackLayouter alloc] init];
	[plainLayouter setShouldStackControllersAboveRoot:YES];
	[self _registerLayouter:plainLayouter];
	
	[self.stackViewController setAnimationDuration:0.25f];
	[self.stackViewController setEasingFunction:[SCEasingFunction easingFunctionWithType:SCEasingFunctionTypeLinear]];
	
	SCMenuViewController *leftViewController = [[SCMenuViewController alloc] initWithPosition:SCStackViewControllerPositionLeft];
	[leftViewController setDelegate:self];
	
	[self.stackViewController pushViewController:leftViewController
									  atPosition:SCStackViewControllerPositionLeft
										  unfold:NO
										animated:NO
									  completion:nil];
	
	SCMenuViewController *rightViewController = [[SCMenuViewController alloc] initWithPosition:SCStackViewControllerPositionRight];
	[rightViewController setDelegate:self];
	
	[self.stackViewController pushViewController:rightViewController
									  atPosition:SCStackViewControllerPositionRight
										  unfold:YES
										animated:YES
									  completion:nil];
	
	[self _showMenuButtons];
	[self _enableOverlayView];
	[self.mainViewController showAnimationOptionsAnimated:YES];
}

- (void)_registerLayouter:(id<SCStackLayouterProtocol>)layouter
{
	for(NSUInteger i=SCStackViewControllerPositionTop; i<=SCStackViewControllerPositionRight; i++) {
		[self.stackViewController registerLayouter:layouter forPosition:(SCStackViewControllerPosition)i animated:NO];
	}
}

- (void)_showMenuButtons
{
	if(self.leftMenuButton == nil) {
		self.leftMenuButton = [UIButton buttonWithType:UIButtonTypeCustom];
		[self.leftMenuButton setFrame:CGRectMake(0.0f, 20.0f, 40.0f, 64.0f)];
		[self.leftMenuButton setImage:[UIImage imageNamed:@"left-menu-tab.png"] forState:UIControlStateNormal];
		[self.leftMenuButton setAutoresizingMask:UIViewAutoresizingFlexibleRightMargin];
		[self.leftMenuButton setAlpha:0.0f];
		[self.leftMenuButton addTarget:self action:@selector(_onLeftMenuButtonTap:) forControlEvents:UIControlEventTouchUpInside];
		[self.stackViewController.view addSubview:self.leftMenuButton];
	}
	
	if(self.rightMenuButton == nil) {
		self.rightMenuButton = [UIButton buttonWithType:UIButtonTypeCustom];
		[self.rightMenuButton setFrame:CGRectMake(CGRectGetWidth(self.view.bounds) - 40.0f, 20.0f, 40.0f, 64.0f)];
		[self.rightMenuButton setImage:[UIImage imageNamed:@"right-menu-tab.png"] forState:UIControlStateNormal];
		[self.rightMenuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
		[self.rightMenuButton setAlpha:0.0f];
		[self.rightMenuButton addTarget:self action:@selector(_onRightMenuButtonTap:) forControlEvents:UIControlEventTouchUpInside];
		[self.stackViewController.view addSubview:self.rightMenuButton];
	}
	
	[UIView animateWithDuration:0.25f animations:^{
		[self.leftMenuButton setAlpha:1.0f];
		[self.rightMenuButton setAlpha:1.0f];
	}];
}

- (void)_hideMenuButtons
{
	[UIView animateWithDuration:0.25f animations:^{
		[self.leftMenuButton setAlpha:0.0f];
		[self.rightMenuButton setAlpha:0.0f];
	}];
}

- (void)_enableOverlayView
{
	[self.overlayView setHidden:NO];
}

- (void)_disableOverlayView
{
	[self.overlayView setHidden:YES];
}

- (void)_onLeftMenuButtonTap:(UIButton *)sender
{
	if(self.stackViewController.scrollView.contentOffset.x >= 0.0f) {
		[self.stackViewController navigateToViewController:[[self.stackViewController viewControllersForPosition:SCStackViewControllerPositionLeft] firstObject]
												  animated:YES
												completion:nil];
	} else if(self.stackViewController.scrollView.contentOffset.x < 0.0f) {
		[self.stackViewController navigateToViewController:self.stackViewController.rootViewController animated:YES completion:nil];
	}
}

- (void)_onRightMenuButtonTap:(UIButton *)sender
{
	if(self.stackViewController.scrollView.contentOffset.x <= 0.0f) {
		[self.stackViewController navigateToViewController:[[self.stackViewController viewControllersForPosition:SCStackViewControllerPositionRight] firstObject]
												  animated:YES
												completion:nil];
	} else if(self.stackViewController.scrollView.contentOffset.x > 0.0f) {
		[self.stackViewController navigateToViewController:self.stackViewController.rootViewController animated:YES completion:nil];
	}
}

- (void)_updateMenuButtonsWithContentOffset:(CGPoint)offset
{
	CGRect frame = self.leftMenuButton.frame;
	frame.origin.x = (offset.x > 0.0f ? 0.0f : ABS(offset.x));
	self.leftMenuButton.frame = frame;
	
	frame = self.rightMenuButton.frame;
	frame.origin.x = CGRectGetWidth(self.stackViewController.view.bounds) - frame.size.width;
	frame.origin.x += (offset.x < 0.0f ?: -offset.x);
	self.rightMenuButton.frame = frame;
}

@end
