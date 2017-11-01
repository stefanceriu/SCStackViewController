//
//  SCStackableViewControllerProtocol.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 5/9/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SCStackedViewControllerDelegate;

@protocol SCStackedViewControllerProtocol <NSObject>

@property (nonatomic, weak) id<SCStackedViewControllerDelegate> delegate;
@property (nonatomic, readonly) SCStackViewControllerPosition position;

- (void)setVisiblePercentage:(CGFloat)percentage;

@end

@protocol SCStackedViewControllerDelegate <NSObject>

@optional
- (void)stackedViewControllerDidRequestPush:(id<SCStackedViewControllerProtocol>)stackedViewController;
- (void)stackedViewControllerDidRequestPop:(id<SCStackedViewControllerProtocol>)stackedViewController;

@end

