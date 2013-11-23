//
//  SCOverlayView.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 23/11/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

@protocol SCOverlayViewDelegate;

@interface SCOverlayView : UIView

@property (nonatomic, weak) id<SCOverlayViewDelegate> delegate;

+ (instancetype)overlayView;

@end

@protocol SCOverlayViewDelegate <NSObject>

@optional
- (void)overlayViewDidReceiveTap:(SCOverlayView *)overlayView;

@end
