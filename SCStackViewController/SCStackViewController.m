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

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

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
@dynamic showsScrollIndicators;
@dynamic minimumNumberOfTouches;
@dynamic maximumNumberOfTouches;

#pragma mark - Constructors

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
    if(self = [super init]) {
        self.rootViewController = rootViewController;
        
        self.viewControllers = (@{
                                  @(SCStackViewControllerPositionTop)   : [NSMutableArray array],
                                  @(SCStackViewControllerPositionLeft)  : [NSMutableArray array],
                                  @(SCStackViewControllerPositionBottom): [NSMutableArray array],
                                  @(SCStackViewControllerPositionRight) : [NSMutableArray array]
                                  });
        
        self.visibleViewControllers = [NSMutableArray array];
        
        self.layouters = [NSMutableDictionary dictionary];
        self.finalFrames = [NSMutableDictionary dictionary];
        
        self.animationDuration = 0.25f;
        self.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
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
    
    
    id<SCStackLayouterProtocol> layouter = self.layouters[@(position)];
    
    [self addChildViewController:viewController];
    viewController.view.frame = [self.finalFrames[@(viewController.hash)] CGRectValue];
    
    BOOL shouldStackAboveRoot = NO;
    if([layouter respondsToSelector:@selector(shouldStackControllersAboveRoot)]) {
        shouldStackAboveRoot = [layouter shouldStackControllersAboveRoot];
    }
    
    if(shouldStackAboveRoot) {
        [self.scrollView insertSubview:viewController.view aboveSubview:self.rootViewController.view];
    } else {
        [self.scrollView insertSubview:viewController.view atIndex:0];
    }
    
    [viewController didMoveToParentViewController:self];
    
    [self updateBounds];
    
    if(unfold) {
        [self.scrollView setContentOffset:[self maximumInsetForPosition:position]
                       withTimingFunction:self.timingFunction
                                 duration:(animated ? self.animationDuration : 0.0f)
                               completion:completion];
    } else if(completion) {
        completion();
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
    
    void(^cleanup)() = ^{
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
    };
    
    if([self.visibleViewControllers containsObject:lastViewController]) {
        [self navigateToViewController:previousViewController
                              animated:animated
                            completion:cleanup];
    } else {
        cleanup();
    }
}

- (void)popToRootViewControllerFromPosition:(SCStackViewControllerPosition)position
                                   animated:(BOOL)animated
                                 completion:(void(^)())completion
{
    [self navigateToViewController:self.rootViewController
                          animated:animated
                        completion:^{
                            NSMutableArray *viewControllers = self.viewControllers[@(position)];
                            
                            for(UIViewController *controller in [viewControllers copy]) {
                                [self popViewControllerAtPosition:position animated:NO completion:nil];
                            }
                            
                            [viewControllers removeAllObjects];
                            
                            if(completion) {
                                completion();
                            }
                        }];
}

- (void)navigateToViewController:(UIViewController *)viewController
                        animated:(BOOL)animated
                      completion:(void(^)())completion;
{
    CGPoint offset = CGPointZero;
    CGRect finalFrame = CGRectZero;
    
    [self updateBounds];
    
    if(![viewController isEqual:self.rootViewController]) {
        
        finalFrame = [[self.finalFrames objectForKey:@(viewController.hash)] CGRectValue];
        
        SCStackViewControllerPosition controllerPosition = [self positionForViewController:viewController];
        
        BOOL isReversed = NO;
        if([self.layouters[@(controllerPosition)] respondsToSelector:@selector(isReversed)]) {
            isReversed = [self.layouters[@(controllerPosition)] isReversed];
        }
        
        switch (controllerPosition) {
            case SCStackViewControllerPositionTop:
                offset.y = (isReversed ? ([self maximumInsetForPosition:controllerPosition].y - CGRectGetMaxY(finalFrame)) : CGRectGetMinY(finalFrame));
                break;
            case SCStackViewControllerPositionLeft:
                offset.x = (isReversed ? ([self maximumInsetForPosition:controllerPosition].x - CGRectGetMaxX(finalFrame)) : CGRectGetMinX(finalFrame));
                break;
            case SCStackViewControllerPositionBottom:
                offset.y = (isReversed ? ([self maximumInsetForPosition:controllerPosition].y - CGRectGetMinY(finalFrame) + CGRectGetHeight(self.view.bounds)) : CGRectGetMaxY(finalFrame) - CGRectGetHeight(self.view.bounds));
                break;
            case SCStackViewControllerPositionRight:
                offset.x = (isReversed ? ([self maximumInsetForPosition:controllerPosition].x - CGRectGetMinX(finalFrame) + CGRectGetWidth(self.view.bounds)) : CGRectGetMaxX(finalFrame) - CGRectGetWidth(self.view.bounds));
                break;
            default:
                break;
        }
    }
    
    [self.scrollView setContentOffset:offset
                   withTimingFunction:self.timingFunction
                             duration:(animated ? self.animationDuration : 0.0f)
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

#pragma mark - UIViewController View Events

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    
    self.scrollView = [[MOScrollView alloc] initWithFrame:self.view.bounds];
    [self.scrollView setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self.scrollView setDirectionalLockEnabled:YES];
    [self.scrollView setDecelerationRate:UIScrollViewDecelerationRateFast];
    [self.scrollView setDelegate:self];
    
    [self setPagingEnabled:YES];
    
    [self addChildViewController:self.rootViewController];
    [self.rootViewController.view setFrame:self.view.bounds];
    [self.scrollView addSubview:self.rootViewController.view];
    [self.rootViewController didMoveToParentViewController:self];
    
    [self.view addSubview:self.scrollView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self scrollViewDidEndDecelerating:self.scrollView];
    [self.rootViewController beginAppearanceTransition:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.rootViewController endAppearanceTransition];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.rootViewController beginAppearanceTransition:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self.rootViewController endAppearanceTransition];
}

#pragma mark - Stack Management

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
    
    [self.scrollView setDelegate:nil];
    
    CGPoint offset = self.scrollView.contentOffset;
    [self.scrollView setContentInset:insets];
    
    if((self.scrollView.contentInset.left <= insets.left) || (self.scrollView.contentInset.top <= insets.top)) {
        [self.scrollView setContentOffset:offset];
    }
    
    [self.scrollView setContentSize:self.view.bounds.size];
    [self.scrollView setDelegate:self];
}

- (void)updateNavigationContraints
{
    if(self.continuousNavigationEnabled) {
        return;
    }
    
    UIEdgeInsets insets = UIEdgeInsetsZero;
    UIViewController *lastVisibleViewController = [self.visibleViewControllers lastObject];
    
    if(CGPointEqualToPoint(self.scrollView.contentOffset, CGPointZero) || lastVisibleViewController == nil) {
        for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
            NSArray *viewControllers = self.viewControllers[@(position)];
            
            if(viewControllers.count == 0) {
                continue;
            }
            
            switch (position) {
                case SCStackViewControllerPositionTop:
                    insets.top = [viewControllers[0] view].frame.size.height;
                    break;
                case SCStackViewControllerPositionLeft:
                    insets.left = [viewControllers[0] view].frame.size.width;
                    break;
                case SCStackViewControllerPositionBottom:
                    insets.bottom = [viewControllers[0] view].frame.size.height;
                    break;
                case SCStackViewControllerPositionRight:
                    insets.right = [viewControllers[0] view].frame.size.width;
                    break;
                default:
                    break;
            }
        }
        
        [self.scrollView setContentInset:insets];
        return;
    }

    SCStackViewControllerPosition lastVisibleControllerPosition = [self positionForViewController:lastVisibleViewController];
    NSArray *viewControllersArray = self.viewControllers[@(lastVisibleControllerPosition)];
    
    lastVisibleViewController = [[self.visibleViewControllers sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [@([viewControllersArray indexOfObject:obj1]) compare:@([viewControllersArray indexOfObject:obj2])];
    }] lastObject];
    
    NSUInteger visibleControllerIndex = [viewControllersArray indexOfObject:lastVisibleViewController];
    NSArray *remainingViewControllers;
    
    if(visibleControllerIndex >= viewControllersArray.count - 1) {
        remainingViewControllers = viewControllersArray;
    } else {
        remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(0, visibleControllerIndex + 2)];
    }
    
    switch (lastVisibleControllerPosition) {
        case SCStackViewControllerPositionTop:
        {
            CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
            insets.top = totalSize;
            break;
        }
        case SCStackViewControllerPositionLeft:
        {
            CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
            insets.left = totalSize;
            break;
        }
        case SCStackViewControllerPositionBottom:
        {
            CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
            insets.bottom = totalSize;
            break;
        }
        case SCStackViewControllerPositionRight:
        {
            CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
            insets.right = totalSize;
            break;
        }
        default:
            break;
    }
    
    [self.scrollView setContentInset:insets];
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return NO;
}

- (void)updateFramesAndTriggerAppearanceCallbacks
{
    CGPoint offset = self.scrollView.contentOffset;
    
    id<SCStackLayouterProtocol> activeLayouter;
    if(offset.y < 0.0f) {
        activeLayouter = self.layouters[@(SCStackViewControllerPositionTop)];
    } else if(offset.x < 0.0f) {
        activeLayouter = self.layouters[@(SCStackViewControllerPositionLeft)];
    } else if(offset.y > 0.0f){
        activeLayouter = self.layouters[@(SCStackViewControllerPositionBottom)];
    } else if(offset.x > 0.0f) {
        activeLayouter = self.layouters[@(SCStackViewControllerPositionRight)];
    }
    
    for(int position=SCStackViewControllerPositionTop; position<=SCStackViewControllerPositionRight; position++) {

        id<SCStackLayouterProtocol> layouter = self.layouters[@(position)];
        
        if([layouter isEqual:activeLayouter]) {
            if([layouter respondsToSelector:@selector(currentFrameForRootViewController:contentOffset:inStackController:)]) {
                CGRect frame = [layouter currentFrameForRootViewController:self.rootViewController
                                                             contentOffset:offset
                                                         inStackController:self];
                [self.rootViewController.view setFrame:frame];
            } else {
                [self.rootViewController.view setFrame:self.view.bounds];
            }
        }
        
        BOOL shouldStackAboveRoot = NO;
        if([layouter respondsToSelector:@selector(shouldStackControllersAboveRoot)]) {
            shouldStackAboveRoot = [layouter shouldStackControllersAboveRoot];
        }
        
        CGRectEdge edge = [self edgeFromOffset:offset];
        __block CGRect remainder;
        if(shouldStackAboveRoot) {
            remainder = self.scrollView.bounds;
        } else {
            remainder = CGRectSubtract(self.scrollView.bounds, CGRectIntersection(self.scrollView.bounds, self.rootViewController.view.frame), edge);
        }
        
        BOOL isReversed = NO;
        if([layouter respondsToSelector:@selector(isReversed)]) {
            isReversed = [layouter isReversed];
        }
        
        NSArray *viewControllersArray = self.viewControllers[@(position)];
        [viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index, BOOL *stop) {
            
            CGRect nextFrame =  [layouter currentFrameForViewController:viewController
                                                              withIndex:index
                                                             atPosition:position
                                                             finalFrame:[self.finalFrames[@(viewController.hash)] CGRectValue]
                                                          contentOffset:offset
                                                      inStackController:self];
            
            CGRect adjustedFrame = nextFrame;
            if(isReversed && index > 0) {
                switch (position) {
                    case SCStackViewControllerPositionTop:
                    {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index + 1, viewControllersArray.count - index - 1)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
                        adjustedFrame.origin.y = [self maximumInsetForPosition:position].y + totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionLeft:
                    {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index + 1, viewControllersArray.count - index - 1)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
                        adjustedFrame.origin.x = [self maximumInsetForPosition:position].x + totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionBottom:
                    {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index, viewControllersArray.count - index)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
                        adjustedFrame.origin.y = self.view.bounds.size.height + [self maximumInsetForPosition:position].y - totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionRight:
                    {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index, viewControllersArray.count - index)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
                        adjustedFrame.origin.x = self.view.bounds.size.width + [self maximumInsetForPosition:position].x - totalSize;
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
                remainder = CGRectSubtract(remainder, CGRectIntersection(remainder, adjustedFrame), edge);
            }
            
            if(visible && ![self.visibleViewControllers containsObject:viewController]) {
                [self.visibleViewControllers addObject:viewController];
                [viewController beginAppearanceTransition:YES animated:NO];
                [viewController.view setFrame:nextFrame];
                [viewController endAppearanceTransition];
                
                if([self.delegate respondsToSelector:@selector(stackViewController:didShowViewController:position:)]) {
                    [self.delegate stackViewController:self didShowViewController:viewController position:position];
                }
                
            } else if(!visible && [self.visibleViewControllers containsObject:viewController]) {
                [self.visibleViewControllers removeObject:viewController];
                [viewController beginAppearanceTransition:NO animated:NO];
                [viewController.view setFrame:nextFrame];
                [viewController endAppearanceTransition];
                
                if([self.delegate respondsToSelector:@selector(stackViewController:didHideViewController:position:)]) {
                    [self.delegate stackViewController:self didHideViewController:viewController position:position];
                }
                
            } else {
                [viewController.view setFrame:nextFrame];
            }
        }];
    }
}

- (void)adjustTargetContentOffset:(inout CGPoint *)targetContentOffset withVelocity:(CGPoint)velocity
{
    if(!self.pagingEnabled && self.continuousNavigationEnabled) {
        return;
    }
    
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
            if(position == SCStackViewControllerPositionLeft && targetContentOffset->x < 0.0f) {
                adjustedOffset.x = [self maximumInsetForPosition:position].x - targetContentOffset->x;
            }
            else if(position == SCStackViewControllerPositionRight && targetContentOffset->x >= 0.0f) {
                adjustedOffset.x = [self maximumInsetForPosition:position].x - targetContentOffset->x;
            }
            else if(position == SCStackViewControllerPositionTop && targetContentOffset->y < 0.0f) {
                adjustedOffset.y = [self maximumInsetForPosition:position].y - targetContentOffset->y;
            }
            else if(position == SCStackViewControllerPositionBottom && targetContentOffset->y >= 0.0f) {
                adjustedOffset.y = [self maximumInsetForPosition:position].y - targetContentOffset->y;
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
                
                CGPoint adjustedVelocity = velocity;
                if(CGPointEqualToPoint(CGPointZero, adjustedVelocity)) {
                    switch (position) {
                        case SCStackViewControllerPositionTop:
                        case SCStackViewControllerPositionBottom:
                        {
                            CGFloat verticalPercentageShown = ABS((ABS(frame.origin.y) - ABS(adjustedOffset.y))) / frame.size.height;
                            if(isReversed) {
                                verticalPercentageShown = 1.0f - verticalPercentageShown;
                            }
                            adjustedVelocity.y = verticalPercentageShown > 0.5f ? 1.0f : -1.0f;
                            
                            break;
                        }
                        case SCStackViewControllerPositionLeft:
                        case SCStackViewControllerPositionRight:
                        {
                            CGFloat horizontalPercentageShown = ABS((ABS(frame.origin.x) - ABS(adjustedOffset.x))) / frame.size.width;
                            if(isReversed) {
                                horizontalPercentageShown = 1.0f - horizontalPercentageShown;
                            }
                            adjustedVelocity.x = horizontalPercentageShown > 0.5f ? 1.0f : -1.0f;
                            
                            break;
                        }
                        default:
                            break;
                    }
                }
                
                if(adjustedVelocity.x) {
                    if (adjustedVelocity.x >= 0.0f) {
                        if(isReversed) {
                            targetContentOffset->x = [self maximumInsetForPosition:position].x - CGRectGetMinX(finalFrame) - iOS5Adjustment;
                        } else {
                            targetContentOffset->x = CGRectGetMaxX(finalFrame) - iOS5Adjustment;
                        }
                    }
                    else if (adjustedVelocity.x < 0.0f) {
                        if(isReversed) {
                            targetContentOffset->x = [self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame) + iOS5Adjustment;
                        } else {
                            targetContentOffset->x = CGRectGetMinX(finalFrame) + iOS5Adjustment;
                        }
                    }
                } else if(adjustedVelocity.y) {
                    if (adjustedVelocity.y > 0.0f) {
                        if(isReversed) {
                            targetContentOffset->y = [self maximumInsetForPosition:position].y - CGRectGetMinY(finalFrame) - iOS5Adjustment;
                        } else {
                            targetContentOffset->y = CGRectGetMaxY(finalFrame) - iOS5Adjustment;
                        }
                    }
                    else if (adjustedVelocity.y < 0.0f) {
                        if(isReversed) {
                            targetContentOffset->y = [self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame) + iOS5Adjustment;
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

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateFramesAndTriggerAppearanceCallbacks];
    
    if([self.delegate respondsToSelector:@selector(stackViewController:didNavigateToOffset:)]) {
        [self.delegate stackViewController:self didNavigateToOffset:self.scrollView.contentOffset];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if(self.scrollView.isTracking) {
        return;
    }
    
    [self updateNavigationContraints];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self updateNavigationContraints];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if(decelerate == NO) {
        [self updateNavigationContraints];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    [self adjustTargetContentOffset:targetContentOffset withVelocity:velocity];
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
    
    [UIView animateWithDuration:self.animationDuration animations:^{
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

- (BOOL)showsScrollIndicators
{
    return [self.scrollView showsHorizontalScrollIndicator] && [self.scrollView showsVerticalScrollIndicator];
}

- (void)setShowsScrollIndicators:(BOOL)showsScrollIndicators
{
    [self.scrollView setShowsHorizontalScrollIndicator:showsScrollIndicators];
    [self.scrollView setShowsVerticalScrollIndicator:showsScrollIndicators];
}

- (NSUInteger)minimumNumberOfTouches
{
    return self.scrollView.panGestureRecognizer.minimumNumberOfTouches;
}

- (void)setMinimumNumberOfTouches:(NSUInteger)minimumNumberOfTouches
{
    [self.scrollView.panGestureRecognizer setMinimumNumberOfTouches:minimumNumberOfTouches];
}

- (NSUInteger)maximumNumberOfTouches
{
    return self.scrollView.maximumNumberOfTouches;
}

- (void)setMaximumNumberOfTouches:(NSUInteger)maximumNumberOfTouches
{
    [self.scrollView setMaximumNumberOfTouches:maximumNumberOfTouches];
}

#pragma mark - Helpers

- (CGPoint)maximumInsetForPosition:(SCStackViewControllerPosition)position
{
    switch (position) {
        case SCStackViewControllerPositionTop:
            return CGPointMake(0, -[[self.viewControllers[@(position)] valueForKeyPath:@"@sum.viewHeight"] floatValue]);
        case SCStackViewControllerPositionLeft:
            return CGPointMake(-[[self.viewControllers[@(position)] valueForKeyPath:@"@sum.viewWidth"] floatValue], 0);
        case SCStackViewControllerPositionBottom:
            return CGPointMake(0, [[self.viewControllers[@(position)] valueForKeyPath:@"@sum.viewHeight"] floatValue]);
        case SCStackViewControllerPositionRight:
            return CGPointMake([[self.viewControllers[@(position)] valueForKeyPath:@"@sum.viewWidth"] floatValue], 0);
        default:
            return CGPointZero;
    }
}

- (SCStackViewControllerPosition)positionForViewController:(UIViewController *)viewController
{
    for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
        if([self.viewControllers[@(position)] containsObject:viewController]) {
            return position;
        }
    }
    
    return -1;
}

- (CGRectEdge)edgeFromOffset:(CGPoint)offset
{
    CGRectEdge edge = -1;
    
    if(offset.x > 0.0f) {
        edge = CGRectMinXEdge;
    } else if(offset.x < 0.0f) {
        edge = CGRectMaxXEdge;
    } else if(offset.y > 0.0f) {
        edge = CGRectMinYEdge;
    } else if(offset.y < 0.0f) {
        edge = CGRectMaxYEdge;
    }
    
    return edge;
}

CGRect CGRectSubtract(CGRect r1, CGRect r2, CGRectEdge edge)
{
    CGRect intersection = CGRectIntersection(r1, r2);
    if (CGRectIsNull(intersection)) {
        return r1;
    }
    
    float chopAmount = (edge == CGRectMinXEdge || edge == CGRectMaxXEdge) ? intersection.size.width : intersection.size.height;
    
    CGRect remainder, throwaway;
    CGRectDivide(r1, &throwaway, &remainder, chopAmount, edge);
    return remainder;
}

@end


@implementation UIViewController (SCStackViewController)

- (SCStackViewController *)stackViewController
{
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[SCStackViewController class]])  {
            return (SCStackViewController *)responder;
        }
    }
    return nil;
}

- (CGFloat)viewWidth
{
    return self.view.bounds.size.width;
}

- (CGFloat)viewHeight
{
    return self.view.bounds.size.height;
}

@end
