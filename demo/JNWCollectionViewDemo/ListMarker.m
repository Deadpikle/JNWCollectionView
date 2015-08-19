//
//  ListMarker.m
//  JNWCollectionViewDemo
//
//  Created by Marc Haisenko on 09.10.13.
//  Copyright (c) 2013 AppJon. All rights reserved.
//
// Drag and drop implementation modified from https://github.com/DarkDust/JNWCollectionView (MIT licensed)


#import "ListMarker.h"

@implementation ListMarker

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor blueColor] set];
    NSRectFill(dirtyRect);
}

@end
