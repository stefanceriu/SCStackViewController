//
//  SCStackNavigationStep.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 15/01/2014.
//  Copyright (c) 2014 Stefan Ceriu. All rights reserved.
//

#import "SCStackNavigationStep.h"

@interface SCStackNavigationStep ()

@property (nonatomic, assign) CGFloat percentage;

@end

@implementation SCStackNavigationStep

+ (instancetype)navigationStepWithPercentage:(CGFloat)percentage
{
    return [[SCStackNavigationStep alloc] initWithPercentage:percentage];
}

- (instancetype)initWithPercentage:(CGFloat)percentage
{
    if(self = [super init]) {
        _percentage = percentage;
    }
    
    return self;
}

@end
