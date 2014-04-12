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
#import "SCResizingStackLayouter.h"

#import "SCMenuViewController.h"

#import "SCOverlayView.h"

#import "SCStackNavigationStep.h"

@interface SCRootViewController () <SCStackViewControllerDelegate, SCOverlayViewDelegate, SCMenuViewControllerDelegate, SCMainViewControllerDelegate>

@property (nonatomic, strong) IBOutlet SCStackViewController *stackViewController;
@property (nonatomic, strong) IBOutlet SCMainViewController *mainViewController;
@property (nonatomic, strong) SCOverlayView *overlayView;

@end

@implementation SCRootViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Set from nib
    //SCMainViewController *mainViewController = [[SCMainViewController alloc] init];
    //[mainViewController setDelegate:self];
    
    self.overlayView = [SCOverlayView overlayView];
    [self.overlayView setDelegate:self];
    [self.overlayView setAlpha:0.0f];
    [self.mainViewController.view addSubview:self.overlayView];
    [self.overlayView setFrame:self.mainViewController.view.bounds];
    
    // Set from nib
    //self.stackViewController = [[SCStackViewController alloc] initWithRootViewController:self.mainViewController];
    //[self.stackViewController setDelegate:self];
    
    [self.stackViewController willMoveToParentViewController:self];
    
    [self.view addSubview:self.stackViewController.view];
    [self.stackViewController.view setFrame:self.view.bounds];
    
    [self addChildViewController:self.stackViewController];
    [self.stackViewController didMoveToParentViewController:self];
    
    
    // Optional properties
    [self.stackViewController setShowsScrollIndicators:NO];
    //[self.stackViewController setTouchRefusalArea:[UIBezierPath bezierPathWithRect:CGRectInset(self.view.bounds, 50, 50)]];
    //[self.stackViewController setMinimumNumberOfTouches:2];
    //[self.stackViewController setMaximumNumberOfTouches:2];
    //[self.stackViewController setContinuousNavigationEnabled:YES];
    //[self.stackViewController setNavigationContaintType:SCStackViewControllerNavigationContraintTypeForward | SCStackViewControllerNavigationContraintTypeReverse];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self mainViewController:self.mainViewController didSelectLayouterType:SCStackLayouterTypeParallax];
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
                            @(SCStackLayouterTypeReversed)           : [SCReversedStackLayouter class],
                            @(SCStacklayouterTypePlainResizing)      : [SCResizingStackLayouter class]
                            });
    });
    
    SCStackViewControllerPosition firstPosition = SCStackViewControllerPositionTop;//SCStackViewControllerPositionLeft;
    SCStackViewControllerPosition secondPosition = SCStackViewControllerPositionBottom;//SCStackViewControllerPositionRight;
    
    id<SCStackLayouterProtocol> aboveRootLayouter = [[typeToLayouter[@(type)] alloc] init];
    [aboveRootLayouter setShouldStackControllersAboveRoot:YES];
    [self.stackViewController registerLayouter:aboveRootLayouter forPosition:firstPosition];
    
    id<SCStackLayouterProtocol> belowRootLayouter = [[typeToLayouter[@(type)] alloc] init];
    [self.stackViewController registerLayouter:belowRootLayouter forPosition:secondPosition];
    
    SCMenuViewController *leftViewController = [[SCMenuViewController alloc] initWithPosition:firstPosition];
    [leftViewController setDelegate:self];
    
    [self.stackViewController contentOffset];
    
    [self.stackViewController popToRootViewControllerFromPosition:firstPosition
                                                         animated:YES
                                                       completion:^{
                                                           
                                                           [self.stackViewController registerNavigationSteps:@[[SCStackNavigationStep navigationStepWithPercentage:0.5f]]
                                                                                           forViewController:leftViewController];
                                                           
                                                           [self.stackViewController pushViewController:leftViewController
                                                                                             atPosition:firstPosition
                                                                                                 unfold:NO
                                                                                               animated:NO
                                                                                             completion:nil];
                                                       }];
    
    
    SCMenuViewController *rightViewController = [[SCMenuViewController alloc] initWithPosition:secondPosition];
    [rightViewController setDelegate:self];
    
    [self.stackViewController popToRootViewControllerFromPosition:secondPosition
                                                         animated:YES
                                                       completion:^{
                                                           
                                                           [self.stackViewController registerNavigationSteps:@[[SCStackNavigationStep navigationStepWithPercentage:0.5f]]
                                                                                           forViewController:rightViewController];
                                                           
                                                           [self.stackViewController pushViewController:rightViewController
                                                                                             atPosition:secondPosition
                                                                                                 unfold:NO
                                                                                               animated:NO
                                                                                             completion:nil];
                                                       }];
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
    
    [self.stackViewController registerNavigationSteps:@[[SCStackNavigationStep navigationStepWithPercentage:0.5f]]
                                    forViewController:newMenuViewController];
    
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

#pragma mark - SCStackViewControllerDelegate

- (void)stackViewController:(SCStackViewController *)stackViewController didNavigateToOffset:(CGPoint)offset
{
    [self.overlayView setAlpha:ABS((offset.x?:offset.y)/300.0f)];
    
    for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <= SCStackViewControllerPositionRight; position++) {
        for(SCMenuViewController *viewController in [self.stackViewController viewControllersForPosition:position]) {
            [viewController setVisiblePercentage:[stackViewController visiblePercentageForViewController:viewController]];
        }
    }
}

#pragma mark - Rotation Handling

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
}

@end
