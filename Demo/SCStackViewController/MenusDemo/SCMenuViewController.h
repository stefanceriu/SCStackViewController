//
//  SCMenuViewController.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 08/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCStackViewController.h"
#import "SCStackedViewControllerProtocol.h"

@interface SCMenuViewController : UIViewController <SCStackedViewControllerProtocol>

- (instancetype)initWithPosition:(SCStackViewControllerPosition)position;

@end
