//
//  GridCell.m
//  JNWCollectionViewDemo
//
//  Created by Jonathan Willing on 4/15/13.
//  Copyright (c) 2013 AppJon. All rights reserved.
//

#import "GridCell.h"
#import "JNWLabel.h"
#import "NSImage+DemoAdditions.h"
#import "DemoImageCache.h"

@implementation GridCell

- (void)setImage:(NSImage *)image {
	_image = image;
	self.backgroundImage = image;
}

- (void)setSelected:(BOOL)selected {
	[super setSelected:selected];
	[self updateBackgroundImage];
}

- (void)updateBackgroundImage {
	if (self.selected) {
        [[self layer] setBorderColor:[[NSColor redColor] CGColor]];
        [[self layer] setBorderWidth:3.0f];
	} else {
        [[self layer] setBorderColor:[[NSColor clearColor] CGColor]];
        [[self layer] setBorderWidth:0.0f];
	}
}

@end
