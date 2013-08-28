//
//  UIViewController+SCStackViewController.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 16/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "UIViewController+SCStackViewController.h"
#import "SCStackViewController.h"

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
