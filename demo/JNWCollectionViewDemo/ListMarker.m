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

- (instancetype)init {
    self = [super init];
    if (self)
        self.color = [NSColor blueColor];
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self)
        self.color = [NSColor blueColor];
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [self.color set];
    NSRectFill(dirtyRect);
}

@end
