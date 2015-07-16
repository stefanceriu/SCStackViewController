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

+ (instancetype)navigationStepWithPercentage:(CGFloat)percentage blockType:(SCStackNavigationStepBlockType)blockType
{
	return [[SCStackNavigationStep alloc] initWithPercentage:percentage blockType:blockType];
}

- (instancetype)initWithPercentage:(CGFloat)percentage
{
	if(self = [self initWithPercentage:percentage blockType:SCStackNavigationStepBlockTypeNone]) {
		
	}
	
	return self;
}

- (instancetype)initWithPercentage:(CGFloat)percentage blockType:(SCStackNavigationStepBlockType)blockType
{
	if(self = [super init]) {
		_percentage = percentage;
		_blockType = blockType;
	}
	
	return self;
}

@end
