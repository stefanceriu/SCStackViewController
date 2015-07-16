//
//  SCOverlayView.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 23/11/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

#import "SCOverlayView.h"

@implementation SCOverlayView

+ (instancetype)overlayView
{
	SCOverlayView *overlayView = nil;
	NSArray *nibContents = [[UINib nibWithNibName:NSStringFromClass([self class]) bundle:nil] instantiateWithOwner:nil options:nil];
	if(nibContents.count > 0) {
		overlayView = (SCOverlayView *)[nibContents objectAtIndex:0];
	}
	return overlayView;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
	[self addGestureRecognizer:tapGesture];
}

- (void)onTap:(UITapGestureRecognizer *)sender
{
	if([self.delegate respondsToSelector:@selector(overlayViewDidReceiveTap:)]) {
		[self.delegate overlayViewDidReceiveTap:self];
	}
}

@end
