//
//  SCStackViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCStackViewController.h"
#import "SCStackLayouterProtocol.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

static const CGFloat kDefaultAnimationDuration = 0.25f;

@interface SCStackScrollView : UIScrollView <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIBezierPath *touchRefusalArea;

@end

@implementation SCStackScrollView

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        CGPoint touchPoint = [touch locationInView:self];
        return ![self.touchRefusalArea containsPoint:touchPoint];
    }
    
    return YES;
}

@end

@interface SCStackViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIViewController *rootViewController;

@property (nonatomic, strong) SCStackScrollView *scrollView;

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
                completion:(void(^)(BOOL finished))completion
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
    
    BOOL isReversed = NO;
    if([self.layouters[@(position)] respondsToSelector:@selector(isReversed)]) {
        isReversed = [self.layouters[@(position)] isReversed];
    }
    
    if(unfold) {
        [UIView animateWithDuration:(animated ? kDefaultAnimationDuration : 0.0f)
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [self.scrollView setContentOffset:[self offsetForPosition:position] animated:(isReversed ? NO : animated)];
                         } completion:completion];
    } else if(completion) {
        completion(YES);
    }
}

- (void)popViewControllerAtPosition:(SCStackViewControllerPosition)position
                           animated:(BOOL)animated
                         completion:(void(^)(BOOL finished))completion
{
    UIViewController *lastViewController = [self.viewControllers[@(position)] lastObject];
    [self.viewControllers[@(position)] removeObject:lastViewController];
    [self updateFinalFramesForPosition:position];
    
    [UIView animateWithDuration:(animated ? kDefaultAnimationDuration : 0.0f)
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self scrollViewDidScroll:self.scrollView];
                         [self updateBounds];
                     } completion:^(BOOL finished) {
                         
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
                             completion(finished);
                         }
                     }];
}

- (void)popToRootViewControllerFromPosition:(SCStackViewControllerPosition)position
                                   animated:(BOOL)animated
                                 completion:(void(^)(BOOL finished))completion
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
                      completion:(void(^)(BOOL finished))completion;
{
    CGRect finalFrame = [[self.finalFrames objectForKey:@(viewController.hash)] CGRectValue];
    [self.scrollView setContentOffset:finalFrame.origin animated:YES];
    
    
    SCStackViewControllerPosition controllerPosition = -1;
    for(SCStackViewControllerPosition position = SCStackViewControllerPositionTop; position <=SCStackViewControllerPositionRight; position++) {
        
        if([self.viewControllers[@(position)] containsObject:viewController]) {
            controllerPosition = position;
        }
    }
    
    CGPoint offset = CGPointZero;
    switch (controllerPosition) {
        case SCStackViewControllerPositionTop:
            offset.y = CGRectGetMinY(finalFrame);
            break;
        case SCStackViewControllerPositionLeft:
            offset.x = CGRectGetMinX(finalFrame);
            break;
        case SCStackViewControllerPositionBottom:
            offset.y = CGRectGetMaxY(finalFrame) - CGRectGetHeight(self.view.bounds);
            break;
        case SCStackViewControllerPositionRight:
            offset.x = CGRectGetMaxX(finalFrame) - CGRectGetWidth(self.view.bounds);
            break;
        default:
            break;
    }
    
    [UIView animateWithDuration:(animated ? kDefaultAnimationDuration : 0.0f)
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.scrollView setContentOffset:offset animated:animated];
                     } completion:completion];
}

- (NSArray *)viewControllersForPosition:(SCStackViewControllerPosition)position
{
    return [self.viewControllers[@(position)] copy];
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
    
    self.scrollView = [[SCStackScrollView alloc] initWithFrame:self.view.bounds];
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
int lastIndex = 0;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Mimic lifecycle on rootView
    int index = (int)roundf(self.scrollView.contentOffset.x/320);
    if(index != lastIndex){
        if(index == 0){
            [self.rootViewController viewWillAppear:YES];
        }else{
            [self.rootViewController viewWillDisappear:YES];
        }
        lastIndex = index;
    }
    
    if([self.rootViewController respondsToSelector:@selector(stackviewDidScrollInScrollView:)]){
        [self.rootViewController performSelector:@selector(stackviewDidScrollInScrollView:) withObject:self.scrollView];
    }
    
    for(int position=SCStackViewControllerPositionTop; position<=SCStackViewControllerPositionRight; position++) {
        
        NSArray *viewControllersArray = self.viewControllers[@(position)];
        
        [viewControllersArray enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index, BOOL *stop) {
            
            
            if([viewController respondsToSelector:@selector(stackviewDidScrollInScrollView:)]){
                [viewController performSelector:@selector(stackviewDidScrollInScrollView:) withObject:self.scrollView];
            }
            
            
            CGRect finalFrame = [self.finalFrames[@(viewController.hash)] CGRectValue];
            CGRect frame =  [self.layouters[@(position)] currentFrameForViewController:viewController
                                                                             withIndex:index
                                                                            atPosition:position
                                                                            finalFrame:finalFrame
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
            
            if(self.fadeViewsArrival){
                // Fade views arrival
                CGFloat alpha = 1-(ABS(finalFrame.origin.x) - ABS(scrollView.contentOffset.x))/(finalFrame.size.width);
                viewController.view.alpha = alpha;
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
