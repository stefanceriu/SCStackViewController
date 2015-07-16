//
//  SCMainViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 17/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCEasingFunction.h"

typedef NS_ENUM(NSUInteger, SCStackDemoType) {
	SCStackDemoTypeVerticalImages,
	SCStackDemoTypeSideMenus,
	SCStackDemoTypeTitleBar,
	SCStackDemoTypeModal,
	SCStackDemoTypeGeneric,
};

typedef NS_ENUM(NSUInteger, SCStackLayouterType) {
	SCStackLayouterTypePlain,
	SCStackLayouterTypeSliding,
	SCStackLayouterTypeParallax,
	SCStackLayouterTypeReversed,
	SCStacklayouterTypePlainResizing,
	SCStackLayouterTypeCount
};

@protocol SCMainViewControllerDelegate;

@interface SCMainViewController : UIViewController

@property (nonatomic, weak) IBOutlet id<SCMainViewControllerDelegate> delegate;

- (void)setVisiblePercentage:(CGFloat)percentage;

- (void)showAnimationOptionsAnimated:(BOOL)animated;
- (void)hideAnimationOptionsAnimated:(BOOL)animated;

@end

@protocol SCMainViewControllerDelegate <NSObject>

- (void)mainViewController:(SCMainViewController *)mainViewController
		 didChangeDemoType:(SCStackDemoType)type;

- (void)mainViewController:(SCMainViewController *)mainViewController
	 didChangeLayouterType:(SCStackLayouterType)type;

- (void)mainViewController:(SCMainViewController *)mainViewController
	didChangeAnimationType:(SCEasingFunctionType)type;

- (void)mainViewController:(SCMainViewController *)mainViewController
didChangeAnimationDuration:(NSTimeInterval)duration;

@end
