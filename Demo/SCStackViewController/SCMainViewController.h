//
//  SCMainViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 17/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCEasingFunction.h"

typedef enum {
    SCStackLayouterTypePlain,
    SCStackLayouterTypeSliding,
    SCStackLayouterTypeParallax,
    SCStackLayouterTypeGoogleMaps,
    SCStackLayouterTypeMerryGoRound,
    SCStackLayouterTypeReversed,
    SCStacklayouterTypePlainResizing,
    SCStackLayouterTypeCount
} SCStackLayouterType;

@protocol SCMainViewControllerDelegate;

@interface SCMainViewController : UIViewController

@property (nonatomic, weak) IBOutlet id<SCMainViewControllerDelegate> delegate;

@end

@protocol SCMainViewControllerDelegate <NSObject>

- (void)mainViewController:(SCMainViewController *)mainViewController
     didChangeLayouterType:(SCStackLayouterType)type;

- (void)mainViewController:(SCMainViewController *)mainViewController
    didChangeAnimationType:(SCEasingFunctionType)type;

- (void)mainViewController:(SCMainViewController *)mainViewController
didChangeAnimationDuration:(NSTimeInterval)duration;

@end
