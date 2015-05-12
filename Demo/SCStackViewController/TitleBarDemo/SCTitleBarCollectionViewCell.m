//
//  SCTitleBarCollectionViewCell.m
//  SCStackViewController
//
//  Created by Stefan Ceriu on 5/12/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import "SCTitleBarCollectionViewCell.h"

@interface SCTitleBarCollectionViewCell ()

@property (nonatomic, weak) IBOutlet UIImageView *imageView;

@end

@implementation SCTitleBarCollectionViewCell

- (void)awakeFromNib
{
	[self.imageView.layer setCornerRadius:10.0f];
}

@end
