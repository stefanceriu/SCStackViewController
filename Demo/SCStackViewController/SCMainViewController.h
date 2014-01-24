//
//  SCMainViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 17/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

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
     didSelectLayouterType:(SCStackLayouterType)type;

@end
