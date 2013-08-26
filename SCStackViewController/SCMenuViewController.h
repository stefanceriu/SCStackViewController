//
//  SCMenuViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCStackViewController.h"

@protocol SCMenuViewControllerDelegate;

@interface SCMenuViewController : UIViewController

- (instancetype)initWithPosition:(SCStackViewControllerPosition)position;

@property (nonatomic, weak) id<SCMenuViewControllerDelegate> delegate;

@property (nonatomic, readonly) SCStackViewControllerPosition position;

- (IBAction)onScrollToMeButtonTapped:(id)sender;
@end

@protocol SCMenuViewControllerDelegate <NSObject>

@optional
- (void)menuViewControllerDidRequestPush:(SCMenuViewController *)menuViewController;
- (void)menuViewControllerDidRequestPop:(SCMenuViewController *)menuViewController;

@end