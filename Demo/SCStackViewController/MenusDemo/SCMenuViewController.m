//
//  SCMenuViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCMenuViewController.h"
#import "UIView+Shadows.h"
#import "UIColor+RandomColors.h"

@interface SCMenuViewController ()

@property (nonatomic, assign) SCStackViewControllerPosition position;

@property (nonatomic, weak) IBOutlet UIView *contentView;

@property (nonatomic, weak) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, weak) IBOutlet UIView *controlsContainer;
@property (nonatomic, weak) IBOutlet UILabel *visiblePercentageLabel;

@end

@implementation SCMenuViewController
@synthesize delegate;

- (instancetype)initWithPosition:(SCStackViewControllerPosition)position
{
    if(self = [super init]) {
        self.position = position;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateShadow];
	
	[self.contentView setBackgroundColor:[UIColor randomColorWithAlpha:1.0f]];
    
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

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self updateShadow];
}

- (void)setVisiblePercentage:(CGFloat)percentage
{
    [self.visiblePercentageLabel setText:[NSString stringWithFormat:@"%.3f%%", percentage]];
}

- (IBAction)onPushButtonTap:(id)sender
{
    if([self.delegate respondsToSelector:@selector(stackedViewControllerDidRequestPush:)]) {
        [self.delegate stackedViewControllerDidRequestPush:self];
    }
}

- (IBAction)onPopButtonTap:(id)sender
{
    if([self.delegate respondsToSelector:@selector(stackedViewControllerDidRequestPop:)]) {
        [self.delegate stackedViewControllerDidRequestPop:self];
    }
}

- (IBAction)onScrollToMeButtonTapped:(id)sender
{
    [self.sc_stackViewController navigateToViewController:self animated:YES completion:nil];
}

- (void)updateShadow
{
	static NSDictionary *positionToShadowEdge;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		positionToShadowEdge = (@{@(SCStackViewControllerPositionTop)    : @(SCShadowEdgeTop),
								  @(SCStackViewControllerPositionLeft)   : @(SCShadowEdgeLeft),
								  @(SCStackViewControllerPositionBottom) : @(SCShadowEdgeBottom),
								  @(SCStackViewControllerPositionRight)  : @(SCShadowEdgeRight)});
	});
	
	[self.contentView castShadowWithPosition:[positionToShadowEdge[@(self.position)] intValue]];
}

@end