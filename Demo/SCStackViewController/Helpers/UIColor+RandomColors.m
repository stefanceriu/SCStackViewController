//
//  UIColor+RandomColors.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 16/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "UIColor+RandomColors.h"
#import "Chameleon.h"

@implementation UIColor (RandomColors)

+ (UIColor *)randomColorWithAlpha:(CGFloat)alpha
{
	static NSMutableArray *colorArray;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		UIColor *baseColor = [UIColor blueColor];
		
		colorArray = [NSMutableArray array];
		[colorArray addObjectsFromArray:[NSArray arrayOfColorsWithColorScheme:ColorSchemeTriadic usingColor:baseColor withFlatScheme:YES]];
		[colorArray addObjectsFromArray:[NSArray arrayOfColorsWithColorScheme:ColorSchemeComplementary usingColor:baseColor withFlatScheme:YES]];
		[colorArray addObjectsFromArray:[NSArray arrayOfColorsWithColorScheme:ColorSchemeAnalogous usingColor:baseColor withFlatScheme:YES]];
	});
	
	return colorArray[(arc4random()%colorArray.count)];
}

@end
