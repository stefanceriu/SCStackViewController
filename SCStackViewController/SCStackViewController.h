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

@protocol SCStackViewControllerProtocol
- (void) stackviewDidScrollInScrollView:(UIScrollView *) scrollview;
@end


@interface SCStackViewController : UIViewController

@property (nonatomic, strong) UIBezierPath *touchRefusalArea;
@property (nonatomic, assign) BOOL bounces;
@property (nonatomic, assign) BOOL fadeViewsArrival;


- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;

- (void)registerLayouter:(id<SCStackLayouterProtocol>)layouter
             forPosition:(SCStackViewControllerPosition)position;

- (void)pushViewController:(UIViewController *)viewController
                atPosition:(SCStackViewControllerPosition)position
                    unfold:(BOOL)unfold
                  animated:(BOOL)animated
                completion:(void(^)(BOOL finished))completion;

- (void)popViewControllerAtPosition:(SCStackViewControllerPosition)position
                           animated:(BOOL)animated
                         completion:(void(^)(BOOL finished))completion;

- (void)popToRootViewControllerFromPosition:(SCStackViewControllerPosition)position
                                   animated:(BOOL)animated
                                 completion:(void(^)(BOOL finished))completion;

- (void)navigateToViewController:(UIViewController *)viewController
                        animated:(BOOL)animated
                      completion:(void(^)(BOOL finished))completion;

- (NSArray *)viewControllersForPosition:(SCStackViewControllerPosition)position;

@end