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

#import "JNWCollectionViewListLayout.h"

typedef struct {
	CGFloat height;
	CGFloat yOffset;
} JNWCollectionViewListLayoutRowInfo;

typedef NS_ENUM(NSInteger, JNWListEdge) {
	JNWListEdgeTop,
	JNWListEdgeBottom
};

NSString * const JNWCollectionViewListLayoutHeaderKind = @"JNWCollectionViewListLayoutHeader";
NSString * const JNWCollectionViewListLayoutFooterKind = @"JNWCollectionViewListLayoutFooter";

@interface JNWCollectionViewListLayoutSection : NSObject
- (instancetype)initWithNumberOfRows:(NSInteger)numberOfRows;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) CGFloat offset;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat headerHeight;
@property (nonatomic, assign) CGFloat footerHeight;
@property (nonatomic, assign) NSInteger numberOfRows;
@property (nonatomic, assign) JNWCollectionViewListLayoutRowInfo *rowInfo;
@end

@implementation JNWCollectionViewListLayoutSection

- (instancetype)initWithNumberOfRows:(NSInteger)numberOfRows {
	self = [super init];
	if (self == nil) return nil;
	_numberOfRows = numberOfRows;
	self.rowInfo = calloc(numberOfRows, sizeof(JNWCollectionViewListLayoutRowInfo));
	return self;
}

- (void)dealloc {
	if (_rowInfo != nil)
		free(_rowInfo);
}

@end

@interface JNWCollectionViewListLayout()
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, assign) CGRect lastInvalidatedBounds;
@property (nonatomic, strong) JNWCollectionViewLayoutAttributes *markerAttributes;
@end

@implementation JNWCollectionViewListLayout

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;
	self.rowHeight = 44.f;
	return self;
}

- (NSMutableArray *)sections {
	if (_sections == nil) {
		_sections = [NSMutableArray array];
	}
	return _sections;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    if (newBounds.size.width != self.lastInvalidatedBounds.size.width) {
    	self.lastInvalidatedBounds = newBounds;
    	return YES;
    }
	return NO;
}

- (void)prepareLayout {
	[self.sections removeAllObjects];
	
	if (self.delegate != nil && ![self.delegate conformsToProtocol:@protocol(JNWCollectionViewListLayoutDelegate)]) {
		NSLog(@"*** list delegate does not conform to JNWCollectionViewListLayoutDelegate!");
	}
	
	BOOL delegateHeightForRow = [self.delegate respondsToSelector:@selector(collectionView:heightForRowAtIndexPath:)];
	BOOL delegateHeightForHeader = [self.delegate respondsToSelector:@selector(collectionView:heightForHeaderInSection:)];
	BOOL delegateHeightForFooter = [self.delegate respondsToSelector:@selector(collectionView:heightForFooterInSection:)];
	JNWCollectionView *collectionView = self.collectionView;
	
	NSUInteger numberOfSections = [self.collectionView numberOfSections];
	CGFloat totalHeight = 0;
	CGFloat verticalSpacing = self.verticalSpacing;
	
	for (NSUInteger section = 0; section < numberOfSections; section++) {
		NSInteger numberOfRows = [collectionView numberOfItemsInSection:section];
		NSInteger headerHeight = delegateHeightForHeader ? [self.delegate collectionView:collectionView heightForHeaderInSection:section] : 0;
		NSInteger footerHeight = delegateHeightForFooter ? [self.delegate collectionView:collectionView heightForFooterInSection:section] : 0;
		
		JNWCollectionViewListLayoutSection *sectionInfo = [[JNWCollectionViewListLayoutSection alloc] initWithNumberOfRows:numberOfRows];
		sectionInfo.offset = totalHeight;
		sectionInfo.height = 0;
		sectionInfo.headerHeight = headerHeight;
		sectionInfo.footerHeight = footerHeight;
		sectionInfo.index = section;
		
		sectionInfo.height += headerHeight; // the footer height is added after cells have determined their offsets
		
		for (NSInteger row = 0; row < numberOfRows; row++) {
			CGFloat rowHeight = self.rowHeight;
			NSIndexPath *indexPath = [NSIndexPath jnw_indexPathForItem:row inSection:section];
			if (delegateHeightForRow)
				rowHeight = [self.delegate collectionView:collectionView heightForRowAtIndexPath:indexPath];
			
			sectionInfo.rowInfo[row].height = rowHeight;
			sectionInfo.rowInfo[row].yOffset = sectionInfo.height;
			sectionInfo.height += rowHeight;
			sectionInfo.height += verticalSpacing;
		}
		
		sectionInfo.height -= verticalSpacing; // We don't want spacing after the last cell.
		
		sectionInfo.height += footerHeight;
		sectionInfo.frame = CGRectMake(0, sectionInfo.offset, collectionView.visibleSize.width, sectionInfo.height);
		
		totalHeight += sectionInfo.height;
		[self.sections addObject:sectionInfo];
	}
    
    if (self.collectionView.dragContext.dropPath) {
        JNWCollectionViewDropIndexPath *indexPath = self.collectionView.dragContext.dropPath;
        JNWCollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
        CGRect frame = attributes.frame;
        if (indexPath.jnw_relation == JNWCollectionViewDropRelationAfter) {
			frame.origin.y += frame.size.height;
			NSInteger numberOfRowsForFinalSection = [collectionView numberOfItemsInSection:self.sections.count - 1];
			// If not dragging to the very last item in the very last section, account for vertical spacing
			if (indexPath.jnw_section != self.sections.count - 1 || indexPath.jnw_item != numberOfRowsForFinalSection - 1) {
				frame.origin.y += (self.verticalSpacing / 2);
			}
		}
		else {
			// If not dragging to before the first item, take out vertical spacing
			if (indexPath.jnw_section != 0 || indexPath.jnw_item != 0)
				frame.origin.y -= (self.verticalSpacing / 2);
		}
		frame.size.height = 2;
        attributes.frame = frame;
        self.markerAttributes = attributes;
    } else {
        self.markerAttributes = nil;
    }
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
	JNWCollectionViewLayoutAttributes *attributes = [[JNWCollectionViewLayoutAttributes alloc] init];
	attributes.frame = [self rectForItemAtIndex:indexPath.jnw_item section:indexPath.jnw_section];
	attributes.alpha = 1.f;
	return attributes;
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryItemInSection:(NSInteger)sectionIdx kind:(NSString *)kind {
	JNWCollectionViewListLayoutSection *section = self.sections[sectionIdx];
	CGFloat width = self.collectionView.visibleSize.width;
	CGRect frame = CGRectZero;
	
	if ([kind isEqualToString:JNWCollectionViewListLayoutHeaderKind]) {
		frame = CGRectMake(0, section.offset, width, section.headerHeight);
		
		if (self.stickyHeaders) {
			// Thanks to http://blog.radi.ws/post/32905838158/sticky-headers-for-uicollectionview-using for the inspiration.
			CGPoint contentOffset = self.collectionView.documentVisibleRect.origin;
			CGPoint nextHeaderOrigin = CGPointMake(FLT_MAX, FLT_MAX);
			
			if (sectionIdx + 1 < self.sections.count) {
				JNWCollectionViewLayoutAttributes *nextHeaderAttributes = [self layoutAttributesForSupplementaryItemInSection:sectionIdx + 1 kind:kind];
				nextHeaderOrigin = nextHeaderAttributes.frame.origin;
			}
			
			frame.origin.y = MIN(MAX(contentOffset.y, frame.origin.y), nextHeaderOrigin.y - CGRectGetHeight(frame));
		}
	} else if ([kind isEqualToString:JNWCollectionViewListLayoutFooterKind]) {
		frame = CGRectMake(0, section.offset + section.height - section.footerHeight, width, section.footerHeight);
	}
	
	JNWCollectionViewLayoutAttributes *attributes = [[JNWCollectionViewLayoutAttributes alloc] init];
	attributes.frame = frame;
	attributes.alpha = 1.f;
	attributes.zIndex = NSIntegerMax;
	return attributes;
}

- (BOOL)shouldApplyExistingLayoutAttributesOnLayout {
	return self.stickyHeaders;
}

- (CGRect)rectForItemAtIndex:(NSInteger)index section:(NSInteger)section {
	JNWCollectionViewListLayoutSection *sectionInfo = self.sections[section];
	CGFloat offset = sectionInfo.offset + sectionInfo.rowInfo[index].yOffset;
	CGFloat width = self.collectionView.visibleSize.width;
	CGFloat height = sectionInfo.rowInfo[index].height;
	return CGRectMake(0, offset, width, height);
}

- (CGRect)rectForSectionAtIndex:(NSInteger)index {
	JNWCollectionViewListLayoutSection *section = self.sections[index];
	return section.frame;
}

- (NSArray *)indexPathsForItemsInRect:(CGRect)rect {
	NSMutableArray *indexPaths = [NSMutableArray array];
	
	for (JNWCollectionViewListLayoutSection *section in self.sections) {
		if (section.numberOfRows > 0 && CGRectIntersectsRect(section.frame, rect)) {
			
			// Since this is a linear set of data, we run a binary search for optimization
			// purposes, finding the rects of the upper and lower bound.
			NSInteger upperRow = [self nearestIntersectingRowInSection:section inRect:rect edge:JNWListEdgeTop];
			NSInteger lowerRow = [self nearestIntersectingRowInSection:section inRect:rect edge:JNWListEdgeBottom];
			
			for (NSInteger item = upperRow; item <= lowerRow; item++) {
				[indexPaths addObject:[NSIndexPath jnw_indexPathForItem:item inSection:section.index]];
			}
		}
	}
				 
	return indexPaths;
}

- (NSInteger)nearestIntersectingRowInSection:(JNWCollectionViewListLayoutSection *)section inRect:(CGRect)containingRect edge:(JNWListEdge)edge {
	NSInteger low = 0;
	NSInteger high = section.numberOfRows - 1;
	NSInteger mid = 0;
	
	CGFloat absoluteOffset = (edge == JNWListEdgeTop ? containingRect.origin.y : containingRect.origin.y + containingRect.size.height);
	CGFloat relativeOffset = absoluteOffset - section.offset;
	
	while (low <= high) {
		mid = (low + high) / 2;
		JNWCollectionViewListLayoutRowInfo midInfo = section.rowInfo[mid];
		
		if (midInfo.yOffset == relativeOffset) {
			return mid;
		}
		if (midInfo.yOffset > relativeOffset) {
			high = mid - 1;
		}
		if (midInfo.yOffset < relativeOffset) {
			low = mid + 1;
		}
	}
	
	// We haven't found a row that exactly aligns with the rect, which is quite often.
	if (edge == JNWListEdgeTop) {
		// Start from the current top row, and keep decreasing the index so we keep travelling up
		// until we're past the boundaries.
		while (mid > 0 && section.rowInfo[mid].yOffset > relativeOffset) {
			mid--;
		}
		
		return mid;
	} else {
		// Start from the current bottom row and keep increasing the index until we hit the lower boundary
		while (mid < (section.numberOfRows - 1) && section.rowInfo[mid].yOffset + section.rowInfo[mid].height + section.offset < relativeOffset) {
			mid++;
		}
	}
	
	return mid;
}

- (NSIndexPath *)indexPathForNextItemInDirection:(JNWCollectionViewDirection)direction currentIndexPath:(NSIndexPath *)currentIndexPath {
	NSIndexPath *newIndexPath = currentIndexPath;
	
	if (direction == JNWCollectionViewDirectionUp) {
		newIndexPath  = [self.collectionView indexPathForNextSelectableItemBeforeIndexPath:currentIndexPath];
	} else if (direction == JNWCollectionViewDirectionDown) {
		newIndexPath = [self.collectionView indexPathForNextSelectableItemAfterIndexPath:currentIndexPath];
	}
	
	return newIndexPath;
}

#pragma mark Drag and Drop

- (JNWCollectionViewDropIndexPath *)dropIndexPathAtPoint:(NSPoint)point {
    [self scrollIfNecessaryForDragAtPoint:point];
    /*
    for (JNWCollectionViewListLayoutSection *section in self.sections) {
        if (CGRectContainsPoint(section.frame, NSPointToCGPoint(point))) {
            NSUInteger index = [self rowInSection:section containingPoint:NSPointToCGPoint(point)];
            if (index == NSNotFound) {
                return nil;
            } else {
                NSIndexPath *testPath = [NSIndexPath jnw_indexPathForItem:index inSection:section.index];
                if ([self.collectionView.dragContext.dragPaths containsObject:testPath]) {
                    // Don't drop on a dragged item.
                    return nil;
                } else {
                    
                    return [JNWCollectionViewDropIndexPath indexPathForItem:index inSection:section.index dropRelation:JNWCollectionViewDropRelationAt];
                }
            }
        }
    }
     */
    
    NSArray *visibleCells = [self.collectionView visibleCells];
    CGFloat halfVerticalSpacing = self.verticalSpacing * 0.5; // calculate this above loop since it is always constant
    for (JNWCollectionViewCell *cell in visibleCells) {
        // run a basic check to see if the point is within the actual cell's frame without accounting
        // for vertical spacing
        if (CGRectContainsPoint(cell.frame, point)) {
            NSIndexPath *path = cell.indexPath;
            if (path) {
                if (point.y <= cell.frame.origin.y + cell.frame.size.height * 0.5) {
                    return [JNWCollectionViewDropIndexPath indexPathForItem:path.jnw_item inSection:path.jnw_section dropRelation:JNWCollectionViewDropRelationAt];
                } else {
                    return [JNWCollectionViewDropIndexPath indexPathForItem:path.jnw_item inSection:path.jnw_section dropRelation:JNWCollectionViewDropRelationAfter];
                }
            }
        }
        else {
            // We may need to account for vertical spacing to know which cell is being dropped on
            CGRect rectWithSpacing = cell.frame;
            // see if the drag operation is "between" cells by being "below" the cell
            rectWithSpacing.size.height += halfVerticalSpacing;
            if (CGRectContainsPoint(rectWithSpacing, point)) {
                return [JNWCollectionViewDropIndexPath indexPathForItem:cell.indexPath.jnw_item inSection:cell.indexPath.jnw_section dropRelation:JNWCollectionViewDropRelationAfter];
            }
            if (cell.indexPath.jnw_item != 0) {
                // see if the drag operation is "between" cells by being "above" the cell
                // (cell 0 can't have an "above" the cell since it is at the top and the verticalSpacing doesn't account for this)
                rectWithSpacing.origin.y -= halfVerticalSpacing;
                if (CGRectContainsPoint(rectWithSpacing, point)) {
                    return [JNWCollectionViewDropIndexPath indexPathForItem:cell.indexPath.jnw_item inSection:cell.indexPath.jnw_section dropRelation:JNWCollectionViewDropRelationAt];
                }
            }
        }
    }
    
    return nil;
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForDropMarker {
    return self.markerAttributes;
}

- (NSUInteger)rowInSection:(JNWCollectionViewListLayoutSection *)section containingPoint:(CGPoint)point {
    NSUInteger numberOfRows = section.numberOfRows;
    NSUInteger low = 0;
    NSUInteger high = (numberOfRows > 0) ? numberOfRows - 1 : 0;
    NSUInteger mid;
    
    CGFloat relativeOffset = point.y - section.offset;
    
    while (low <= high) {
        mid = (low + high) / 2;
        JNWCollectionViewListLayoutRowInfo midInfo = section.rowInfo[mid];
        
        if (midInfo.yOffset <= relativeOffset && (midInfo.yOffset + midInfo.height) >= relativeOffset) {
            return mid;
        } else if (midInfo.yOffset > relativeOffset && mid > 0) {
            high = mid - 1;
        } else if (midInfo.yOffset < relativeOffset && mid < numberOfRows) {
            low = mid + 1;
        } else {
            break;
        }
    }
    
    return NSNotFound;
}


@end
