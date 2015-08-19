/*
 Copyright (c) 2013, Jonathan Willing. All rights reserved.
 Licensed under the MIT license <http://opensource.org/licenses/MIT>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 documentation files (the "Software"), to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
 to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions
 of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
 TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 IN THE SOFTWARE.
 */

#import "JNWCollectionViewLayout.h"
#import "JNWCollectionView+Private.h"
#import "JNWCollectionViewLayout+Private.h"

@implementation JNWCollectionViewLayoutAttributes

@end

@implementation JNWCollectionViewLayout

- (instancetype)init {
    self = [super init];
    if (self == nil) return nil;
    
    self.shouldAutoScroll = NO;
    CGFloat defaultThreshold = 25.0f;
    self.leftAutoScrollThreshold = defaultThreshold;
    self.rightAutoScrollThreshold = defaultThreshold;
    self.upAutoScrollThreshold = defaultThreshold;
    self.downAutoScrollThreshold = defaultThreshold;
    
    CGFloat defaultAutoScrollAmount = 10.0f;
    self.leftAutoScrollAmount = defaultAutoScrollAmount;
    self.rightAutoScrollAmount = defaultAutoScrollAmount;
    self.upAutoScrollAmount = defaultAutoScrollAmount;
    self.downAutoScrollAmount = defaultAutoScrollAmount;
    
    return self;
}

- (void)invalidateLayout {
	// Forward this onto the collection view itself.
	[self.collectionView collectionViewLayoutWasInvalidated:self];
}

- (void)prepareLayout {
	// For subclasses
}

- (instancetype)initWithCollectionView:(JNWCollectionView *)collectionView {
	return [super init];
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
	return nil;
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryItemInSection:(NSInteger)section kind:(NSString *)kind {
	return nil;
}

- (NSArray *)indexPathsForItemsInRect:(CGRect)rect {
	return nil;
}

- (CGRect)rectForSectionAtIndex:(NSInteger)index {
	return CGRectNull;
}

- (CGSize)contentSize {
	return CGSizeZero;
}

- (JNWCollectionViewScrollDirection)scrollDirection {
	return JNWCollectionViewScrollDirectionVertical;
}

- (NSIndexPath *)indexPathForNextItemInDirection:(JNWCollectionViewDirection)direction currentIndexPath:(NSIndexPath *)currentIndexPath {
	return currentIndexPath;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
	return YES;
}

- (BOOL)shouldApplyExistingLayoutAttributesOnLayout {
	return YES;
}

#pragma mark Drag and Drop

- (JNWCollectionViewDropIndexPath *)dropIndexPathAtPoint:(NSPoint)point {
    return nil;
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForDropMarker {
    return nil;
}

- (BOOL)scrollIfNecessaryForDragAtPoint:(CGPoint)point {
    if (self.shouldAutoScroll && self.collectionView) {
        CGRect bounds = self.collectionView.contentView.bounds;
        if (CGRectContainsPoint(bounds, NSPointToCGPoint(point))) {
            NSClipView *clipView = [self.collectionView contentView];
            NSPoint newOrigin = [clipView bounds].origin;
            // Now check to see if we're within the bounds of the scroll
            if ((bounds.origin.x + bounds.size.width) - point.x < self.rightAutoScrollThreshold) {
                // scroll right
                newOrigin.x += _rightAutoScrollAmount;
            } else if (point.x - bounds.origin.x < self.leftAutoScrollThreshold) {
                // scroll left
                newOrigin.x -= self.leftAutoScrollAmount;
            }
            if ((bounds.origin.y + bounds.size.height) - point.y < self.downAutoScrollThreshold) {
                // scroll down
                newOrigin.y += self.downAutoScrollAmount;
            } else if (point.y - bounds.origin.y < self.upAutoScrollThreshold) {
                // scroll up
                newOrigin.y -= self.upAutoScrollAmount;
            }
            [clipView setBoundsOrigin:newOrigin];
        }
    }
    return NO;
}

@end
