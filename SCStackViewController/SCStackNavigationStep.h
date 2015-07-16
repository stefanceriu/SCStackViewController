//
//  SCStackNavigationStep.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 15/01/2014.
//  Copyright (c) 2014 Stefan Ceriu. All rights reserved.
//

/** A stack navigation step defines a relative position in a view
 * controller at which the scrolling should stop when reached.
 * I works as both a pagination point and a navigation contraint (the
 * scroll view bounces on it)
 *
 * It is initialized with a percentage which will be transform into an
 * actual offset based on the view controller's frame.
 */

@import Foundation;
@import CoreGraphics;

typedef NS_ENUM(NSUInteger, SCStackNavigationStepBlockType) {
	SCStackNavigationStepBlockTypeNone,
	SCStackNavigationStepBlockTypeForward,
	SCStackNavigationStepBlockTypeReverse
};

@interface SCStackNavigationStep : NSObject

@property (nonatomic, readonly) CGFloat percentage;

@property (nonatomic, readonly) SCStackNavigationStepBlockType blockType;

+ (instancetype)navigationStepWithPercentage:(CGFloat)percentage;

+ (instancetype)navigationStepWithPercentage:(CGFloat)percentage blockType:(SCStackNavigationStepBlockType)blockType;

- (instancetype)initWithPercentage:(CGFloat)percentage;

- (instancetype)initWithPercentage:(CGFloat)percentage blockType:(SCStackNavigationStepBlockType)blockType;

@end
