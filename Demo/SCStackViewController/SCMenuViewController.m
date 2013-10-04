//
//  SCMenuViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCMenuViewController.h"
#import "UIColor+RandomColors.h"

@interface SCMenuViewController ()

@property (nonatomic, assign) SCStackViewControllerPosition position;

@end

@implementation SCMenuViewController

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
    [self.view setBackgroundColor:[UIColor randomColor]];
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
    [self.stackViewController navigateToViewController:self animated:YES completion:nil];
}

@end