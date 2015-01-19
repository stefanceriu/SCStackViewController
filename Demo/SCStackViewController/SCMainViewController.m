//
//  SCMainViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 17/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCMainViewController.h"

typedef NS_ENUM(NSUInteger, SCPickerViewComponentType)
{
    SCPickerViewComponentTypeLayouter,
    SCPickerViewComponentTypeEasingFunction,
    SCPickerViewComponentTypeAnimationDuration
};

@interface SCMainViewController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, weak) IBOutlet UILabel *visiblePercentageLabel;

@end

@implementation SCMainViewController

#pragma mark - Public

- (void)setVisiblePercentage:(CGFloat)percentage
{
	[self.visiblePercentageLabel setText:[NSString stringWithFormat:@"%.3f%%", percentage]];
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return SCPickerViewComponentTypeAnimationDuration + 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    switch ((SCPickerViewComponentType)component) {
        case SCPickerViewComponentTypeLayouter:
            return SCStackLayouterTypeCount;
        case SCPickerViewComponentTypeEasingFunction:
            return SCEasingFunctionTypeBounceEaseInOut + 1;
        case SCPickerViewComponentTypeAnimationDuration:
            return 40;
    }
}

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    UIFont *font = [UIFont fontWithName:@"Menlo" size:18.0f];
    UIColor *color = [UIColor colorWithWhite:1.0f alpha:1.0f];
    
    switch ((SCPickerViewComponentType)component) {
        case SCPickerViewComponentTypeLayouter: {
            static NSDictionary *typeToString;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                typeToString = (@{@(SCStackLayouterTypePlain)              : @"Plain",
                                  @(SCStackLayouterTypeSliding)            : @"Sliding",
                                  @(SCStackLayouterTypeParallax)           : @"Parallax",
                                  @(SCStackLayouterTypeGoogleMaps)         : @"Google Maps",
                                  @(SCStackLayouterTypeMerryGoRound)       : @"Merry Go Round",
                                  @(SCStackLayouterTypeReversed)           : @"Reversed",
                                  @(SCStacklayouterTypePlainResizing)      : @"Resizing"});
            });
            
            return [[NSAttributedString alloc] initWithString:typeToString[@(row)]
                                                   attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName : color}];
        }
        case SCPickerViewComponentTypeEasingFunction:
        {
            static NSDictionary *typeToString;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                typeToString = (@{@(SCEasingFunctionTypeLinear)               : @"Linear",
                                  
                                  @(SCEasingFunctionTypeQuadraticEaseIn)      : @"Quadratic Ease In",
                                  @(SCEasingFunctionTypeQuadraticEaseOut)     : @"Quadratic Ease Out",
                                  @(SCEasingFunctionTypeQuadraticEaseInOut)   : @"Quadratic Ease In Out",
                                  
                                  @(SCEasingFunctionTypeCubicEaseIn)          : @"Cubic Ease In",
                                  @(SCEasingFunctionTypeCubicEaseOut)         : @"Cubic Ease Out",
                                  @(SCEasingFunctionTypeCubicEaseInOut)       : @"Cubic Ease In Out",
                                  
                                  @(SCEasingFunctionTypeQuarticEaseIn)        : @"Quartic Ease In",
                                  @(SCEasingFunctionTypeQuarticEaseOut)       : @"Quartic Ease Out",
                                  @(SCEasingFunctionTypeQuarticEaseInOut)     : @"Quartic Ease In Out",
                                  
                                  @(SCEasingFunctionTypeQuinticEaseIn)        : @"Quintic Ease In",
                                  @(SCEasingFunctionTypeQuinticEaseOut)       : @"Quintic Ease Out",
                                  @(SCEasingFunctionTypeQuinticEaseInOut)     : @"Quintic Ease In Out",
                                  
                                  @(SCEasingFunctionTypeSineEaseIn)           : @"Sine Ease In",
                                  @(SCEasingFunctionTypeSineEaseOut)          : @"Sine Ease Out",
                                  @(SCEasingFunctionTypeSineEaseInOut)        : @"Sine Ease In Out",
                                  
                                  @(SCEasingFunctionTypeCircularEaseIn)       : @"Circular Ease In",
                                  @(SCEasingFunctionTypeCircularEaseOut)      : @"Circular Ease Out",
                                  @(SCEasingFunctionTypeCircularEaseInOut)    : @"Circular Ease In Out",
                                  
                                  @(SCEasingFunctionTypeExponentialEaseIn)    : @"Exponential Ease In",
                                  @(SCEasingFunctionTypeExponentialEaseOut)   : @"Exponential Ease Out",
                                  @(SCEasingFunctionTypeExponentialEaseInOut) : @"Exponential Ease In Out",
                                  
                                  @(SCEasingFunctionTypeElasticEaseIn)        : @"Elastic Ease In",
                                  @(SCEasingFunctionTypeElasticEaseOut)       : @"Elastic Ease Out",
                                  @(SCEasingFunctionTypeElasticEaseInOut)     : @"Elastic Ease In Out",
                                  
                                  @(SCEasingFunctionTypeBackEaseIn)           : @"Back Ease In",
                                  @(SCEasingFunctionTypeBackEaseOut)          : @"Back Ease Out",
                                  @(SCEasingFunctionTypeBackEaseInOut)        : @"Back Ease In Out",
                                  
                                  @(SCEasingFunctionTypeBounceEaseIn)         : @"Bounce Ease In",
                                  @(SCEasingFunctionTypeBounceEaseOut)        : @"Bounce Ease Out",
                                  @(SCEasingFunctionTypeBounceEaseInOut)      : @"Bounce Ease In Out"});
            });
            
            return [[NSAttributedString alloc] initWithString:typeToString[@(row)]
                                                   attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName : color}];
        }
        case SCPickerViewComponentTypeAnimationDuration:
        {
            return [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.2f", [self _rowToDuration:row]]
                                                   attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName : color}];
        }
    }
}

#pragma mark - UIPickerViewDelegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    switch ((SCPickerViewComponentType)component) {
        case SCPickerViewComponentTypeLayouter:
        {
            if([self.delegate respondsToSelector:@selector(mainViewController:didChangeLayouterType:)]) {
                [self.delegate mainViewController:self didChangeLayouterType:(SCStackLayouterType)row];
            }
            break;
        }
        case SCPickerViewComponentTypeEasingFunction:
        {
            if([self.delegate respondsToSelector:@selector(mainViewController:didChangeAnimationType:)]) {
                [self.delegate mainViewController:self didChangeAnimationType:(SCEasingFunctionType)row];
            }
            break;
        }
        case SCPickerViewComponentTypeAnimationDuration:
        {
            if([self.delegate respondsToSelector:@selector(mainViewController:didChangeAnimationDuration:)]) {
                [self.delegate mainViewController:self didChangeAnimationDuration:[self _rowToDuration:row]];
            }
            break;
        }
    }
}

- (NSTimeInterval)_rowToDuration:(NSUInteger)row
{
    return 0.25f * (row + 1);
}

@end
