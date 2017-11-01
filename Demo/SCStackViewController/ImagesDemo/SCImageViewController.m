//
//  SCImageViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCImageViewController.h"
#import "UIView+Shadows.h"

@interface SCImageViewController ()

@property (nonatomic, assign) SCStackViewControllerPosition position;

@property (nonatomic, weak) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, weak) IBOutlet UIView *controlsContainer;
@property (nonatomic, weak) IBOutlet UILabel *visiblePercentageLabel;

@end

@implementation SCImageViewController
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
	
	[self.backgroundImageView setImage:[UIImage imageNamed:@"panorama.jpg"]];
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
		positionToShadowEdge = (@{
								  @(SCStackViewControllerPositionTop)    : @(SCShadowEdgeTop),
								  @(SCStackViewControllerPositionLeft)   : @(SCShadowEdgeLeft),
								  @(SCStackViewControllerPositionBottom) : @(SCShadowEdgeBottom),
								  @(SCStackViewControllerPositionRight)  : @(SCShadowEdgeRight)
								  });
	});
	
	[self.backgroundImageView castShadowWithPosition:(SCShadowEdge)[positionToShadowEdge[@(self.position)] intValue]];
}

@end
