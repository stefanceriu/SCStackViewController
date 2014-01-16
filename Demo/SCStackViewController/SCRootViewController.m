//
//  SCViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCRootViewController.h"

#import "SCStackViewController.h"
#import "SCMainViewController.h"

#import "SCStackLayouter.h"
#import "SCParallaxStackLayouter.h"
#import "SCSlidingStackLayouter.h"
#import "SCGoogleMapsStackLayouter.h"
#import "SCMerryGoRoundStackLayouter.h"
#import "SCReversedStackLayouter.h"

#import "SCMenuViewController.h"
#import "UIViewController+Shadows.h"

#import "SCOverlayView.h"

#import "SCStackNavigationStep.h"

@interface SCRootViewController () <SCStackViewControllerDelegate, SCOverlayViewDelegate, SCMenuViewControllerDelegate, SCMainViewControllerDelegate>

@property (nonatomic, strong) SCStackViewController *stackViewController;
@property (nonatomic, strong) SCOverlayView *overlayView;

@end

@implementation SCRootViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    SCMainViewController *mainViewController = [[SCMainViewController alloc] init];
    [mainViewController setDelegate:self];
    [mainViewController.view castShadowWithPosition:SCShadowEdgeAll];
    
    self.overlayView = [SCOverlayView overlayView];
    [self.overlayView setDelegate:self];
    [self.overlayView setAlpha:0.0f];
    [mainViewController.view addSubview:self.overlayView];
    
    self.stackViewController = [[SCStackViewController alloc] initWithRootViewController:mainViewController];
    [self.stackViewController.view setFrame:self.view.bounds];
    //[self.stackViewController setTouchRefusalArea:[UIBezierPath bezierPathWithRect:CGRectInset(self.view.bounds, 50, 50)]];
    [self.stackViewController setShowsScrollIndicators:NO];
    [self.stackViewController setDelegate:self];
    
    [self addChildViewController:self.stackViewController];
    [self.view addSubview:self.stackViewController.view];
    [self.stackViewController didMoveToParentViewController:self];
    
    //[self.stackViewController setMinimumNumberOfTouches:2];
    //[self.stackViewController setMaximumNumberOfTouches:2];
    
    [self mainViewController:mainViewController didSelectLayouterType:SCStackLayouterTypeParallax];
}

#pragma mark - SCMainViewControllerDelegate

- (void)mainViewController:(SCMainViewController *)mainViewController didSelectLayouterType:(SCStackLayouterType)type
{
    static NSDictionary *typeToLayouter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        typeToLayouter = (@{
                          @(SCStackLayouterTypePlain)              : [SCStackLayouter class],
                          @(SCStackLayouterTypeSliding)            : [SCSlidingStackLayouter class],
                          @(SCStackLayouterTypeParallax)           : [SCParallaxStackLayouter class],
                          @(SCStackLayouterTypeGoogleMaps)         : [SCGoogleMapsStackLayouter class],
                          @(SCStackLayouterTypeMerryGoRound)       : [SCMerryGoRoundStackLayouter class],
                          @(SCStackLayouterTypeReversed)           : [SCReversedStackLayouter class]
                          });
    });
    
    id<SCStackLayouterProtocol> aboveRootLayouter = [[typeToLayouter[@(type)] alloc] init];
    [aboveRootLayouter setShouldStackControllersAboveRoot:YES];
    [self.stackViewController registerLayouter:aboveRootLayouter forPosition:SCStackViewControllerPositionTop];
    
    id<SCStackLayouterProtocol> belowRootLayouter = [[typeToLayouter[@(type)] alloc] init];
    [self.stackViewController registerLayouter:belowRootLayouter forPosition:SCStackViewControllerPositionBottom];
    
    SCMenuViewController *leftViewController = [[SCMenuViewController alloc] initWithPosition:SCStackViewControllerPositionTop];
    [leftViewController.view castShadowWithPosition:SCShadowEdgeTop];
    [leftViewController setDelegate:self];
    
    [self.stackViewController popToRootViewControllerFromPosition:SCStackViewControllerPositionTop
                                                         animated:YES
                                                       completion:^{
                                                           
                                                           [self.stackViewController registerNavigationSteps:@[[SCStackNavigationStep navigationStepWithPercentage:0.25f],[SCStackNavigationStep navigationStepWithPercentage:0.5f]]
                                                                                           forViewController:leftViewController];
                                                           
                                                           [self.stackViewController pushViewController:leftViewController
                                                                                             atPosition:SCStackViewControllerPositionTop
                                                                                                 unfold:NO
                                                                                               animated:NO
                                                                                             completion:nil];
                                                       }];
    
    
    SCMenuViewController *rightViewController = [[SCMenuViewController alloc] initWithPosition:SCStackViewControllerPositionBottom];
    [rightViewController.view castShadowWithPosition:SCShadowEdgeBottom];
    [rightViewController setDelegate:self];
    
    [self.stackViewController popToRootViewControllerFromPosition:SCStackViewControllerPositionBottom
                                                         animated:YES
                                                       completion:^{
                                                           
                                                           [self.stackViewController registerNavigationSteps:@[[SCStackNavigationStep navigationStepWithPercentage:0.5f],
                                                                                                               [SCStackNavigationStep navigationStepWithPercentage:0.25f]]
                                                                                           forViewController:rightViewController];
                                                           
                                                           [self.stackViewController pushViewController:rightViewController
                                                                                             atPosition:SCStackViewControllerPositionBottom
                                                                                                 unfold:NO
                                                                                               animated:NO
                                                                                             completion:nil];
                                                       }];
}

#pragma mark - SCStackViewControllerDelegate

- (void)stackViewController:(SCStackViewController *)stackViewController didNavigateToOffset:(CGPoint)offset
{
    [self.overlayView setAlpha:ABS(offset.x/300.0f)];
}

#pragma mark - SCOverlayViewDelegate

- (void)overlayViewDidReceiveTap:(SCOverlayView *)overlayView
{
    [self.stackViewController navigateToViewController:self.stackViewController.rootViewController animated:YES completion:nil];
}

#pragma mark - SCMenuViewControllerDelegate

- (void)menuViewControllerDidRequestPush:(SCMenuViewController *)menuViewController
{
    SCMenuViewController *newMenuViewController = [[SCMenuViewController alloc] initWithPosition:menuViewController.position];
    [newMenuViewController setDelegate:self];
    
    static NSDictionary *positionToShadowEdge;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        positionToShadowEdge = (@{
                                @(SCStackViewControllerPositionTop)    : @(SCShadowEdgeTop),
                                @(SCStackViewControllerPositionLeft)   : @(SCShadowEdgeLeft),
                                @(SCStackViewControllerPositionBottom) : @(SCShadowEdgeBottom),
                                @(SCStackViewControllerPositionRight)  : @(SCShadowEdgeRight)
                                });
    });
    
    [newMenuViewController.view castShadowWithPosition:[positionToShadowEdge[@(menuViewController.position)] intValue]];
    [self.stackViewController pushViewController:newMenuViewController
                                      atPosition:menuViewController.position
                                          unfold:YES
                                        animated:YES
                                      completion:nil];
}

- (void)menuViewControllerDidRequestPop:(SCMenuViewController *)menuViewController
{
    [self.stackViewController popViewControllerAtPosition:menuViewController.position
                                                 animated:YES
                                               completion:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
}

@end
