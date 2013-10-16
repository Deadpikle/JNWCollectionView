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

@interface GridCell()
@property (nonatomic, strong) JNWLabel *label;
@end

@implementation GridCell

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if (self == nil) return nil;
	
	self.label = [[JNWLabel alloc] initWithFrame:self.bounds];
	self.label.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self addSubview:self.label];
	
	return self;
}

- (void)setLabelText:(NSString *)labelText {
	_labelText = labelText;
	self.label.text = labelText;
}

- (void)setImage:(NSImage *)image {
	_image = image;
	self.backgroundImage = image;
}

- (void)setSelected:(BOOL)selected {
	[super setSelected:selected];
	[self updateBackgroundImage];
}

- (void)updateBackgroundImage {
	NSImage *image = nil;
	
	if (self.selected) {
		NSString *identifier = [NSString stringWithFormat:@"%@%x", NSStringFromClass(self.class), self.selected];
		CGSize size = CGSizeMake(1, CGRectGetHeight(self.bounds));
		image = [DemoImageCache.sharedCache cachedImageWithIdentifier:identifier size:size withCreationBlock:^NSImage * (CGSize size) {
			return [NSImage highlightedGradientImageWithHeight:size.height];
		}];
	} else {
		image = self.image;
	}
	
	if (self.backgroundImage != image) {
		self.backgroundImage = image;
	}
}

@end
