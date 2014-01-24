//
//  SCMenuViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCMenuViewController.h"
#import "UIColor+RandomColors.h"

#import "UIViewController+Shadows.h"

@interface SCMenuViewController ()

@property (nonatomic, assign) SCStackViewControllerPosition position;

@property (nonatomic, weak) IBOutlet UIView *controlsContainer;
@property (nonatomic, weak) IBOutlet UILabel *visiblePercentageLabel;

@end

@implementation SCMenuViewController

- (instancetype)initWithPosition:(SCStackViewControllerPosition)position
{
    if(self = [super init]) {
        self.position = position;
        
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
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor randomColor]];
    
    switch (self.position) {
        case SCStackViewControllerPositionTop:
            self.visiblePercentageLabel.center = CGPointMake(self.view.center.x, CGRectGetHeight(self.view.bounds) - CGRectGetHeight(self.visiblePercentageLabel.bounds));
            self.controlsContainer.center = CGPointMake(self.view.center.x, CGRectGetHeight(self.controlsContainer.bounds));
            break;
        case SCStackViewControllerPositionBottom:
            self.visiblePercentageLabel.center = CGPointMake(self.view.center.x, CGRectGetHeight(self.visiblePercentageLabel.bounds));
            self.controlsContainer.center = CGPointMake(self.view.center.x, CGRectGetHeight(self.view.bounds) - CGRectGetHeight(self.controlsContainer.bounds));
            break;
        case SCStackViewControllerPositionLeft:
            self.visiblePercentageLabel.transform = CGAffineTransformMakeRotation(-M_PI/2);
            self.visiblePercentageLabel.center = CGPointMake(CGRectGetWidth(self.visiblePercentageLabel.bounds), 100.0f);
            break;
        case SCStackViewControllerPositionRight:
            self.visiblePercentageLabel.transform = CGAffineTransformMakeRotation(M_PI/2);
            self.visiblePercentageLabel.center = CGPointMake(CGRectGetWidth(self.view.bounds) - CGRectGetWidth(self.visiblePercentageLabel.bounds), 100.0f);
            break;
    }
    
}

- (void)setVisiblePercentage:(CGFloat)percentage
{
    [self.visiblePercentageLabel setText:[NSString stringWithFormat:@"%.2f%%", percentage]];
}

- (IBAction)onPushButtonTap:(id)sender
{
    if([self.delegate respondsToSelector:@selector(menuViewControllerDidRequestPush:)]) {
        [self.delegate menuViewControllerDidRequestPush:self];
    }
}

- (IBAction)onPopButtonTap:(id)sender
{
    if([self.delegate respondsToSelector:@selector(menuViewControllerDidRequestPop:)]) {
        [self.delegate menuViewControllerDidRequestPop:self];
    }
}

- (IBAction)onScrollToMeButtonTapped:(id)sender
{
    UIViewController *x = [[self.stackViewController viewControllersForPosition:SCStackViewControllerPositionBottom] lastObject];
    
    [self.stackViewController navigateToViewController:x animated:YES completion:nil];
}

@end