//
//  SCMenuViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCTitleBarViewController.h"

#import "SCStackViewController.h"
#import "SCStackNavigationStep.h"

#import "UIView+Shadows.h"
#import "UIColor+RandomColors.h"
#import "SCTitleBarCollectionViewCell.h"

@interface SCTitleBarViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, assign) SCStackViewControllerPosition position;
@property (nonatomic, weak) IBOutlet UILabel *visiblePercentageLabel;

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;

@property (nonatomic, weak) IBOutlet UIButton *minimizeButton;
@property (nonatomic, weak) IBOutlet UIButton *maximizeButton;

@end

@implementation SCTitleBarViewController
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
	
	NSString *identifier =NSStringFromClass([SCTitleBarCollectionViewCell class]);
	[self.collectionView registerNib:[UINib nibWithNibName:identifier bundle:nil] forCellWithReuseIdentifier:identifier];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self updateShadow];
}

- (void)setVisiblePercentage:(CGFloat)percentage
{
    [self.visiblePercentageLabel setText:[NSString stringWithFormat:@"%.3f%%", percentage]];
	
	CGFloat normalized = MAX(0, MIN(1, (percentage - 0.1f) / 0.2f));
	
	CGRect frame = self.visiblePercentageLabel.frame;
	frame.origin.y = 300.0f - (normalized * 40.0f);
	self.visiblePercentageLabel.frame = frame;
	
	[self.minimizeButton setAlpha:normalized];
	[self.maximizeButton setAlpha:normalized];
}

- (IBAction)onMinimizeButtonTap:(id)sender
{
	[self.sc_stackViewController navigateToStep:[SCStackNavigationStep navigationStepWithPercentage:0.1f] inViewController:self animated:YES completion:nil];
}

- (IBAction)onMaximizeButtonTap:(id)sender
{
	[self.sc_stackViewController navigateToStep:[SCStackNavigationStep navigationStepWithPercentage:1.0f] inViewController:self animated:YES completion:nil];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return 20;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	SCTitleBarCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([SCTitleBarCollectionViewCell class]) forIndexPath:indexPath];
	[cell.imageView setBackgroundColor:[UIColor randomColorWithAlpha:1.0f]];
	return cell;
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
	
	[self.view castShadowWithPosition:[positionToShadowEdge[@(self.position)] intValue]];
}

@end