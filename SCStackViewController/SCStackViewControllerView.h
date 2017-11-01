//
//  SCStackViewControllerView.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 17/01/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

@import UIKit;

@protocol SCStackViewControllerViewDelegate;

@interface SCStackViewControllerView : UIView

@property (nonatomic, weak) id<SCStackViewControllerViewDelegate> delegate;

@end

@protocol SCStackViewControllerViewDelegate <NSObject>

- (void)stackViewControllerViewWillChangeFrame:(SCStackViewControllerView *)stackViewControllerView;
- (void)stackViewControllerViewDidChangeFrame:(SCStackViewControllerView *)stackViewControllerView;

@end

