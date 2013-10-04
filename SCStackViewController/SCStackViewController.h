//
//  SCStackViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

typedef enum {
    SCStackViewControllerPositionTop,
    SCStackViewControllerPositionLeft,
    SCStackViewControllerPositionBottom,
    SCStackViewControllerPositionRight
} SCStackViewControllerPosition;


@protocol SCStackLayouterProtocol;


@protocol SCStackViewControllerDelegate;


@interface SCStackViewController : UIViewController

@property (nonatomic, strong, readonly) UIViewController *rootViewController;

@property (nonatomic, strong) UIBezierPath *touchRefusalArea;
@property (nonatomic, assign) BOOL bounces;

@property (nonatomic, weak) id<SCStackViewControllerDelegate> delegate;

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;

- (void)registerLayouter:(id<SCStackLayouterProtocol>)layouter
             forPosition:(SCStackViewControllerPosition)position;

- (void)pushViewController:(UIViewController *)viewController
                atPosition:(SCStackViewControllerPosition)position
                    unfold:(BOOL)unfold
                  animated:(BOOL)animated
                completion:(void(^)())completion;

- (void)popViewControllerAtPosition:(SCStackViewControllerPosition)position
                           animated:(BOOL)animated
                         completion:(void(^)())completion;

- (void)popToRootViewControllerFromPosition:(SCStackViewControllerPosition)position
                                   animated:(BOOL)animated
                                 completion:(void(^)())completion;

- (void)navigateToViewController:(UIViewController *)viewController
                        animated:(BOOL)animated
                      completion:(void(^)())completion;

- (NSArray *)viewControllersForPosition:(SCStackViewControllerPosition)position;

- (BOOL)isViewControllerVisible:(UIViewController *)viewController;

@end


@protocol SCStackViewControllerDelegate <NSObject>

@optional
- (void)stackViewController:(SCStackViewController *)stackViewController didShowViewController:(UIViewController *)controller position:(SCStackViewControllerPosition)position;
- (void)stackViewController:(SCStackViewController *)stackViewController didHideViewController:(UIViewController *)controller position:(SCStackViewControllerPosition)position;

- (void)stackViewController:(SCStackViewController *)stackViewController didNavigateToOffset:(CGPoint)offset;

@end


@interface UIViewController (SCStackViewController)

- (SCStackViewController *)stackViewController;

- (CGFloat)viewWidth;
- (CGFloat)viewHeight;

@end
