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
    [viewControllers enumerateObjectsUsingBlock:^(UIViewController *x, NSUInteger idx, BOOL *stop) {
        CGRect finalFrame = [self.layouters[@(position)] finalFrameForViewController:x
                                                                           withIndex:idx
                                                                          atPosition:position
                                                                         withinGroup:viewControllers
                                                                   inStackController:self];
        
        [self.finalFrames setObject:[NSValue valueWithCGRect:finalFrame] forKey:@([x hash])];
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
        
        NSArray *viewControllersArray = self.viewControllers[@(position)];
        [viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index, BOOL *stop) {
            CGRect frame =  [self.layouters[@(position)] currentFrameForViewController:viewController
                                                                             withIndex:index
                                                                            atPosition:position
                                                                            finalFrame:[self.finalFrames[@(viewController.hash)] CGRectValue]
                                                                         contentOffset:scrollView.contentOffset
                                                                     inStackController:self];
            
            CGRect intersection = CGRectIntersection(self.scrollView.bounds, frame);
            __block BOOL visible = YES;
            [viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *obj, NSUInteger idx, BOOL *stop) {
                if(CGRectContainsRect(obj.view.frame, intersection) && ![viewController isEqual:obj]) {
                    visible = NO;
                    *stop = YES;
                }
            }];
            
            if(CGRectContainsRect(self.rootViewController.view.frame, intersection)) {
                visible = NO;
            }
            
            if(visible && ![self.visibleViewControllers containsObject:viewController]) {
                [self.visibleViewControllers addObject:viewController];
                [viewController beginAppearanceTransition:YES animated:NO];
                [viewController.view setFrame:frame];
                [viewController endAppearanceTransition];
            } else if(!visible && [self.visibleViewControllers containsObject:viewController]) {
                [self.visibleViewControllers removeObject:viewController];
                [viewController beginAppearanceTransition:NO animated:NO];
                [viewController.view setFrame:frame];
                [viewController endAppearanceTransition];
            } else {
                [viewController.view setFrame:frame];
            }
        }];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if(CGPointEqualToPoint(velocity, CGPointZero)) {
        return;
    }
    
    CGRect finalFrame = CGRectMake(targetContentOffset->x, targetContentOffset->y, 0, 0);
    for(NSValue *frameValue in self.finalFrames.allValues) {
        
        CGRect frame = [frameValue CGRectValue];
        frame.origin.x = frame.origin.x > 0 ? CGRectGetMinX(frame) - CGRectGetWidth(self.view.bounds) : CGRectGetMinX(frame);
        frame.origin.y = frame.origin.y > 0 ? CGRectGetMinY(frame) - CGRectGetHeight(self.view.bounds) : CGRectGetMinY(frame);
        
        if(CGRectContainsPoint(frame, *targetContentOffset)) {
            finalFrame = frame;
            break;
        }
    }
    
    CGFloat iOS5Adjustment = 0.0f;
    if(SYSTEM_VERSION_LESS_THAN(@"6.0")) {
        iOS5Adjustment = 0.1f;
    }
    
    if(velocity.x || velocity.y == 0) {
        if (velocity.x >= 0.0) {
            targetContentOffset->x = CGRectGetMaxX(finalFrame) - iOS5Adjustment;
        }
        else if (velocity.x < -0.1) {
            targetContentOffset->x = CGRectGetMinX(finalFrame) + iOS5Adjustment;
        }
    } else {
        if (velocity.y >= 0.0) {
            targetContentOffset->y = CGRectGetMaxY(finalFrame) - iOS5Adjustment;
        }
        else if (velocity.y < -0.1) {
            targetContentOffset->y = CGRectGetMinY(finalFrame) + iOS5Adjustment;
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

@end
