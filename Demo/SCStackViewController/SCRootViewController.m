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

@interface SCRootViewController () <SCMenuViewControllerDelegate, SCMainViewControllerDelegate>

@property (nonatomic, strong) SCStackViewController *stackViewController;

@end

@implementation SCRootViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    SCMainViewController *mainViewController = [[SCMainViewController alloc] init];
    [mainViewController setDelegate:self];
    [mainViewController.view castShadowWithPosition:SCShadowEdgeAll];
    
    self.stackViewController = [[SCStackViewController alloc] initWithRootViewController:mainViewController];
    [self.stackViewController.view setFrame:self.view.bounds];
    //[self.stackViewController setTouchRefusalArea:[UIBezierPath bezierPathWithRect:CGRectInset(self.view.bounds, 50, 50)]];
    
    [self addChildViewController:self.stackViewController];
    [self.view addSubview:self.stackViewController.view];
    [self.stackViewController didMoveToParentViewController:self];
    
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
    
    id<SCStackLayouterProtocol> layouter = [[typeToLayouter[@(type)] alloc] init];
    
    [self.stackViewController registerLayouter:layouter forPosition:SCStackViewControllerPositionLeft];
    [self.stackViewController registerLayouter:layouter forPosition:SCStackViewControllerPositionRight];
    
    [self.stackViewController popToRootViewControllerFromPosition:SCStackViewControllerPositionLeft
                                                         animated:YES
                                                       completion:nil];
    
    SCMenuViewController *leftViewController = [[SCMenuViewController alloc] initWithPosition:SCStackViewControllerPositionLeft];
    [leftViewController.view castShadowWithPosition:SCShadowEdgeLeft];
    [leftViewController setDelegate:self];
    [self.stackViewController pushViewController:leftViewController
                                      atPosition:SCStackViewControllerPositionLeft
                                          unfold:NO
                                        animated:NO
                                      completion:nil];
    
    [self.stackViewController popToRootViewControllerFromPosition:SCStackViewControllerPositionRight
                                                         animated:YES
                                                       completion:nil];
    
    SCMenuViewController *rightViewController = [[SCMenuViewController alloc] initWithPosition:SCStackViewControllerPositionRight];
    [rightViewController.view castShadowWithPosition:SCShadowEdgeRight];
    [rightViewController setDelegate:self];
    [self.stackViewController pushViewController:rightViewController
                                      atPosition:SCStackViewControllerPositionRight
                                          unfold:NO
                                        animated:NO
                                      completion:nil];
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
