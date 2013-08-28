//
//  UIViewController+SCStackViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 16/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

@class SCStackViewController;

@interface UIViewController (SCStackViewController)

- (SCStackViewController *)stackViewController;

- (CGFloat)viewWidth;
- (CGFloat)viewHeight;

@end

