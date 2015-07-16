//
//  SCModalViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCModalViewController.h"
#import "UIView+Shadows.h"
#import "UIColor+RandomColors.h"

@interface SCModalViewController ()

@property (nonatomic, assign) SCStackViewControllerPosition position;

@property (nonatomic, weak) IBOutlet UIView *contentView;

@property (nonatomic, weak) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, weak) IBOutlet UIView *controlsContainer;
@property (nonatomic, weak) IBOutlet UILabel *visiblePercentageLabel;

@end

@implementation SCModalViewController
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

- (IBAction)onPopButtonTap:(id)sender
{
	if([self.delegate respondsToSelector:@selector(stackedViewControllerDidRequestPop:)]) {
		[self.delegate stackedViewControllerDidRequestPop:self];
	}
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