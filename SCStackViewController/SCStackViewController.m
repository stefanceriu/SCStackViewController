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

#import "SCStackNavigationStep.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@interface SCStackViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIViewController *rootViewController;

@property (nonatomic, strong) MOScrollView *scrollView;

@property (nonatomic, strong) NSMutableDictionary *layouters;
@property (nonatomic, strong) NSMutableDictionary *finalFrames;

@property (nonatomic, strong) NSDictionary *viewControllers;
@property (nonatomic, strong) NSMutableArray *visibleViewControllers;


@property (nonatomic, strong) NSMutableDictionary *navigationSteps;

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
        self.navigationSteps = [NSMutableDictionary dictionary];
        
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

- (void)registerNavigationSteps:(NSArray *)navigationSteps forViewController:(UIViewController *)viewController
{
    navigationSteps = [navigationSteps sortedArrayUsingComparator:^NSComparisonResult(SCStackNavigationStep *obj1, SCStackNavigationStep *obj2) {
        return obj1.percentage > obj2.percentage;
    }];
    
    [self.navigationSteps setObject:navigationSteps forKey:@([viewController hash])];
}


- (void)pushViewController:(UIViewController *)viewController
                atPosition:(SCStackViewControllerPosition)position
                    unfold:(BOOL)unfold
                  animated:(BOOL)animated
                completion:(void(^)())completion
{
    NSAssert(viewController != nil, @"Trying to push nil view controller");
    
    if([[self.viewControllers.allValues valueForKeyPath:@"@unionOfArrays.self"] containsObject:viewController]) {
        NSLog(@"Trying to push an already pushed view controller");
        
        if(unfold) {
            [self navigateToViewController:viewController animated:animated completion:completion];
        } else if(completion) {
            completion();
        }
        return;
    }
    
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
    
    [self updateContentSizeIgnoringNavigationContraints];
    
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
        [self updateContentSizeIgnoringNavigationContraints];
        
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
    
    [self updateContentSizeIgnoringNavigationContraints];
    
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
    [self.rootViewController beginAppearanceTransition:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.rootViewController endAppearanceTransition];

    [self updateBoundsUsingNavigationContraints];
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

#pragma mark Navigation Contraints

// Sets the insets to the summed up sizes of all the participating view controllers (used before pushing and popping)
- (void)updateContentSizeIgnoringNavigationContraints
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    
    for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <= SCStackViewControllerPositionRight; position++) {
        
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
    [self.scrollView setContentInset:insets];
    
    CGPoint offset = self.scrollView.contentOffset;
    if((self.scrollView.contentInset.left <= insets.left) || (self.scrollView.contentInset.top <= insets.top)) {
        [self.scrollView setContentOffset:offset];
    }
    
    [self.scrollView setContentSize:self.view.bounds.size];
    [self.scrollView setDelegate:self];
}

// Sets the insets to the first encountered navigation steps in all directions (used when stack is centred on the root)
- (void)updateContentSizeUsingDefaultNavigationContraints
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    
    for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
        NSArray *viewControllers = self.viewControllers[@(position)];
        
        if(viewControllers.count == 0) {
            continue;
        }
        
        BOOL isReversed = NO;
        if([self.layouters[@(position)] respondsToSelector:@selector(isReversed)]) {
            isReversed = [self.layouters[@(position)] isReversed];
        }
        
        switch (position) {
            case SCStackViewControllerPositionTop:
                insets.top = ABS([self nextStepOffsetForViewController:viewControllers[0] position:position velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:CGPointZero].y);
                break;
            case SCStackViewControllerPositionLeft:
                insets.left = ABS([self nextStepOffsetForViewController:viewControllers[0] position:position velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:CGPointZero].x);
                break;
            case SCStackViewControllerPositionBottom:
                insets.bottom = ABS([self nextStepOffsetForViewController:viewControllers[0] position:position velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:CGPointZero].y);
                break;
            case SCStackViewControllerPositionRight:
                insets.right = ABS([self nextStepOffsetForViewController:viewControllers[0] position:position velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:CGPointZero].x);
                break;
            default:
                break;
        }
    }
    
    [self.scrollView setContentInset:insets];
}

// Sets the insets to the next navigation steps based on the current state
- (void)updateBoundsUsingNavigationContraints
{
    if(self.continuousNavigationEnabled) {
        return;
    }
    
    UIEdgeInsets insets = UIEdgeInsetsZero;
    UIViewController *lastVisibleController = [self.visibleViewControllers lastObject];
    
    if(CGPointEqualToPoint(self.scrollView.contentOffset, CGPointZero) || lastVisibleController == nil) {
        [self updateContentSizeUsingDefaultNavigationContraints];
        return;
    }
    
    SCStackViewControllerPosition lastVisibleControllerPosition = [self positionForViewController:lastVisibleController];
    
    NSArray *viewControllersArray = self.viewControllers[@(lastVisibleControllerPosition)];
    
    lastVisibleController = [[self.visibleViewControllers sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [@([viewControllersArray indexOfObject:obj1]) compare:@([viewControllersArray indexOfObject:obj2])];
    }] lastObject];
    
    
    NSUInteger visibleControllerIndex = [viewControllersArray indexOfObject:lastVisibleController];
    
    BOOL isReversed = NO;
    if([self.layouters[@(lastVisibleControllerPosition)] respondsToSelector:@selector(isReversed)]) {
        isReversed = [self.layouters[@(lastVisibleControllerPosition)] isReversed];
    }
    
    switch (lastVisibleControllerPosition) {
        case SCStackViewControllerPositionTop: {
            // Fetch the next step and set it as the current inset
            insets.top = ABS([self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].y);
            
            // If the next step is the upper bound of the current view controller and there are more view controllers on the stack, fetch the following view controller's first navigation step and use that
            if(ABS(self.scrollView.contentOffset.y) == insets.top && visibleControllerIndex < viewControllersArray.count - 1) {
                insets.top = ABS([self nextStepOffsetForViewController:viewControllersArray[visibleControllerIndex + 1] position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].y);
            }
            
            // Reverse the velocity, fetch the previous navigation step and use it as the inset for the opposite direction so that the navigation contraint works coming back as well
            insets.bottom = [self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].y;
            
            break;
        }
        case SCStackViewControllerPositionLeft: {
            insets.left = ABS([self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].x);
            
            if(ABS(self.scrollView.contentOffset.x) == insets.left && visibleControllerIndex < viewControllersArray.count - 1) {
                insets.left = ABS([self nextStepOffsetForViewController:viewControllersArray[visibleControllerIndex + 1] position:lastVisibleControllerPosition velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].x);
            }
            
            insets.right = [self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].x;
            
            break;
        }
        case SCStackViewControllerPositionBottom: {
            insets.bottom = ABS([self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].y);
            
            if(ABS(self.scrollView.contentOffset.y) == insets.bottom && visibleControllerIndex < viewControllersArray.count - 1) {
                insets.bottom = ABS([self nextStepOffsetForViewController:viewControllersArray[visibleControllerIndex + 1] position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, 1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].y);
            }
            
            insets.top = - [self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(0.0f, -1.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].y;
            
            break;
        }
        case SCStackViewControllerPositionRight: {
            insets.right = ABS([self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].x);
            
            if(ABS(self.scrollView.contentOffset.x) == insets.right && visibleControllerIndex < viewControllersArray.count - 1) {
                insets.right = ABS([self nextStepOffsetForViewController:viewControllersArray[visibleControllerIndex + 1] position:lastVisibleControllerPosition velocity:CGPointMake(1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].x);
            }
            
            insets.left = - [self nextStepOffsetForViewController:lastVisibleController position:lastVisibleControllerPosition velocity:CGPointMake(-1.0f, 0.0f) reversed:isReversed contentOffset:self.scrollView.contentOffset].x;
            
            break;
        }
        default:
            break;
    }
    
    [self.scrollView setContentInset:insets];
}

#pragma mark Appearance callbacks and framesetting

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
            }
        } else if(activeLayouter == nil) {
            [self.rootViewController.view setFrame:self.view.bounds];
        }
        
        BOOL shouldStackControllersAboveRoot = NO;
        if([layouter respondsToSelector:@selector(shouldStackControllersAboveRoot)]) {
            shouldStackControllersAboveRoot = [layouter shouldStackControllersAboveRoot];
        }
        
        CGRectEdge edge = [self edgeFromOffset:offset];
        __block CGRect remainder;
        
        // Determine the amount of unobstructed space the stacked view controllers might be seen through
        if(shouldStackControllersAboveRoot) {
            remainder = CGRectSubtract(self.scrollView.bounds, CGRectIntersection(self.scrollView.bounds, self.view.bounds), edge);
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
            
            // If using a reversed layouter adjust the frame to normal
            if(isReversed && index > 0) {
                switch (position) {
                    case SCStackViewControllerPositionTop: {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index + 1, viewControllersArray.count - index - 1)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
                        adjustedFrame.origin.y = [self maximumInsetForPosition:position].y + totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionLeft: {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index + 1, viewControllersArray.count - index - 1)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
                        adjustedFrame.origin.x = [self maximumInsetForPosition:position].x + totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionBottom: {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index, viewControllersArray.count - index)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewHeight"] floatValue];
                        adjustedFrame.origin.y = CGRectGetHeight(self.view.bounds) + [self maximumInsetForPosition:position].y - totalSize;
                        break;
                    }
                    case SCStackViewControllerPositionRight: {
                        NSArray *remainingViewControllers = [viewControllersArray subarrayWithRange:NSMakeRange(index, viewControllersArray.count - index)];
                        CGFloat totalSize = [[remainingViewControllers valueForKeyPath:@"@sum.viewWidth"] floatValue];
                        adjustedFrame.origin.x = CGRectGetWidth(self.view.bounds) + [self maximumInsetForPosition:position].x - totalSize;
                        break;
                    }
                    default:
                        break;
                }
            }
            
            
            CGRect intersection = CGRectIntersection(remainder, adjustedFrame);
            
            // If a view controller's frame does intersect the remainder then it's visible
            BOOL visible = ((position == SCStackViewControllerPositionLeft || position == SCStackViewControllerPositionRight) && CGRectGetWidth(intersection) > 0.0f);
            visible = visible || ((position == SCStackViewControllerPositionTop || position == SCStackViewControllerPositionBottom) && CGRectGetHeight(intersection) > 0.0f);
            
            if(visible) {
                // And if it's visible then we prepare for the next view controller by reducing the remainder some more
                remainder = CGRectSubtract(remainder, CGRectIntersection(remainder, adjustedFrame), edge);
            }
            
            // Finally, trigger appearance callbacks and new frame
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

#pragma mark Pagination

- (void)adjustTargetContentOffset:(inout CGPoint *)targetContentOffset withVelocity:(CGPoint)velocity
{
    if(!self.pagingEnabled && self.continuousNavigationEnabled) {
        return;
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
            frame.origin.x = frame.origin.x > 0.0f ? CGRectGetMinX(frame) - CGRectGetWidth(self.view.bounds) : CGRectGetMinX(frame);
            frame.origin.y = frame.origin.y > 0.0f ? CGRectGetMinY(frame) - CGRectGetHeight(self.view.bounds) : CGRectGetMinY(frame);
            
            if(CGRectContainsPoint(frame, adjustedOffset)) {
                
                keepGoing = NO;
                
                CGPoint adjustedVelocity = velocity;
                
                // If the velocity is zero then adjust it based on which half of the view controller is visible
                if(CGPointEqualToPoint(CGPointZero, adjustedVelocity)) {
                    switch (position) {
                        case SCStackViewControllerPositionTop:
                        case SCStackViewControllerPositionBottom:
                        {
                            CGFloat verticalPercentageShown = ABS((ABS(frame.origin.y) - ABS(adjustedOffset.y))) / CGRectGetHeight(frame);
                            if(isReversed) {
                                verticalPercentageShown = 1.0f - verticalPercentageShown;
                            }
                            adjustedVelocity.y = verticalPercentageShown > 0.5f ? 1.0f : -1.0f;
                            break;
                        }
                        case SCStackViewControllerPositionLeft:
                        case SCStackViewControllerPositionRight:
                        {
                            CGFloat horizontalPercentageShown = ABS((ABS(frame.origin.x) - ABS(adjustedOffset.x))) / CGRectGetWidth(frame);
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
                
                // Calculate the next step of the pagination (either a navigationStep or a controller edge)
                CGPoint nextStepOffset = [self nextStepOffsetForViewController:viewController
                                                                      position:position
                                                                      velocity:adjustedVelocity
                                                                      reversed:isReversed
                                                                 contentOffset:*targetContentOffset];
                
                *targetContentOffset = nextStepOffset;
                
                *stop = YES;
            }
        }];
        
        if(!keepGoing) {
            break;
        }
    }
    
    // Fix for iOS 5.x pagination
    if(SYSTEM_VERSION_LESS_THAN(@"6.0")) {
        targetContentOffset->y += 0.1f;
        targetContentOffset->x += 0.1f;
    }
}

#pragma mark Shared

- (CGPoint)nextStepOffsetForViewController:(UIViewController *)viewController
                                  position:(SCStackViewControllerPosition)position
                                  velocity:(CGPoint)velocity
                                  reversed:(BOOL)isReversed
                             contentOffset:(CGPoint)contentOffset

{
    
    CGPoint nextStepOffset = CGPointZero;
    
    NSArray *navigationSteps = self.navigationSteps[@([viewController hash])];
    
    CGRect finalFrame = [self.finalFrames[@(viewController.hash)] CGRectValue];
    
    if((velocity.y > 0.0f && position == SCStackViewControllerPositionTop)    || (velocity.x > 0.0f && position == SCStackViewControllerPositionLeft) ||
       (velocity.y < 0.0f && position == SCStackViewControllerPositionBottom) || (velocity.x < 0.0f && position == SCStackViewControllerPositionRight)) {
        navigationSteps = [[navigationSteps reverseObjectEnumerator] allObjects];
    }
    
    for(SCStackNavigationStep *nextStep in navigationSteps) {
        
        if(position == SCStackViewControllerPositionTop) {
            if(isReversed) {
                nextStepOffset.y = [self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame) + CGRectGetHeight(finalFrame) * (1.0f - nextStep.percentage);
            } else {
                nextStepOffset.y = CGRectGetMaxY(finalFrame) - CGRectGetHeight(finalFrame) * nextStep.percentage;
            }
        } else if(position == SCStackViewControllerPositionLeft) {
            if(isReversed) {
                nextStepOffset.x = [self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame) + CGRectGetWidth(finalFrame) * (1.0f - nextStep.percentage);
            } else {
                nextStepOffset.x = CGRectGetMaxX(finalFrame) - CGRectGetWidth(finalFrame) * nextStep.percentage;
            }
        } else if(position == SCStackViewControllerPositionBottom) {
            if(isReversed) {
                nextStepOffset.y = [self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame) + CGRectGetHeight(finalFrame) * nextStep.percentage + CGRectGetHeight(self.view.bounds);
            } else {
                nextStepOffset.y = CGRectGetMinY(finalFrame) + CGRectGetHeight(finalFrame) * nextStep.percentage - CGRectGetHeight(self.view.bounds);
            }
        } else if(position == SCStackViewControllerPositionRight) {
            if(isReversed) {
                nextStepOffset.x = [self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame) + CGRectGetWidth(finalFrame) * nextStep.percentage + CGRectGetWidth(self.view.bounds);
            } else {
                nextStepOffset.x = CGRectGetMinX(finalFrame) + CGRectGetWidth(finalFrame) * nextStep.percentage - CGRectGetWidth(self.view.bounds);
            }
        }
        
        if((velocity.y > 0.0f && nextStepOffset.y > contentOffset.y) || (velocity.y < 0.0f && nextStepOffset.y < contentOffset.y) ||
           (velocity.x > 0.0f && nextStepOffset.x > contentOffset.x) || (velocity.x < 0.0f && nextStepOffset.x < contentOffset.x)) {
            return nextStepOffset;
        }
    }
    
    // If no navigation step is found use the view controller's bounds
    if(velocity.y > 0.0f && isReversed) {
        nextStepOffset.y = [self maximumInsetForPosition:position].y - CGRectGetMinY(finalFrame);
    } else if(velocity.x > 0.0f && isReversed) {
        nextStepOffset.x = [self maximumInsetForPosition:position].x - CGRectGetMinX(finalFrame);
    }
    
    else if(velocity.y < 0.0f && isReversed) {
        nextStepOffset.y = [self maximumInsetForPosition:position].y - CGRectGetMaxY(finalFrame);
    } else if(velocity.x < 0.0f && isReversed) {
        nextStepOffset.x = [self maximumInsetForPosition:position].x - CGRectGetMaxX(finalFrame);
    }
    
    else if(velocity.y > 0.0f && !isReversed) {
        nextStepOffset.y = CGRectGetMaxY(finalFrame);
    } else if(velocity.x > 0.0f && !isReversed) {
        nextStepOffset.x = CGRectGetMaxX(finalFrame);
    }
    
    else if(velocity.y < 0.0f && !isReversed) {
        nextStepOffset.y = CGRectGetMinY(finalFrame);
    }
    else if(velocity.x < 0.0f && !isReversed) {
        nextStepOffset.x = CGRectGetMinX(finalFrame);
    }
    
    if(position == SCStackViewControllerPositionBottom) {
        nextStepOffset.y = nextStepOffset.y + (isReversed ? CGRectGetHeight(self.view.bounds) : -CGRectGetHeight(self.view.bounds));
    }
    
    if(position == SCStackViewControllerPositionRight) {
        nextStepOffset.x = nextStepOffset.x + (isReversed ? CGRectGetWidth(self.view.bounds) : -CGRectGetWidth(self.view.bounds));
    }
    
    return nextStepOffset;
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
    [self updateBoundsUsingNavigationContraints];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self updateBoundsUsingNavigationContraints];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if(decelerate == NO) {
        [self updateBoundsUsingNavigationContraints];
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
        [self updateContentSizeIgnoringNavigationContraints];
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
    
    float chopAmount = (edge == CGRectMinXEdge || edge == CGRectMaxXEdge) ? CGRectGetWidth(intersection) : CGRectGetHeight(intersection);
    
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
    return CGRectGetWidth(self.view.bounds);
}

- (CGFloat)viewHeight
{
    return CGRectGetHeight(self.view.bounds);
}

@end
