//
//  SCStackViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCStackViewController.h"
#import "SCStackLayouterProtocol.h"
#import "MOScrollView.h"
#import "UIViewController+SCStackViewController.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

static const CGFloat kDefaultAnimationDuration = 0.25f;

@interface SCStackViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIViewController *rootViewController;

@property (nonatomic, strong) MOScrollView *scrollView;

@property (nonatomic, strong) NSMutableDictionary *layouters;
@property (nonatomic, strong) NSMutableDictionary *finalFrames;

@property (nonatomic, strong) NSDictionary *viewControllers;
@property (nonatomic, strong) NSMutableArray *visibleViewControllers;

@end

@implementation SCStackViewController
@dynamic bounces;
@dynamic touchRefusalArea;

#pragma mark - Constructors

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
    if(self = [super init]) {
        self.rootViewController = rootViewController;
    }
    
    return self;
}

#pragma mark - Public Methods

- (void)registerLayouter:(id<SCStackLayouterProtocol>)layouter
             forPosition:(SCStackViewControllerPosition)position
{
    [self.layouters setObject:layouter forKey:@(position)];
}

- (void)pushViewController:(UIViewController *)viewController
                atPosition:(SCStackViewControllerPosition)position
                    unfold:(BOOL)unfold
                  animated:(BOOL)animated
                completion:(void(^)())completion
{
    NSAssert(viewController != nil, @"Trying to push nil view controller");
    NSAssert(![[self.viewControllers.allValues valueForKeyPath:@"@unionOfArrays.self"] containsObject:viewController], @"Trying to push an already pushed view controller");
    
    NSMutableArray *viewControllers = self.viewControllers[@(position)];
    [viewControllers addObject:viewController];
    
    [self updateFinalFramesForPosition:position];
    
    [self addChildViewController:viewController];
    viewController.view.frame = [self.finalFrames[@(viewController.hash)] CGRectValue];
    [self.scrollView insertSubview:viewController.view atIndex:0];
    [viewController didMoveToParentViewController:self];
    
    [self updateBounds];
    
    if(unfold) {
        [self.scrollView setContentOffset:[self offsetForPosition:position]
                       withTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
                                 duration:(animated ? kDefaultAnimationDuration : 0.0f)
                               completion:completion];
    } else if(completion) {
        completion(YES);
    }
}

- (void)popViewControllerAtPosition:(SCStackViewControllerPosition)position
                           animated:(BOOL)animated
                         completion:(void(^)())completion
{
    UIViewController *lastViewController = [self.viewControllers[@(position)] lastObject];
    
    UIViewController *previousViewController;
    if([self.viewControllers[@(position)] count] == 1) {
        previousViewController = self.rootViewController;
    } else {
        previousViewController = [self.viewControllers[@(position)] objectAtIndex:[self.viewControllers[@(position)] indexOfObject:lastViewController] - 1];
    }
    
    [self navigateToViewController:previousViewController
                          animated:animated
                        completion:^{
                            
                            [self.viewControllers[@(position)] removeObject:lastViewController];
                            [self.finalFrames removeObjectForKey:@([lastViewController hash])];
                            [self updateFinalFramesForPosition:position];
                            [self updateBounds];
                            
                            if([self.visibleViewControllers containsObject:lastViewController]) {
                                [lastViewController beginAppearanceTransition:NO animated:animated];
                            }
                            
                            [lastViewController willMoveToParentViewController:nil];
                            [lastViewController.view removeFromSuperview];
                            [lastViewController removeFromParentViewController];
                            
                            if([self.visibleViewControllers containsObject:lastViewController]) {
                                [lastViewController endAppearanceTransition];
                                [self.visibleViewControllers removeObject:lastViewController];
                            }
                            
                            if(completion) {
                                completion();
                            }
                        }];
}

- (void)popToRootViewControllerFromPosition:(SCStackViewControllerPosition)position
                                   animated:(BOOL)animated
                                 completion:(void(^)())completion
{
    NSArray *controllersToBeRemoved = [self.viewControllers[@(position)] copy];
    
    [self.viewControllers[@(position)] enumerateObjectsUsingBlock:^(UIViewController *controller, NSUInteger idx, BOOL *stop) {
        [self.finalFrames removeObjectForKey:@([controller hash])];
    }];
    [self.viewControllers[@(position)] removeAllObjects];
    
    [self updateFinalFramesForPosition:position];
    
    [UIView animateWithDuration:(animated ? kDefaultAnimationDuration : 0.0f)
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self scrollViewDidScroll:self.scrollView];
                         [self updateBounds];
                     } completion:^(BOOL finished) {
                         for(UIViewController *controller in controllersToBeRemoved) {
                             
                             if([self.visibleViewControllers containsObject:controller]) {
                                 [controller beginAppearanceTransition:NO animated:animated];
                             }
                             
                             [controller willMoveToParentViewController:nil];
                             [controller.view removeFromSuperview];
                             [controller removeFromParentViewController];
                             
                             if([self.visibleViewControllers containsObject:controller]) {
                                 [controller endAppearanceTransition];
                                 [self.visibleViewControllers removeObject:controller];
                             }
                             if(completion) {
                                 completion(finished);
                             }
                         }
                     }];
}

- (void)navigateToViewController:(UIViewController *)viewController
                        animated:(BOOL)animated
                      completion:(void(^)())completion;
{
    CGPoint offset = CGPointZero;
    CGRect finalFrame = CGRectZero;
    
    if(![viewController isEqual:self.rootViewController]) {
        
        finalFrame = [[self.finalFrames objectForKey:@(viewController.hash)] CGRectValue];
        
        SCStackViewControllerPosition controllerPosition = -1;
        for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
            if([self.viewControllers[@(position)] containsObject:viewController]) {
                controllerPosition = position;
            }
        }
        
        BOOL isReversed = NO;
        if([self.layouters[@(controllerPosition)] respondsToSelector:@selector(isReversed)]) {
            isReversed = [self.layouters[@(controllerPosition)] isReversed];
        }
        
        switch (controllerPosition) {
            case SCStackViewControllerPositionTop:
                offset.y = (isReversed ? ([self offsetForPosition:controllerPosition].y - CGRectGetMaxY(finalFrame)) : CGRectGetMinY(finalFrame));
                break;
            case SCStackViewControllerPositionLeft:
                offset.x = (isReversed ? ([self offsetForPosition:controllerPosition].x - CGRectGetMaxX(finalFrame)) : CGRectGetMinX(finalFrame));
                break;
            case SCStackViewControllerPositionBottom:
                offset.y = (isReversed ? ([self offsetForPosition:controllerPosition].y - CGRectGetMinY(finalFrame) + CGRectGetHeight(self.view.bounds)) : CGRectGetMaxY(finalFrame) - CGRectGetHeight(self.view.bounds));
                break;
            case SCStackViewControllerPositionRight:
                offset.x = (isReversed ? ([self offsetForPosition:controllerPosition].x - CGRectGetMinX(finalFrame) + CGRectGetWidth(self.view.bounds)) : CGRectGetMaxX(finalFrame) - CGRectGetWidth(self.view.bounds));
                break;
            default:
                break;
        }
    }
    
    [self.scrollView setContentOffset:offset
                   withTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
                             duration:(animated ? kDefaultAnimationDuration : 0.0f)
                           completion:completion];
}

- (NSArray *)viewControllersForPosition:(SCStackViewControllerPosition)position
{
    return [self.viewControllers[@(position)] copy];
}

- (BOOL)isViewControllerVisible:(UIViewController *)viewController
{
    return [self.visibleViewControllers containsObject:viewController];
}

#pragma mark - Private Methods

- (void)updateFinalFramesForPosition:(SCStackViewControllerPosition)position
{
    NSMutableArray *viewControllers = self.viewControllers[@(position)];
    [viewControllers enumerateObjectsUsingBlock:^(UIViewController *controller, NSUInteger idx, BOOL *stop) {
        CGRect finalFrame = [self.layouters[@(position)] finalFrameForViewController:controller
                                                                           withIndex:idx
                                                                          atPosition:position
                                                                         withinGroup:viewControllers
                                                                   inStackController:self];
        
        [self.finalFrames setObject:[NSValue valueWithCGRect:finalFrame] forKey:@([controller hash])];
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    
    self.scrollView = [[MOScrollView alloc] initWithFrame:self.view.bounds];
    [self.scrollView setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self.scrollView setDirectionalLockEnabled:YES];
    [self.scrollView setShowsHorizontalScrollIndicator:NO];
    [self.scrollView setDecelerationRate:UIScrollViewDecelerationRateFast];
    [self.scrollView setDelegate:self];
    
    [self addChildViewController:self.rootViewController];
    [self.rootViewController.view setFrame:self.scrollView.bounds];
    [self.rootViewController beginAppearanceTransition:YES animated:NO];
    [self.scrollView addSubview:self.rootViewController.view];
    [self.rootViewController endAppearanceTransition];
    [self.rootViewController didMoveToParentViewController:self];
    
    [self.view addSubview:self.scrollView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.scrollView setContentOffset:CGPointZero];
}

- (void)updateBounds
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    
    for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
        
        NSArray *viewControllerHashes = [self.viewControllers[@(position)] valueForKeyPath:@"@distinctUnionOfObjects.hash"];
        NSArray *finalFrameKeys = [self.finalFrames.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSNumber *hash, NSDictionary *bindings) {
            return [viewControllerHashes containsObject:hash];
        }]];
        
        NSArray *frames = [self.finalFrames objectsForKeys:finalFrameKeys notFoundMarker:[NSNull null]];
        for(NSValue *value in frames) {
            switch (position) {
                case SCStackViewControllerPositionTop:
                    insets.top = MAX(insets.top, ABS(CGRectGetMinY([value CGRectValue])));
                    break;
                case SCStackViewControllerPositionLeft:
                    insets.left = MAX(insets.left, ABS(CGRectGetMinX([value CGRectValue])));
                    break;
                case SCStackViewControllerPositionBottom:
                    insets.bottom = MAX(insets.bottom, CGRectGetMaxY([value CGRectValue]) - CGRectGetHeight(self.view.bounds));
                    break;
                case SCStackViewControllerPositionRight:
                    insets.right = MAX(insets.right, CGRectGetMaxX([value CGRectValue]) - CGRectGetWidth(self.view.bounds));
                    break;
                default:
                    break;
            }
        }
    }
    
    [self.scrollView setContentInset:insets];
    [self.scrollView setContentSize:self.view.bounds.size];
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return NO;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    for(int position=SCStackViewControllerPositionTop; position<=SCStackViewControllerPositionRight; position++) {
        
        CGRectEdge edge = [self edgeFromOffset:scrollView.contentOffset];
        
        BOOL isReversed = NO;
        if([self.layouters[@(position)] respondsToSelector:@selector(isReversed)]) {
            isReversed = [self.layouters[@(position)] isReversed];
        }
        
        __block CGRect remainder = rectSubtract(self.scrollView.bounds, CGRectIntersection(self.scrollView.bounds, self.rootViewController.view.frame), edge);
        
        NSArray *viewControllersArray = self.viewControllers[@(position)];
        [viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index, BOOL *stop) {
            
            CGRect nextFrame =  [self.layouters[@(position)] currentFrameForViewController:viewController
                                                                                 withIndex:index
                                                                                atPosition:position
                                                                                finalFrame:[self.finalFrames[@(viewController.hash)] CGRectValue]
                                                                             contentOffset:scrollView.contentOffset
                                                                         inStackController:self];
            
            CGRect adjustedFrame = nextFrame;
            if(isReversed) {
                switch (position) {
                    case SCStackViewControllerPositionTop:
                    {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index + 1, viewControllersArray.count - index - 1)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
                        adjustedFrame.origin.y = [self offsetForPosition:position].y + totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionLeft:
                    {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index + 1, viewControllersArray.count - index - 1)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
                        adjustedFrame.origin.x = [self offsetForPosition:position].x + totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionBottom:
                    {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index, viewControllersArray.count - index)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
                        adjustedFrame.origin.y = self.rootViewController.view.bounds.size.height + [self offsetForPosition:position].y - totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionRight:
                    {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index, viewControllersArray.count - index)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
                        adjustedFrame.origin.x = self.rootViewController.view.bounds.size.width + [self offsetForPosition:position].x - totalSize;
                        break;
                    }
                    default:
                        break;
                }
            }
            
            CGRect intersection = CGRectIntersection(remainder, adjustedFrame);
            BOOL visible = ((position == SCStackViewControllerPositionLeft || position == SCStackViewControllerPositionRight) && intersection.size.width > 0.0f);
            visible = visible || ((position == SCStackViewControllerPositionTop || position == SCStackViewControllerPositionBottom) && intersection.size.height > 0.0f);
            
            if(visible) {
                remainder = rectSubtract(remainder, CGRectIntersection(remainder, adjustedFrame), edge);
            }
            
            if(visible && ![self.visibleViewControllers containsObject:viewController]) {
                [self.visibleViewControllers addObject:viewController];
                [viewController beginAppearanceTransition:YES animated:NO];
                [viewController.view setFrame:nextFrame];
                [viewController endAppearanceTransition];
            } else if(!visible && [self.visibleViewControllers containsObject:viewController]) {
                [self.visibleViewControllers removeObject:viewController];
                [viewController beginAppearanceTransition:NO animated:NO];
                [viewController.view setFrame:nextFrame];
                [viewController endAppearanceTransition];
            } else {
                [viewController.view setFrame:nextFrame];
            }
        }];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    
    __block CGRect finalFrame = CGRectZero;
    
    CGFloat iOS5Adjustment = 0.0f;
    if(SYSTEM_VERSION_LESS_THAN(@"6.0")) {
        iOS5Adjustment = 0.1f;
    }
    
    for(int position=SCStackViewControllerPositionTop; position<=SCStackViewControllerPositionRight; position++) {
        
        CGPoint adjustedOffset = *targetContentOffset;
        
        BOOL isReversed = NO;
        if([self.layouters[@(position)] respondsToSelector:@selector(isReversed)]) {
            isReversed = [self.layouters[@(position)] isReversed];
        }
        
        if(isReversed) {
            
            if(position == SCStackViewControllerPositionLeft || position == SCStackViewControllerPositionRight) {
                adjustedOffset.x = [self offsetForPosition:position].x - targetContentOffset->x;
            } else {
                adjustedOffset.y = [self offsetForPosition:position].y - targetContentOffset->y;
            }
        }
        
        NSArray *viewControllersArray = self.viewControllers[@(position)];
        
        __block BOOL keepGoing = YES;
        
        [viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index, BOOL *stop) {
            
            CGRect frame = [self.finalFrames[@(viewController.hash)] CGRectValue];
            frame.origin.x = frame.origin.x > 0 ? CGRectGetMinX(frame) - CGRectGetWidth(self.view.bounds) : CGRectGetMinX(frame);
            frame.origin.y = frame.origin.y > 0 ? CGRectGetMinY(frame) - CGRectGetHeight(self.view.bounds) : CGRectGetMinY(frame);
            
            if(CGRectContainsPoint(frame, adjustedOffset)) {
                
                keepGoing = NO;
                
                finalFrame = frame;
                
                if(velocity.x || velocity.y == 0) {
                    if (velocity.x >= 0.0) {
                        if(isReversed) {
                            targetContentOffset->x = [self offsetForPosition:position].x - CGRectGetMinX(finalFrame) - iOS5Adjustment;
                        } else {
                            targetContentOffset->x = CGRectGetMaxX(finalFrame) - iOS5Adjustment;
                        }
                    }
                    else if (velocity.x < -0.1) {
                        if(isReversed) {
                            targetContentOffset->x = [self offsetForPosition:position].x - CGRectGetMaxX(finalFrame) + iOS5Adjustment;
                        } else {
                            targetContentOffset->x = CGRectGetMinX(finalFrame) + iOS5Adjustment;
                        }
                    }
                } else {
                    if (velocity.y >= 0.0) {
                        if(isReversed) {
                            targetContentOffset->y = [self offsetForPosition:position].y - CGRectGetMinY(finalFrame) - iOS5Adjustment;
                        } else {
                            targetContentOffset->y = CGRectGetMaxY(finalFrame) - iOS5Adjustment;
                        }
                    }
                    else if (velocity.y < -0.1) {
                        if(isReversed) {
                            targetContentOffset->y = [self offsetForPosition:position].y - CGRectGetMaxY(finalFrame) + iOS5Adjustment;
                        } else {
                            targetContentOffset->y = CGRectGetMinY(finalFrame) + iOS5Adjustment;
                        }
                    }
                }
                
                *stop = YES;
            }
        }];
        
        if(!keepGoing) {
            break;
        }
    }
}

#pragma mark - Rotation Handling

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.scrollView setContentOffset:CGPointZero];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    for(int position=SCStackViewControllerPositionTop; position<=SCStackViewControllerPositionRight; position++) {
        [self updateFinalFramesForPosition:position];
    }
    
    [UIView animateWithDuration:kDefaultAnimationDuration animations:^{
        [self scrollViewDidScroll:self.scrollView];
        [self updateBounds];
    }];
}

#pragma mark - Properties

- (BOOL)bounces
{
    return [self.scrollView bounces];
}

- (void)setBounces:(BOOL)bounces
{
    [self.scrollView setBounces:bounces];
}

- (UIBezierPath *)touchRefusalArea
{
    return [self.scrollView touchRefusalArea];
}

- (void)setTouchRefusalArea:(UIBezierPath *)path
{
    [self.scrollView setTouchRefusalArea:path];
}

- (NSMutableDictionary *)layouters
{
    if(_layouters == nil) {
        _layouters = [NSMutableDictionary dictionary];
    }
    
    return _layouters;
}

- (NSMutableDictionary *)finalFrames
{
    if(_finalFrames == nil) {
        _finalFrames = [NSMutableDictionary dictionary];
    }
    
    return _finalFrames;
}

- (NSDictionary *)viewControllers
{
    if(_viewControllers == nil) {
        _viewControllers = (@{
                              @(SCStackViewControllerPositionTop)   : [NSMutableArray array],
                              @(SCStackViewControllerPositionLeft)  : [NSMutableArray array],
                              @(SCStackViewControllerPositionBottom): [NSMutableArray array],
                              @(SCStackViewControllerPositionRight) : [NSMutableArray array]
                              });
    }
    
    return _viewControllers;
}

- (NSMutableArray *)visibleViewControllers
{
    if(_visibleViewControllers == nil) {
        _visibleViewControllers = [NSMutableArray array];
    }
    
    return _visibleViewControllers;
}

#pragma mark - Helpers

- (CGPoint)offsetForPosition:(SCStackViewControllerPosition)position
{
    switch (position) {
        case SCStackViewControllerPositionTop:
            return CGPointMake(0, -self.scrollView.contentInset.top);
        case SCStackViewControllerPositionLeft:
            return CGPointMake(-self.scrollView.contentInset.left, 0);
        case SCStackViewControllerPositionBottom:
            return CGPointMake(0, self.scrollView.contentInset.bottom);
        case SCStackViewControllerPositionRight:
            return CGPointMake(self.scrollView.contentInset.right, 0);
        default:
            return CGPointZero;
    }
}

- (CGRectEdge)edgeFromOffset:(CGPoint)offset
{
    if(offset.x >= 0.0f) {
        return CGRectMinXEdge;
    } else if(offset.x < 0.0f) {
        return CGRectMaxXEdge;
    } else if(offset.y >= 0.0f) {
        return CGRectMinYEdge;
    } else {
        return CGRectMaxYEdge;
    }
}

CGRect rectSubtract(CGRect r1, CGRect r2, CGRectEdge edge)
{
    CGRect intersection = CGRectIntersection(r1, r2);
    if (CGRectIsNull(intersection)) {
        return r1;
    }
    
    float chopAmount = (edge == CGRectMinXEdge || edge == CGRectMaxXEdge) ? intersection.size.width : intersection.size.height;
    
    CGRect r3, throwaway;
    CGRectDivide(r1, &throwaway, &r3, chopAmount, edge);
    return r3;
}

@end
