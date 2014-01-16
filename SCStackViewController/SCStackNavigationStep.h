//
//  SCStackNavigationStep.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 15/01/2014.
//  Copyright (c) 2014 Stefan Ceriu. All rights reserved.
//

@interface SCStackNavigationStep : NSObject

@property (nonatomic, readonly) CGFloat percentage;

+ (instancetype)navigationStepWithPercentage:(CGFloat)percentage;

- (instancetype)initWithPercentage:(CGFloat)percentage;

@end
