//
//  UIView+Shadows.h
//  SCStackViewController
//
//  Created by Stefan Ceriu on 16/08/2013.
//  Copyright (c) 2013 Stefan Ceriu. All rights reserved.
//

typedef enum {
    SCShadowEdgeNone   = 0,
    SCShadowEdgeTop    = 1 << 0,
    SCShadowEdgeLeft   = 1 << 1,
    SCShadowEdgeBottom = 1 << 2,
    SCShadowEdgeRight  = 1 << 3,
    SCShadowEdgeAll    = SCShadowEdgeTop | SCShadowEdgeLeft | SCShadowEdgeBottom | SCShadowEdgeRight
} SCShadowEdge;

@interface UIView (Shadows)

- (void)castShadowWithPosition:(SCShadowEdge)edge;

@end
