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

#import "JNWCollectionViewGridLayout.h"

typedef struct {
	CGPoint origin;
} JNWCollectionViewGridLayoutItemInfo;

NSString * const JNWCollectionViewGridLayoutHeaderKind = @"JNWCollectionViewGridLayoutHeader";
NSString * const JNWCollectionViewGridLayoutFooterKind = @"JNWCollectionViewGridLayoutFooter";

@interface JNWCollectionViewGridLayout()
@property (nonatomic, assign) CGRect lastInvalidatedBounds;
@end

@interface JNWCollectionViewGridLayoutSection : NSObject
- (instancetype)initWithNumberOfItems:(NSInteger)numberOfItems;
@property (nonatomic, assign) CGFloat offset;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat headerHeight;
@property (nonatomic, assign) CGFloat footerHeight;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) NSInteger numberOfItems;
@property (nonatomic, assign) JNWCollectionViewGridLayoutItemInfo *itemInfo;
@end

@implementation JNWCollectionViewGridLayoutSection

- (instancetype)initWithNumberOfItems:(NSInteger)numberOfItems {
	self = [super init];
	if (self == nil) return nil;
	_numberOfItems = numberOfItems;
	self.itemInfo = calloc(numberOfItems, sizeof(JNWCollectionViewGridLayoutItemInfo));
	return self;
}

- (void)dealloc {
	if (_itemInfo != NULL)
		free(_itemInfo);
}

@end

static const CGSize JNWCollectionViewGridLayoutDefaultSize = (CGSize){ 44.f, 44.f };

@interface JNWCollectionViewGridLayout()
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic) NSArray<NSNumber*> *numberOfColumnsList; // NSUInteger
@property (nonatomic) NSArray<NSNumber*> *itemPaddingList; // CGFloat
@property (nonatomic, strong) JNWCollectionViewLayoutAttributes *markerAttributes;
@end

@implementation JNWCollectionViewGridLayout

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;
    self.itemSizes = @[[NSValue valueWithSize:JNWCollectionViewGridLayoutDefaultSize]];
	self.itemPaddingEnabled = YES;
;
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

- (void)setItemSize:(CGSize)itemSize {
    self.itemSizes = @[[NSValue valueWithSize:itemSize]];
}

- (CGSize)itemSize {
    if (self.itemSizes && self.itemSizes.count) {
        return [self.itemSizes[0] sizeValue];
    }
    return JNWCollectionViewGridLayoutDefaultSize;
}

- (void)prepareLayout {
	[self.sections removeAllObjects];

	if (self.delegate != nil && ![self.delegate conformsToProtocol:@protocol(JNWCollectionViewGridLayoutDelegate)]) {
		NSLog(@"*** grid delegate does not conform to JNWCollectionViewGridLayoutDelegate!");
	}
    
    NSUInteger numberOfSections = [self.collectionView numberOfSections];
    CGFloat totalWidth = self.collectionView.visibleSize.width - self.itemHorizontalMargin;
    
    if ([self.delegate respondsToSelector:@selector(sizeForItemInCollectionView:forSection:)]) {
        NSMutableArray *allSizes = [NSMutableArray array];
        NSMutableArray *allColumnNumbers = [NSMutableArray array];
        NSMutableArray *addItemPaddings = [NSMutableArray array];
        for (NSUInteger i = 0; i < numberOfSections; i++) {
            CGSize size = [self.delegate sizeForItemInCollectionView:self.collectionView forSection:i];
            [allSizes addObject:[NSValue valueWithSize:size]];
            // calc # of columns
            NSUInteger numberOfColumns = totalWidth / (size.width + self.itemHorizontalMargin);
            if (numberOfColumns == 0) {
                numberOfColumns = 1;
            }
            [allColumnNumbers addObject:[NSNumber numberWithUnsignedInteger:numberOfColumns]];
            // calc item padding
            if (self.itemHorizontalMargin == 0 && self.itemPaddingEnabled) {
                CGFloat totalPadding = totalWidth - (numberOfColumns * size.width);
                if (totalPadding < 0) {
                    totalPadding = 0;
                }
                totalPadding = floorf(totalPadding / (numberOfColumns + 1));
                [addItemPaddings addObject:[NSNumber numberWithFloat:totalPadding]];
            } else {
                [addItemPaddings addObject:[NSNumber numberWithFloat:self.itemHorizontalMargin]];
            }
            
        }
        self.itemSizes = allSizes;
        self.numberOfColumnsList = allColumnNumbers;
        self.itemPaddingList = addItemPaddings;
    }
    else {
        CGSize itemSize = JNWCollectionViewGridLayoutDefaultSize;
        if ([self.delegate respondsToSelector:@selector(sizeForItemInCollectionView:)]) {
            itemSize = [self.delegate sizeForItemInCollectionView:self.collectionView];
        }
        else if (self.itemSize.width != itemSize.width || self.itemSize.height != itemSize.height) {
            itemSize = self.itemSize;
        }
        NSUInteger numberOfColumns = totalWidth / (itemSize.width + self.itemHorizontalMargin);
        if (numberOfColumns == 0) {
            numberOfColumns = 1;
        }
        CGFloat padding = self.itemHorizontalMargin;
        if (self.itemHorizontalMargin == 0 && self.itemPaddingEnabled) {
            padding = totalWidth - (numberOfColumns * itemSize.width);
            if (padding < 0) {
                padding = 0;
            }
            padding = floorf(padding / (numberOfColumns + 1));
        }
        NSMutableArray *allSizes = [NSMutableArray array];
        NSMutableArray *allColumnNumbers = [NSMutableArray array];
        NSMutableArray *addItemPaddings = [NSMutableArray array];
        for (NSUInteger i = 0; i < numberOfSections; i++) {
            [allSizes addObject:[NSValue valueWithSize:itemSize]];
            [allColumnNumbers addObject:[NSNumber numberWithUnsignedInteger:numberOfColumns]];
            [addItemPaddings addObject:[NSNumber numberWithUnsignedInteger:padding]];
        }
        self.itemSizes = allSizes;
        self.numberOfColumnsList = allColumnNumbers;
        self.itemPaddingList = addItemPaddings;
    }
	
	BOOL delegateHeightForHeader = [self.delegate respondsToSelector:@selector(collectionView:heightForHeaderInSection:)];
	BOOL delegateHeightForFooter = [self.delegate respondsToSelector:@selector(collectionView:heightForFooterInSection:)];
	BOOL delegateForSectionInsets = [self.delegate respondsToSelector:@selector(collectionView:layout:insetForSectionAtIndex:)];
	
    CGFloat verticalSpacing = self.verticalSpacing;
	
	CGFloat totalHeight = 0;
	for (NSUInteger section = 0; section < numberOfSections; section++) {
		NSInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];
		NSInteger headerHeight = delegateHeightForHeader ? [self.delegate collectionView:self.collectionView heightForHeaderInSection:section] : 0;
		NSInteger footerHeight = delegateHeightForFooter ? [self.delegate collectionView:self.collectionView heightForFooterInSection:section] : 0;
		NSEdgeInsets sectionInsets = delegateForSectionInsets ? [self.delegate collectionView:self.collectionView layout:self insetForSectionAtIndex:section] : NSEdgeInsetsMake(0, 0, 0, 0);

		JNWCollectionViewGridLayoutSection *sectionInfo = [[JNWCollectionViewGridLayoutSection alloc] initWithNumberOfItems:numberOfItems];
		sectionInfo.offset = totalHeight + headerHeight + sectionInsets.top;
		sectionInfo.height = 0;
		sectionInfo.index = section;
		sectionInfo.headerHeight = headerHeight;
		sectionInfo.footerHeight = footerHeight;
        
        CGSize itemSize = [self.itemSizes[section] sizeValue];
        NSUInteger numberOfColumns = [self.numberOfColumnsList[section] unsignedIntegerValue];
        CGFloat itemPadding = [self.itemPaddingList[section] floatValue];
		
		for (NSInteger item = 0; item < numberOfItems; item++) {
			CGPoint origin = CGPointZero;
			NSInteger column = ((item - (item % numberOfColumns)) / numberOfColumns);
			origin.x = sectionInsets.left + itemPadding + (item % numberOfColumns) * (itemSize.width + itemPadding);
			origin.y = column * itemSize.height + column * verticalSpacing;
			sectionInfo.itemInfo[item].origin = origin;
		}
		
		NSInteger numberOfRows = ceilf((float)numberOfItems / (float)numberOfColumns);
		
		sectionInfo.height = itemSize.height * numberOfRows + verticalSpacing * MAX(numberOfRows - 1, 0);
		totalHeight += sectionInfo.height + footerHeight + headerHeight + sectionInsets.bottom + sectionInsets.top;
		[self.sections addObject:sectionInfo];
	}
    
    if (self.collectionView.dragContext.dropPath) {
        JNWCollectionViewDropIndexPath *indexPath = self.collectionView.dragContext.dropPath;
        JNWCollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
        CGRect frame = attributes.frame;
        if (indexPath.jnw_relation == JNWCollectionViewDropRelationAfter) {
			frame.origin.x += frame.size.width + 2; // make it appear "after" the dragged-over item
			NSInteger numberOfRowsForFinalSection = [self.collectionView numberOfItemsInSection:self.sections.count - 1];
			// If not dragging to the very last item in the very last section, account for vertical spacing
			if (indexPath.jnw_section != self.sections.count - 1 || indexPath.jnw_item != numberOfRowsForFinalSection - 1) {
				frame.origin.x += (self.itemHorizontalMargin / 2);
			}
        }
		else {
			// If not dragging to before the first item, take out vertical spacing
			if (indexPath.jnw_section != 0 || indexPath.jnw_item != 0)
				frame.origin.x -= (self.itemHorizontalMargin / 2);
		}
        frame.size.width = 2;
        attributes.frame = frame;
        self.markerAttributes = attributes;
    } else {
        self.markerAttributes = nil;
    }
}

- (CGSize)sizeForSection:(NSUInteger)section {
    if (section < self.itemSizes.count) {
        return [self.itemSizes[section] sizeValue];
    }
    else if ([self.delegate respondsToSelector:@selector(sizeForItemInCollectionView:forSection:)]) {
        return [self.delegate sizeForItemInCollectionView:self.collectionView forSection:section];
    }
    return JNWCollectionViewGridLayoutDefaultSize;
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
	JNWCollectionViewGridLayoutSection *section = self.sections[indexPath.jnw_section];
	JNWCollectionViewGridLayoutItemInfo itemInfo = section.itemInfo[indexPath.jnw_item];
	CGFloat offset = section.offset;
	
	JNWCollectionViewLayoutAttributes *attributes = [[JNWCollectionViewLayoutAttributes alloc] init];
    CGSize size = [self sizeForSection:indexPath.jnw_section];
	attributes.frame = CGRectMake(itemInfo.origin.x, itemInfo.origin.y + offset, size.width, size.height);
	attributes.alpha = 1.f;
	return attributes;
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryItemInSection:(NSInteger)idx kind:(NSString *)kind {
	JNWCollectionViewGridLayoutSection *section = self.sections[idx];
	CGFloat width = self.collectionView.visibleSize.width;
	CGRect frame = CGRectZero;
	
	if ([kind isEqualToString:JNWCollectionViewGridLayoutHeaderKind]) {
		frame = CGRectMake(0, section.offset - section.headerHeight, width, section.headerHeight);
	} else if ([kind isEqualToString:JNWCollectionViewGridLayoutFooterKind]) {
		frame = CGRectMake(0, section.offset + section.height, width, section.footerHeight);
	}
	
	JNWCollectionViewLayoutAttributes *attributes = [[JNWCollectionViewLayoutAttributes alloc] init];
	attributes.frame = frame;
	attributes.alpha = 1.f;
	return attributes;
}

- (CGRect)rectForSectionAtIndex:(NSInteger)index {
	JNWCollectionViewGridLayoutSection *section = self.sections[index];
	CGFloat height = section.height + section.headerHeight + section.footerHeight;
	return CGRectMake(0, section.offset, self.collectionView.visibleSize.width, height);
}

- (NSArray *)indexPathsForItemsInRect:(CGRect)rect {
	NSMutableArray *visibleRows = [NSMutableArray array];
	
	for (JNWCollectionViewGridLayoutSection *section in self.sections) {
        
        NSRange columns = [self columnsInRect:rect forSection:section.index];
		NSRange rows = [self rowsInRect:rect fromSection:section];
        NSUInteger numberOfColumns = [self.numberOfColumnsList[section.index] unsignedIntegerValue];
		
		for (NSUInteger rowIdx = rows.location; rowIdx < NSMaxRange(rows); rowIdx++) {
			for (NSUInteger columnIdx = columns.location; columnIdx < NSMaxRange(columns); columnIdx++) {
				NSUInteger itemIdx = (numberOfColumns * rowIdx) + columnIdx;
				if (itemIdx >= section.numberOfItems)
					break;
				[visibleRows addObject:[NSIndexPath jnw_indexPathForItem:itemIdx inSection:section.index]];
			}
		}
	}
	
	return visibleRows;
}

- (NSIndexPath *)indexPathForNextItemInDirection:(JNWCollectionViewDirection)direction currentIndexPath:(NSIndexPath *)currentIndexPath {
	NSIndexPath *newIndexPath = currentIndexPath;
	
	if (direction == JNWCollectionViewDirectionRight) {
		newIndexPath = [self.collectionView indexPathForNextSelectableItemAfterIndexPath:currentIndexPath];
	} else if (direction == JNWCollectionViewDirectionLeft) {
		newIndexPath = [self.collectionView indexPathForNextSelectableItemBeforeIndexPath:currentIndexPath];
	} else if (direction == JNWCollectionViewDirectionUp) {
		CGPoint origin = [self.collectionView rectForItemAtIndexPath:currentIndexPath].origin;
		// Bump the origin up to the cell directly above this one.
		origin.y -= 1; // TODO: Use padding here when implemented.
		newIndexPath = [self.collectionView indexPathForItemAtPoint:origin];
	} else if (direction == JNWCollectionViewDirectionDown) {
		CGRect frame = [self.collectionView rectForItemAtIndexPath:currentIndexPath];
		CGPoint origin = frame.origin;
		// Bump the origin down to the cell directly below this one.
		origin.y += frame.size.height + 1; // TODO: Use padding here when implemented.
		newIndexPath = [self.collectionView indexPathForItemAtPoint:origin];
	}
	
	if (newIndexPath == nil && (direction == JNWCollectionViewDirectionUp || direction == JNWCollectionViewDirectionDown)) {
		CGRect frame = [self.collectionView rectForItemAtIndexPath:currentIndexPath];
		CGPoint origin = frame.origin;
		// This can occur if we have items in a grid section that don't completely fill the section on the
		// last row. Because there still might be a cell above or below, we attempt to skip a row to see if
		// this is the case.
        CGSize size = [self sizeForSection:currentIndexPath.jnw_section];
		origin.y += (direction == JNWCollectionViewDirectionDown ? size.height + frame.size.height + 1 : -(size.height + 1));
		newIndexPath = [self.collectionView indexPathForItemAtPoint:origin];
	}
	
	return newIndexPath;
}

- (NSRange)columnsInRect:(CGRect)rect forSection:(NSUInteger)section {
	NSRange result = NSMakeRange(0, 0);
	
	CGPoint point = CGPointMake(0, CGRectGetMinY(rect));
    CGSize size = [self sizeForSection:section];
    NSUInteger numberOfColumns = [self.numberOfColumnsList[section] unsignedIntegerValue];
    CGFloat itemPadding = [self.itemPaddingList[section] floatValue];
	for (NSUInteger column = 0; column < numberOfColumns; column++) {
		point.x += itemPadding;
		
		if (CGRectContainsPoint(rect, point)) {
			if (result.length == 0) {
				result = NSMakeRange(column, 1);
			}
			else {
				result.length++;
			}
		}
		
		point.x += size.width;
	}
	
	return result;
}

- (NSRange)rowsInRect:(CGRect)rect fromSection:(JNWCollectionViewGridLayoutSection *)section {
	if (section.offset + section.height < CGRectGetMinY(rect) || section.offset > CGRectGetMaxY(rect)) {
		return NSMakeRange(0, 0);
	}
	
	CGFloat relativeRectTop = MAX(0, CGRectGetMinY(rect) - section.offset);
    CGSize size = [self sizeForSection:section.index];
	NSInteger rowBegin = relativeRectTop / (size.height + self.verticalSpacing);
    NSInteger rowsInRect = ceil(rect.size.height / (size.height + self.verticalSpacing));
    NSInteger rowEnd = floorf(rowBegin+rowsInRect);
	return NSMakeRange(rowBegin, 1 + rowEnd - rowBegin);
}

#pragma Drag and Drop

//self.numberOfColumnsList = allColumnNumbers;
//self.itemPaddingList = addItemPaddings;
- (JNWCollectionViewDropIndexPath *)dropIndexPathAtPoint:(NSPoint)point {
    [self scrollIfNecessaryForDragAtPoint:point];
    NSArray *visibleCells = [self.collectionView visibleCells];
    for (JNWCollectionViewCell *cell in visibleCells) {
        if (CGRectContainsPoint(cell.frame, point)) {
            NSIndexPath *path = [self.collectionView indexPathForCell:cell];
            if (path) {
                if (point.x <= cell.frame.origin.x + cell.frame.size.width * 0.5) {
                    return [JNWCollectionViewDropIndexPath indexPathForItem:path.jnw_item inSection:path.jnw_section dropRelation:JNWCollectionViewDropRelationAt];
                } else {
                    return [JNWCollectionViewDropIndexPath indexPathForItem:path.jnw_item inSection:path.jnw_section dropRelation:JNWCollectionViewDropRelationAfter];
                }
            }
        }
        else {
            // We may need to account for horizontal item padding to know which cell is being dropped on
            NSUInteger numberOfColumns = self.numberOfColumnsList[cell.indexPath.jnw_section].unsignedIntegerValue;
            NSUInteger positionCalculation = cell.indexPath.jnw_item % numberOfColumns;
            BOOL isItemOnVeryLeft = positionCalculation == 0;
            BOOL isItemOnVeryRight = positionCalculation == numberOfColumns;
            CGRect rectWithSpacing = cell.frame;
            // see if the drag operation is "between" cells by being "right of" the cell
            CGFloat halfPadding = self.itemPaddingList[cell.indexPath.jnw_section].floatValue / 2;
            rectWithSpacing.size.width += halfPadding;
            if (!isItemOnVeryRight && CGRectContainsPoint(rectWithSpacing, point)) {
                return [JNWCollectionViewDropIndexPath indexPathForItem:cell.indexPath.jnw_item inSection:cell.indexPath.jnw_section dropRelation:JNWCollectionViewDropRelationAfter];
            }
            // see if the drag operation is "between" cells by being "left of" the cell
            rectWithSpacing = cell.frame;
            rectWithSpacing.origin.x -= halfPadding;
            if (!isItemOnVeryLeft && CGRectContainsPoint(rectWithSpacing, point)) {
                return [JNWCollectionViewDropIndexPath indexPathForItem:cell.indexPath.jnw_item inSection:cell.indexPath.jnw_section dropRelation:JNWCollectionViewDropRelationAt];
            }
        }
    }
    return nil;
}

- (JNWCollectionViewLayoutAttributes *)layoutAttributesForDropMarker {
    return self.markerAttributes;
}

@end
