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
        
        self.viewControllers = (@{
                                  @(SCStackViewControllerPositionTop)   : [NSMutableArray array],
                                  @(SCStackViewControllerPositionLeft)  : [NSMutableArray array],
                                  @(SCStackViewControllerPositionBottom): [NSMutableArray array],
                                  @(SCStackViewControllerPositionRight) : [NSMutableArray array]
                                  });
        
        self.visibleViewControllers = [NSMutableArray array];
        
        self.layouters = [NSMutableDictionary dictionary];
        self.finalFrames = [NSMutableDictionary dictionary];
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

#pragma mark - UIViewController View Events

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
    
    [self setPagingEnabled:YES];
    
    [self addChildViewController:self.rootViewController];
    [self.rootViewController.view setFrame:self.scrollView.bounds];
    [self.rootViewController beginAppearanceTransition:YES animated:NO];
    [self.scrollView addSubview:self.rootViewController.view];
    [self.rootViewController endAppearanceTransition];
    [self.rootViewController didMoveToParentViewController:self];
    
    [self.view addSubview:self.scrollView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self scrollViewDidEndDecelerating:self.scrollView];
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
    
    UIViewController *lastVisibleViewController = [self.visibleViewControllers lastObject];
    
    UIEdgeInsets insets = UIEdgeInsetsZero;
    
    if(CGPointEqualToPoint(self.scrollView.contentOffset, CGPointZero) || lastVisibleViewController == nil) {
        for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
            NSArray *viewControllers = self.viewControllers[@(position)];
            if(viewControllers.count) {
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
        }
    } else {
        SCStackViewControllerPosition lastVisibleControllerPosition = -1;
        NSArray *viewControllersArray;
        for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
            if([self.viewControllers[@(position)] containsObject:lastVisibleViewController]) {
                lastVisibleControllerPosition = position;
                viewControllersArray = self.viewControllers[@(position)];
            }
        }
        
        NSUInteger visibleControllerIndex = [viewControllersArray indexOfObject:lastVisibleViewController];
        NSArray *remainingViewControllers;
        
        if(visibleControllerIndex >= viewControllersArray.count - 1) {
            remainingViewControllers = viewControllersArray;
        } else {
            remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(0, visibleControllerIndex + 2)];
        }
        
        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
        
        switch (lastVisibleControllerPosition) {
            case SCStackViewControllerPositionTop:
                insets.top = totalSize;
                break;
            case SCStackViewControllerPositionLeft:
                insets.left = totalSize;
                break;
            case SCStackViewControllerPositionBottom:
                insets.bottom = totalSize;
                break;
            case SCStackViewControllerPositionRight:
                insets.right = totalSize;
                break;
            default:
                break;
        }
    }
    
    [self.scrollView setContentInset:insets];
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return NO;
}

- (void)updateFramesAndTriggerAppearanceCallbacks
{
    for(int position=SCStackViewControllerPositionTop; position<=SCStackViewControllerPositionRight; position++) {
        
        CGRectEdge edge = [self edgeFromOffset:self.scrollView.contentOffset];
        
        BOOL isReversed = NO;
        if([self.layouters[@(position)] respondsToSelector:@selector(isReversed)]) {
            isReversed = [self.layouters[@(position)] isReversed];
        }
        
        __block CGRect remainder = CGRectSubtract(self.scrollView.bounds, CGRectIntersection(self.scrollView.bounds, self.rootViewController.view.frame), edge);
        
        NSArray *viewControllersArray = self.viewControllers[@(position)];
        [viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index, BOOL *stop) {
            
            CGRect nextFrame =  [self.layouters[@(position)] currentFrameForViewController:viewController
                                                                                 withIndex:index
                                                                                atPosition:position
                                                                                finalFrame:[self.finalFrames[@(viewController.hash)] CGRectValue]
                                                                             contentOffset:self.scrollView.contentOffset
                                                                         inStackController:self];
            
            CGRect adjustedFrame = nextFrame;
            if(isReversed && index > 0) {
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
                adjustedOffset.x = [self offsetForPosition:position].x - targetContentOffset->x;
            }
            else if(position == SCStackViewControllerPositionRight && targetContentOffset->x >= 0.0f) {
                adjustedOffset.x = [self offsetForPosition:position].x - targetContentOffset->x;
            }
            else if(position == SCStackViewControllerPositionTop && targetContentOffset->y < 0.0f) {
                adjustedOffset.y = [self offsetForPosition:position].y - targetContentOffset->y;
            }
            else if(position == SCStackViewControllerPositionBottom && targetContentOffset->y >= 0.0f) {
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
