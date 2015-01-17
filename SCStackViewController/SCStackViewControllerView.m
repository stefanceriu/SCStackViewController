//
//  SCStackViewControllerView.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 17/01/2015.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCStackViewControllerView.h"

@implementation SCStackViewControllerView

- (void)setFrame:(CGRect)frame
{
	[self.delegate stackViewControllerViewWillChangeFrame:self];
	
	super.frame = frame;
	
	[self.delegate stackViewControllerViewDidChangeFrame:self];
}

@end
