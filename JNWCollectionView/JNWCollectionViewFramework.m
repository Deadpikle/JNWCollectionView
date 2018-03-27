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
// Drag and drop implementation modified from https://github.com/DarkDust/JNWCollectionView (MIT licensed)

#import "JNWCollectionViewFramework.h"
#import "JNWCollectionView+Private.h"
#import "JNWCollectionViewCell+Private.h"
#import "JNWCollectionViewReusableView+Private.h"
#import <QuartzCore/QuartzCore.h>
#import "JNWCollectionViewData.h"
#import "JNWCollectionViewListLayout.h"
#import "JNWCollectionViewDocumentView.h"
#import "JNWCollectionViewLayout.h"
#import "JNWCollectionViewLayout+Private.h"

#import "NSSet+Map.h"
#import "NSDictionary+Mapping.h"
#import "NSArray+Mapping.h"

#ifndef NSAppKitVersionNumber10_11
#define NSAppKitVersionNumber10_11 1404
#endif


typedef NS_ENUM(NSInteger, JNWCollectionViewSelectionType) {
	JNWCollectionViewSelectionTypeSingle,
	JNWCollectionViewSelectionTypeExtending,
	JNWCollectionViewSelectionTypeMultiple
};

@interface JNWCollectionView() <NSDraggingSource> {
	struct {
		unsigned int dataSourceNumberOfSections:1;
		unsigned int dataSourceViewForSupplementaryView:1;
		
		unsigned int delegateMouseDown:1;
		unsigned int delegateMouseDownWithEvent:1;
		unsigned int delegateMouseUp:1;
		unsigned int delegateMouseUpWithEvent:1;
		unsigned int delegateMouseMoved:1;
		unsigned int delegateMouseDragged:1;
		unsigned int delegateMouseEntered:1;
		unsigned int delegateMouseExited:1;
		unsigned int delegateShouldSelect:1;
		unsigned int delegateDidSelect:1;
		unsigned int delegateDidSelectMult:1;
		unsigned int delegateShouldDeselect:1;
		unsigned int delegateDidDeselect:1;
		unsigned int delegateDidDeselectMult:1;
		unsigned int delegateDidSelectItemsChange:1;
		unsigned int delegateShouldScroll:1;
		unsigned int delegateDidScroll:1;
		unsigned int delegateDidDoubleClick:1;
		unsigned int delegateDidRightClick:1;
		unsigned int delegateDidEndDisplayingCell:1;
		unsigned int delegateMenuForEvent:1;
		unsigned int delegateObjectValueForCell:1;
		
		unsigned int dragDropDelegateAllowsDragDrop:1;
		unsigned int dragDropDelegateDropMarker:1;
		unsigned int dragDropDelegateDropMarkerForIndexPath:1;
		
		unsigned int wantsLayout;
	} _collectionViewFlags;
	
	CGSize _lastDrawnSize;
}

// Layout data/cache
@property (nonatomic, strong) JNWCollectionViewData *data;

// Selection
@property (nonatomic, strong, readwrite) NSMutableArray *selectedIndexes;

// Cells
@property (nonatomic, strong) NSMutableDictionary *reusableCells; // { identifier : (cells) }
@property (nonatomic, strong) NSMutableDictionary *visibleCellsMap; // { index path : cell }
@property (nonatomic, strong) NSMutableDictionary *cellClassMap; // { identifier : class }
@property (nonatomic, strong) NSMutableDictionary *cellNibMap; // { identifier : nib }

// Supplementary views
@property (nonatomic, strong) NSMutableDictionary *reusableSupplementaryViews; // { "kind/identifier" : (views) }
@property (nonatomic, strong) NSMutableDictionary *visibleSupplementaryViewsMap; // { "index/kind/identifier" : view } }
@property (nonatomic, strong) NSMutableDictionary *supplementaryViewClassMap; // { "kind/identifier" : class }
@property (nonatomic, strong) NSMutableDictionary *supplementaryViewNibMap; // { "kind/identifier" : nib }

@property (nonatomic, strong) NSView *collectionViewDocumentView;

// Drag and drop
@property (nonatomic, strong) NSView *dropMarker;

// Insert & Delete
@property BOOL willBeginBatchUpdates;
@property BOOL isAnimating;
@property NSMutableArray<NSIndexPath*> *insertedItems;
@property NSMutableArray<NSIndexPath*> *deletedItems;

@end

@implementation JNWCollectionView
@dynamic drawsBackground;
@dynamic backgroundColor;
@dynamic documentView;

// We're using a static function for the common initialization so that subclassers
// don't accidentally override this method in their own common init method.
static void JNWCollectionViewCommonInit(JNWCollectionView *collectionView) {
	collectionView.data = [[JNWCollectionViewData alloc] initWithCollectionView:collectionView];
	
	collectionView.selectedIndexes = [NSMutableArray array];
	collectionView.cellClassMap = [NSMutableDictionary dictionary];
	collectionView.cellNibMap = [NSMutableDictionary dictionary];
	collectionView.visibleCellsMap = [NSMutableDictionary dictionary];
	collectionView.reusableCells = [NSMutableDictionary dictionary];
	collectionView.supplementaryViewClassMap = [NSMutableDictionary dictionary];
	collectionView.supplementaryViewNibMap = [NSMutableDictionary dictionary];
	collectionView.visibleSupplementaryViewsMap = [NSMutableDictionary dictionary];
	collectionView.reusableSupplementaryViews = [NSMutableDictionary dictionary];
	
	// By default we are layer-backed.
	collectionView.wantsLayer = YES;
	
	// Set the document view to a custom class that returns YES to -isFlipped.
	JNWCollectionViewDocumentView *documentView = [[JNWCollectionViewDocumentView alloc] initWithFrame:CGRectZero];
	collectionView.collectionViewDocumentView = documentView;
	collectionView.documentView = documentView;
	
	// We don't want to perform an initial layout pass until the user has called -reloadData.
	collectionView->_collectionViewFlags.wantsLayout = NO;
	
	collectionView.allowsSelection = YES;
	
	collectionView.allowsEmptySelection = YES;
	
	collectionView.allowsMultipleSelection = YES;
	
	collectionView.sendsMultipleSelectionCalls = YES;
	
	collectionView.backgroundColor = NSColor.whiteColor;
	collectionView.drawsBackground = YES;
	
	collectionView.insertedItems = [NSMutableArray array];
	collectionView.deletedItems = [NSMutableArray array];
}

- (id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if (self == nil) return nil;
	JNWCollectionViewCommonInit(self);
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self == nil) return nil;
	JNWCollectionViewCommonInit(self);
	return self;
}

-(void)dealloc {
	[self unregisterDraggedTypes];
}

#pragma mark Delegate and data source

- (void)setDelegate:(id<JNWCollectionViewDelegate>)delegate {
	_delegate = delegate;
	_collectionViewFlags.delegateMouseUp = [delegate respondsToSelector:@selector(collectionView:mouseUpInItemAtIndexPath:)];
	_collectionViewFlags.delegateMouseUpWithEvent = [delegate respondsToSelector:@selector(collectionView:mouseUpInItemAtIndexPath:withEvent:)];
	_collectionViewFlags.delegateMouseDown = [delegate respondsToSelector:@selector(collectionView:mouseDownInItemAtIndexPath:)];
	_collectionViewFlags.delegateMouseDownWithEvent = [delegate respondsToSelector:@selector(collectionView:mouseDownInItemAtIndexPath:withEvent:)];
	_collectionViewFlags.delegateMouseMoved = [delegate respondsToSelector:@selector(collectionView:mouseMovedInItemAtIndexPath:withEvent:)];
	_collectionViewFlags.delegateMouseDragged = [delegate respondsToSelector:@selector(collectionView:mouseDraggedInItemAtIndexPath:withEvent:)];
	_collectionViewFlags.delegateMouseEntered = [delegate respondsToSelector:@selector(collectionView:mouseEnteredInItemAtIndexPath:withEvent:)];
	_collectionViewFlags.delegateMouseExited = [delegate respondsToSelector:@selector(collectionView:mouseExitedInItemAtIndexPath:withEvent:)];
	_collectionViewFlags.delegateShouldSelect = [delegate respondsToSelector:@selector(collectionView:shouldSelectItemAtIndexPath:)];
	_collectionViewFlags.delegateDidSelect = [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)];
	_collectionViewFlags.delegateDidSelectMult = [delegate respondsToSelector:@selector(collectionView:didSelectItemsAtIndexPaths:)];
	_collectionViewFlags.delegateShouldDeselect = [delegate respondsToSelector:@selector(collectionView:shouldDeselectItemAtIndexPath:)];
	_collectionViewFlags.delegateDidDeselect = [delegate respondsToSelector:@selector(collectionView:didDeselectItemAtIndexPath:)];
	_collectionViewFlags.delegateDidDeselectMult = [delegate respondsToSelector:@selector(collectionView:didDeselectItemsAtIndexPaths:)];
	_collectionViewFlags.delegateDidSelectItemsChange = [delegate respondsToSelector:@selector(collectionView:selectedItemsChangedToIndexPaths:)];
	_collectionViewFlags.delegateDidDoubleClick = [delegate respondsToSelector:@selector(collectionView:didDoubleClickItemAtIndexPath:)];
	_collectionViewFlags.delegateDidRightClick = [delegate respondsToSelector:@selector(collectionView:didRightClickItemAtIndexPath:)];
	_collectionViewFlags.delegateDidEndDisplayingCell = [delegate respondsToSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)];
	_collectionViewFlags.delegateShouldScroll = [delegate respondsToSelector:@selector(collectionView:shouldScrollToItemAtIndexPath:)];
	_collectionViewFlags.delegateDidScroll = [delegate respondsToSelector:@selector(collectionView:didScrollToItemAtIndexPath:)];
	_collectionViewFlags.delegateMenuForEvent = [delegate respondsToSelector:@selector(collectionView:menuForEvent:)];
	_collectionViewFlags.delegateObjectValueForCell = [delegate respondsToSelector:@selector(collectionView:objectValueForItemAtIndexPath:)];
}

- (void)setDataSource:(id<JNWCollectionViewDataSource>)dataSource {
	_dataSource = dataSource;
	_collectionViewFlags.dataSourceNumberOfSections = [dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)];
	_collectionViewFlags.dataSourceViewForSupplementaryView = [dataSource respondsToSelector:@selector(collectionView:viewForSupplementaryViewOfKind:inSection:)];
	NSAssert(dataSource == nil || [dataSource respondsToSelector:@selector(collectionView:numberOfItemsInSection:)],
			 @"data source must implement collectionView:numberOfItemsInSection");
	NSAssert(dataSource == nil || [dataSource respondsToSelector:@selector(collectionView:cellForItemAtIndexPath:)],
			 @"data source must implement collectionView:cellForItemAtIndexPath:");
}

- (void)setDragDropDelegate:(id<JNWCollectionViewDragDropDelegate>)dragDropDelegate {
	_dragDropDelegate = dragDropDelegate;
	
	//[self unregisterDraggedTypes]; // safety measure
	[self registerForDraggedTypes:[dragDropDelegate draggedTypesForCollectionView:self]];
	
	_collectionViewFlags.dragDropDelegateDropMarker = [dragDropDelegate respondsToSelector:@selector(collectionView:dropMarkerViewWithFrame:)];
	_collectionViewFlags.dragDropDelegateDropMarkerForIndexPath = [dragDropDelegate respondsToSelector:@selector(collectionView:dropMarkerViewWithFrame:forIndexPath:)];
	_collectionViewFlags.dragDropDelegateAllowsDragDrop = [dragDropDelegate respondsToSelector:@selector(collectionView:shouldAllowDragDropForIndices:)];
}


#pragma mark Queueing and dequeuing

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)reuseIdentifier {
	NSParameterAssert(cellClass);
	NSParameterAssert(reuseIdentifier);
	NSAssert([cellClass isSubclassOfClass:JNWCollectionViewCell.class], @"registered cell class must be a subclass of JNWCollectionViewCell");
	self.cellClassMap[reuseIdentifier] = cellClass;
	[self.cellNibMap removeObjectForKey:reuseIdentifier];
}

- (void)registerClass:(Class)supplementaryViewClass forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)reuseIdentifier {
	NSParameterAssert(supplementaryViewClass);
	NSParameterAssert(kind);
	NSParameterAssert(reuseIdentifier);
	NSAssert([supplementaryViewClass isSubclassOfClass:JNWCollectionViewReusableView.class],
			 @"registered supplementary view class must be a subclass of JNWCollectionViewReusableView");
	
	// Thanks to PSTCollectionView for the original idea of using the key and reuse identfier to
	// form the key for the supplementary views.
	NSString *identifier = [self supplementaryViewIdentifierWithKind:kind reuseIdentifier:reuseIdentifier];
	self.supplementaryViewClassMap[identifier] = supplementaryViewClass;
	[self.supplementaryViewNibMap removeObjectForKey:identifier];
}

- (void)registerNib:(NSNib *)cellNib forCellWithReuseIdentifier:(NSString *)reuseIdentifier {
	NSParameterAssert(cellNib);
	NSParameterAssert(reuseIdentifier);
	
	self.cellNibMap[reuseIdentifier] = cellNib;
	[self.cellClassMap removeObjectForKey:reuseIdentifier];
}

- (void)registerNib:(NSNib *)supplementaryViewNib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)reuseIdentifier {
	NSParameterAssert(supplementaryViewNib);
	NSParameterAssert(kind);
	NSParameterAssert(reuseIdentifier);
	
	NSString *identifier = [self supplementaryViewIdentifierWithKind:kind reuseIdentifier:reuseIdentifier];
	self.supplementaryViewNibMap[identifier] = supplementaryViewNib;
	[self.supplementaryViewClassMap removeObjectForKey:identifier];
}

- (id)dequeueItemWithIdentifier:(NSString *)identifier inReusePool:(NSDictionary *)reuse {
	if (identifier == nil)
		return nil;
	
	NSMutableArray *reusableItems = reuse[identifier];
	if (reusableItems != nil) {
		id reusableItem = [reusableItems lastObject];
		
		if (reusableItem != nil) {
			[reusableItems removeObject:reusableItem];
			return reusableItem;
		}
	}
	
	return nil;
}

- (void)enqueueItem:(id)item withIdentifier:(NSString *)identifier inReusePool:(NSMutableDictionary *)reuse {
	if (identifier == nil)
		return;
	
	NSMutableArray *reusableCells = reuse[identifier];
	if (reusableCells == nil) {
		reusableCells = [NSMutableArray array];
		reuse[identifier] = reusableCells;
	}
	
	[reusableCells addObject:item];
}

- (id)firstTopLevelObjectOfClass:(Class)objectClass inNib:(NSNib *)nib {
	NSArray *topLevelObjects = nil;
	return [self firstTopLevelObjectOfClass:objectClass inNib:nib topLevelObjects:&topLevelObjects];
}

- (id)firstTopLevelObjectOfClass:(Class)objectClass inNib:(NSNib *)nib topLevelObjects:(NSArray**)objects {
	id foundObject = nil;
	if ([nib instantiateWithOwner:self topLevelObjects:objects]) {
		NSUInteger objectIndex = [*objects indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
			if ([obj isKindOfClass:objectClass]) {
				*stop = YES;
				return YES;
			}
			return NO;
		}];
		if (objectIndex != NSNotFound) {
			foundObject = [*objects objectAtIndex:objectIndex];
		}
	}
	return foundObject;
}

- (JNWCollectionViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier {
	NSParameterAssert(identifier);
	JNWCollectionViewCell *cell = [self dequeueItemWithIdentifier:identifier inReusePool:self.reusableCells];
	
	// If the view doesn't exist, we go ahead and create one. If we have a class registered
	// for this identifier, we use it, otherwise we just create an instance of JNWCollectionViewCell.
	if (cell == nil) {
		Class cellClass = self.cellClassMap[identifier];
		NSNib *cellNib = self.cellNibMap[identifier];
		
		if (cellClass == nil && cellNib == nil) {
			cellClass = JNWCollectionViewCell.class;
		}
		
		if (cellNib != nil) {
			NSArray *topLevelObjects = nil;
			cell = [self firstTopLevelObjectOfClass:JNWCollectionViewCell.class inNib:cellNib topLevelObjects:&topLevelObjects];
			// If the delegate is looking to use data binding, rig up the cell to use the NSObjectController from the nib.
			if (_collectionViewFlags.delegateObjectValueForCell) {
				for (id obj in topLevelObjects) {
					if ([obj isKindOfClass:[NSObjectController class]]) {
						cell.objectController = obj;
						break;
					}
				}
			}
		} else if (cellClass != nil) {
			cell = [[cellClass alloc] initWithFrame:CGRectZero];
		}
	}
	
	cell.reuseIdentifier = identifier;
	[cell prepareForReuse];
	[cell setMenu:[[NSMenu alloc] init]];
	return cell;
}

- (JNWCollectionViewReusableView *)dequeueReusableSupplementaryViewOfKind:(NSString *)kind withReuseIdentifer:(NSString *)reuseIdentifier {
	NSParameterAssert(reuseIdentifier);
	NSParameterAssert(kind);
	
	NSString *identifier = [self supplementaryViewIdentifierWithKind:kind reuseIdentifier:reuseIdentifier];
	JNWCollectionViewReusableView *view = [self dequeueItemWithIdentifier:identifier inReusePool:self.reusableSupplementaryViews];
	
	if (view == nil) {
		Class viewClass = self.supplementaryViewClassMap[identifier];
		NSNib *viewNib = self.supplementaryViewNibMap[identifier];
		
		if (viewClass == nil && viewNib == nil) {
			viewClass = JNWCollectionViewReusableView.class;
		}
		
		if (viewNib != nil) {
			view = [self firstTopLevelObjectOfClass:JNWCollectionViewReusableView.class inNib:viewNib];
		} else if (viewClass != nil) {
			view = [[viewClass alloc] initWithFrame:CGRectZero];
		}
	}
	
	view.reuseIdentifier = reuseIdentifier;
	view.kind = kind;
	
	return view;
}

- (void)enqueueReusableCell:(JNWCollectionViewCell *)cell withIdentifier:(NSString *)identifier {
	[self enqueueItem:cell withIdentifier:identifier inReusePool:self.reusableCells];
}

- (void)enqueueReusableSupplementaryView:(JNWCollectionViewReusableView *)view ofKind:(NSString *)kind withReuseIdentifier:(NSString *)reuseIdentifier {
	NSString *identifier = [self supplementaryViewIdentifierWithKind:kind reuseIdentifier:reuseIdentifier];
	[self enqueueItem:view withIdentifier:identifier inReusePool:self.reusableSupplementaryViews];
}

#pragma mark Reloading

- (void)reloadData {
	_collectionViewFlags.wantsLayout = YES;
	
	// Remove and notify any selected indexes we've been tracking.
	NSArray *selectedIndexes = self.selectedIndexes.copy;
	[self.selectedIndexes removeAllObjects];

	if (_collectionViewFlags.delegateDidDeselect && self.sendsMultipleSelectionCalls) {
        for (NSIndexPath *indexPath in selectedIndexes) {
            [self.delegate collectionView:self didDeselectItemAtIndexPath:indexPath];
        }
	}
    if (_collectionViewFlags.delegateDidDeselectMult && !self.sendsMultipleSelectionCalls) {
        [self.delegate collectionView:self didDeselectItemsAtIndexPaths:[NSSet setWithArray:self.selectedIndexes]];
    }
	
	[self.data recalculateAndPrepareLayout:YES];
	[self performFullRelayoutForcingSubviewsReset:YES];
	
	// Select the first item if empty selection is not allowed
	if (!self.allowsEmptySelection) {
		NSIndexPath *indexPath = [self indexPathForNextSelectableItemAfterIndexPath:nil];
		[self selectItemAtIndexPath:indexPath animated:NO sendDelegateMessage:self.sendsMultipleSelectionCalls];
		if (!self.sendsMultipleSelectionCalls && _collectionViewFlags.delegateDidSelectMult) {
			[self.delegate collectionView:self didSelectItemsAtIndexPaths:[NSSet setWithArray:@[indexPath]]];
		}
		if (_collectionViewFlags.delegateDidSelectItemsChange) {
			[self.delegate collectionView:self selectedItemsChangedToIndexPaths:[NSSet setWithArray:self.selectedIndexes]];
		}
	}
}

- (void)setCollectionViewLayout:(JNWCollectionViewLayout *)collectionViewLayout {
	if (self.collectionViewLayout == collectionViewLayout)
		return;
	
	NSAssert(collectionViewLayout.collectionView == nil, @"Collection view layouts should not be reused between separate collection view instances.");
	
	_collectionViewLayout = collectionViewLayout;
	_collectionViewLayout.collectionView = self;
	
	// Don't reload the data until we've performed an initial reload.
	if (_collectionViewFlags.wantsLayout) {
		[self reloadData];
	}
}

#pragma mark Resetting of state

/// Completely removes and resets cells, supplementary views, and selection state.
- (void)resetAllCellsAndSupplementaryViews {
	// Remove any queued views.
	[self.reusableCells removeAllObjects];
	[self.reusableSupplementaryViews removeAllObjects];
	
	// Remove any view mappings
	if (_collectionViewFlags.delegateDidEndDisplayingCell) {
		for (JNWCollectionViewCell *cell in self.visibleCellsMap.allValues) {
			[self.delegate collectionView:self didEndDisplayingCell:cell forItemAtIndexPath:cell.indexPath];
		}
	}
	[self.visibleCellsMap removeAllObjects];
	[self.visibleSupplementaryViewsMap removeAllObjects];
	
	// Remove any cells or views that might be added to the document view.
	NSArray *subviews = [[self.documentView subviews] copy];
	
	for (NSView *view in subviews) {
		[view removeFromSuperview];
	}
}

#pragma mark Cell Information

- (NSInteger)numberOfSections {
	return self.data.numberOfSections;
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section {
	return [self.data numberOfItemsInSection:section];
}

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point {
	// TODO: Optimize, and perhaps have an option to defer this to the layout class.
	for (int i = 0; i < self.data.numberOfSections; i++) {
		JNWCollectionViewSection section = self.data.sections[i];
		if (!CGRectContainsPoint(section.frame, point))
			continue;
		
		NSUInteger numberOfItems = section.numberOfItems;
		for (NSInteger item = 0; item < numberOfItems; item++) {
			NSIndexPath *indexPath = [NSIndexPath jnw_indexPathForItem:item inSection:section.index];
			JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
			if (CGRectContainsPoint(attributes.frame, point)) {
				return indexPath;
			}
		}
	}
	
	return nil;
}

- (NSArray *)visibleCells {
	return self.visibleCellsMap.allValues;
}

- (BOOL)validateIndexPath:(NSIndexPath *)indexPath {
	return (indexPath.jnw_section < self.data.numberOfSections && indexPath.jnw_item < self.data.sections[indexPath.jnw_section].numberOfItems);
}

- (NSArray *)allIndexPaths {
	NSMutableArray *indexPaths = [NSMutableArray array];
	for (int i = 0; i < self.data.numberOfSections; i++) {
		JNWCollectionViewSection section = self.data.sections[i];
		for (NSInteger item = 0; item < section.numberOfItems; item++) {
			[indexPaths addObject:[NSIndexPath jnw_indexPathForItem:item inSection:section.index]];
		}
	}
	
	return indexPaths.copy;
}

- (NSIndexPath *)firstIndexPath {
	if ([self numberOfItemsInSection:0] > 0) {
		return [NSIndexPath jnw_indexPathForItem:0 inSection:0];
	}
	
	return nil;
}

- (NSIndexPath *)lastIndexPath {
	NSIndexPath *indexPath = nil;
	NSInteger numberOfSections = self.data.numberOfSections;
	if (numberOfSections > 0) {
		JNWCollectionViewSection section = self.data.sections[numberOfSections - 1];
		NSInteger numberOfItems = section.numberOfItems;
		if (numberOfItems > 0) {
			indexPath = [NSIndexPath jnw_indexPathForItem:numberOfItems - 1 inSection:numberOfSections - 1];
		}
	}
	return indexPath;
}

- (NSArray *)indexPathsForItemsInRect:(CGRect)rect {
	if (CGRectEqualToRect(rect, CGRectZero))
		return [NSArray array];
	
	NSArray *potentialIndexPaths = [self.collectionViewLayout indexPathsForItemsInRect:rect];
	if (potentialIndexPaths != nil) {
		return potentialIndexPaths;
	}
	
	NSMutableArray *visibleCells = [NSMutableArray array];
	
	for (int i = 0; i < self.data.numberOfSections; i++) {
		JNWCollectionViewSection section = self.data.sections[i];
		if (!CGRectIntersectsRect(section.frame, rect))
			continue;
		
		NSUInteger numberOfItems = section.numberOfItems;
		for (NSInteger item = 0; item < numberOfItems; item++) {
			NSIndexPath *indexPath = [NSIndexPath jnw_indexPathForItem:item inSection:section.index];
			JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
			
			if (CGRectIntersectsRect(attributes.frame, rect)) {
				[visibleCells addObject:indexPath];
			}
		}
	}
	
	return visibleCells;
}

- (NSArray *)layoutIdentifiersForSupplementaryViewsInRect:(CGRect)rect {
	NSMutableArray *visibleIdentifiers = [NSMutableArray array];
	NSArray *allIdentifiers = [self allSupplementaryViewIdentifiers];
	
	if (CGRectEqualToRect(rect, CGRectZero))
		return visibleIdentifiers;
	
	for (int i = 0; i < self.data.numberOfSections; i++) {
		JNWCollectionViewSection section = self.data.sections[i];
		for (NSString *identifier in allIdentifiers) {
			NSString *kind = [self kindForSupplementaryViewIdentifier:identifier];
			JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryItemInSection:section.index kind:kind];
			if (CGRectIntersectsRect(attributes.frame, rect)) {
				[visibleIdentifiers addObject:[self layoutIdentifierForSupplementaryViewIdentifier:identifier inSection:section.index]];
			}
		}
	}
	
	return visibleIdentifiers.copy;
}

- (NSIndexSet *)indexesForSectionsInRect:(CGRect)rect {
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	
	if (CGRectEqualToRect(rect, CGRectZero))
		return indexes;
	
	for (int i = 0; i < self.data.numberOfSections; i++) {
		JNWCollectionViewSection section = self.data.sections[i];
		if (CGRectIntersectsRect(rect, section.frame)) {
			[indexes addIndex:section.index];
		}
	}
	
	return indexes.copy;
}

- (NSArray *)indexPathsForVisibleItems {
	return [self indexPathsForItemsInRect:self.documentVisibleRect];
}

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(JNWCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated {
	if (_collectionViewFlags.delegateShouldScroll && ![self.delegate collectionView:self shouldScrollToItemAtIndexPath:indexPath]) {
		return;
	}
	
	CGRect rect = [self rectForItemAtIndexPath:indexPath];
	CGRect visibleRect = self.documentVisibleRect;
	
	switch (scrollPosition) {
			break;
		case JNWCollectionViewScrollPositionTop:
			// make the top of our rect flush with the top of the visible bounds
			rect.size.height = CGRectGetHeight(visibleRect);
			//rect.origin.y = self.documentVisibleRect.origin.y + rect.size.height;
			break;
		case JNWCollectionViewScrollPositionMiddle:
			// TODO
			rect.size.height = self.bounds.size.height;
			rect.origin.y += (CGRectGetHeight(visibleRect) / 2.f) - CGRectGetHeight(rect);
			break;
		case JNWCollectionViewScrollPositionBottom:
			// make the bottom of our rect flush with the bottom of the visible bounds
			rect.size.height = CGRectGetHeight(visibleRect);
			rect.origin.y -= CGRectGetHeight(visibleRect);
			break;
		case JNWCollectionViewScrollPositionNone:
			// no scroll needed
			return;
			break;
		case JNWCollectionViewScrollPositionNearest:
			// We just pass the cell's frame onto the scroll view. It calculates this for us.
			break;
		default: // defaults to the same behavior as nearest
			break;
	}
	
	[self.clipView scrollRectToVisible:rect animated:animated];
	
	if (_collectionViewFlags.delegateDidScroll) {
		[self.delegate collectionView:self didScrollToItemAtIndexPath:indexPath];
	}
}

- (CGRect)rectForItemAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath == nil || indexPath.jnw_section < self.data.numberOfSections) {
		JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
		return attributes.frame;
	}
	
	return CGRectZero;
}

- (CGRect)rectForSupplementaryViewWithKind:(NSString *)kind inSection:(NSInteger)section {
	if (section >= 0 && section < self.data.numberOfSections) {
		JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryItemInSection:section kind:kind];
		return attributes.frame;
	}
	
	return CGRectZero;
}

- (CGRect)rectForSection:(NSInteger)index {
	if (index >= 0 && index < self.data.numberOfSections) {
		JNWCollectionViewSection section = self.data.sections[index];
		return section.frame;
	}
	return CGRectZero;
}

- (JNWCollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath == nil)
		return nil;
	return self.visibleCellsMap[indexPath];
}

- (JNWCollectionViewReusableView *)supplementaryViewForKind:(NSString *)kind reuseIdentifier:(NSString *)reuseIdentifier inSection:(NSInteger)section {
	NSString *identifer = [self supplementaryViewIdentifierWithKind:kind reuseIdentifier:reuseIdentifier];
	NSString *layoutIdentifier = [self layoutIdentifierForSupplementaryViewIdentifier:identifer inSection:section];
	
	return self.visibleSupplementaryViewsMap[layoutIdentifier];
}

- (NSIndexPath *)indexPathForCell:(JNWCollectionViewCell *)cell {
	return cell.indexPath;
}

#pragma mark Layout

- (void)layout {
	[super layout];
	
	if (CGSizeEqualToSize(self.visibleSize, _lastDrawnSize)) {
		[self layoutCells];
		[self layoutSupplementaryViews];
	} else {
		// Calling recalculate on our data will update the bounds needed for the collection
		// view, and optionally prepare the layout once again if the layout subclass decides
		// it needs a recalculation.
		CGRect visibleBounds = (CGRect){ .size = self.visibleSize };
		BOOL shouldInvalidate = [self.collectionViewLayout shouldInvalidateLayoutForBoundsChange:visibleBounds];
		[self.data recalculateAndPrepareLayout:shouldInvalidate];
		
		// See https://github.com/jwilling/JNWCollectionView/issues/117 if you are having issues with resizing
		// window frames and lag
		[self performFullRelayoutForcingSubviewsReset:NO];
		//[self performFullRelayoutForcingSubviewsReset:shouldInvalidate];
	}
}

- (void)reflectScrolledClipView:(NSClipView*)clipView {
    [super reflectScrolledClipView:clipView];
    
    // 10.12 started optimizing the layout pass and reducing the number of calls to layout(). As
    // such, invalidate our layout when the scroll changes on 10.12 and above.
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_11) {
        // Invalidate our layout when we our scrolled. This is required for 10.12 and above.
        self.needsLayout = YES;
    }
}

- (void)collectionViewLayoutWasInvalidated:(JNWCollectionViewLayout *)layout {
	// First we prepare the layout. In the future it would possibly be a good idea to coalesce
	// this call to reduce unnecessary layout preparation calls.
	[self.data recalculateAndPrepareLayout:YES];
    // On 2018-03-27, Deadpikle changed the subview reset from YES to NO. He did not know
    // why a layout invalidation should cause all subviews to be reset (read: reallocated),
    // when cells should be able to be re-used between layout passes. Having this as YES
    // forces all cells to be recreated on an invalidateLayout call.
    // With this set to NO, the only time all subviews have a force reset is via reloadData.
	[self performFullRelayoutForcingSubviewsReset:NO];
}

- (void)performFullRelayoutForcingSubviewsReset:(BOOL)forceReset {
	if (forceReset && _collectionViewFlags.wantsLayout) {
		[self resetAllCellsAndSupplementaryViews];
	}
	
	[self layoutDocumentView];
	[self layoutCellsWithRedraw:YES];
	[self layoutSupplementaryViewsWithRedraw:YES];
	
	_lastDrawnSize = self.visibleSize;
}

- (void)layoutDocumentView {
	if (!_collectionViewFlags.wantsLayout)
		return;
	
	[self updateScrollDirection];
	
	NSView *documentView = self.documentView;
	documentView.frameSize = self.data.encompassingSize;
}

- (void)updateScrollDirection {
	switch (self.collectionViewLayout.scrollDirection) {
		case JNWCollectionViewScrollDirectionVertical:
			self.hasVerticalScroller = YES;
			self.hasHorizontalScroller = NO;
			break;
		case JNWCollectionViewScrollDirectionHorizontal:
			self.hasVerticalScroller = NO;
			self.hasHorizontalScroller = YES;
			break;
		case JNWCollectionViewScrollDirectionBoth:
		default:
			self.hasVerticalScroller = YES;
			self.hasHorizontalScroller = YES;
			break;
	}
}

- (CGSize)visibleSize {
	return self.documentVisibleRect.size;
}

- (void)layoutCells {
	[self layoutCellsWithRedraw:NO];
}

- (void)layoutCellsWithRedraw:(BOOL)needsVisibleRedraw {
	if (self.dataSource == nil || !_collectionViewFlags.wantsLayout)
		return;
	
	if (needsVisibleRedraw || [self.collectionViewLayout shouldApplyExistingLayoutAttributesOnLayout]) {
		for (NSIndexPath *indexPath in self.visibleCellsMap.allKeys) {
			JNWCollectionViewCell *cell = self.visibleCellsMap[indexPath];
			[self updateCell:cell forIndexPath:indexPath];
		}
	}
	
	NSArray *oldVisibleIndexPaths = [self.visibleCellsMap allKeys];
	NSArray *updatedVisibleIndexPaths = [self indexPathsForItemsInRect:self.documentVisibleRect];
	
	
	NSMutableArray *indexPathsToRemove = [NSMutableArray arrayWithArray:oldVisibleIndexPaths];
	[indexPathsToRemove removeObjectsInArray:updatedVisibleIndexPaths];
	
	NSMutableArray *indexPathsToAdd = [NSMutableArray arrayWithArray:updatedVisibleIndexPaths];
	[indexPathsToAdd removeObjectsInArray:oldVisibleIndexPaths];
	
	// Remove old cells and put them in the reuse queue
	for (NSIndexPath *indexPath in indexPathsToRemove) {
		[self removeAndEnqueueCellAtIndexPath:indexPath];
	}
	
	// Add the new cells
	for (NSIndexPath *indexPath in indexPathsToAdd) {
		[self addCellForIndexPath:indexPath];
	}
}

- (JNWCollectionViewCell*)addCellForIndexPath:(NSIndexPath*)indexPath {
	JNWCollectionViewCell *cell = [self.dataSource collectionView:self cellForItemAtIndexPath:indexPath];
	
	// If any of these are true this cell isn't valid, and we'll be forced to skip it and throw the relevant exceptions.
	if (cell == nil || ![cell isKindOfClass:JNWCollectionViewCell.class]) {
		NSAssert(cell != nil, @"collectionView:cellForItemAtIndexPath: must return a non-nil cell.");
		// Although we have checked to ensure the class registered for the cell is a subclass
		// of JNWCollectionViewCell earlier, there's always the chance that the user has
		// not used the dedicated dequeuing method to retrieve their newly created cell and
		// instead have just created it themselves. There's not much we can do to prevent this,
		// so it's probably worth it to double check this one more time.
		NSAssert([cell isKindOfClass:JNWCollectionViewCell.class],
				 @"collectionView:cellForItemAtIndexPath: must return an instance or subclass of JNWCollectionViewCell.");
		return nil;
	}
	cell.indexPath = indexPath;
	cell.collectionView = self;
	
	[self updateLayoutAttributesForCell:cell indexPath:indexPath];
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0;
		[self updateCell:cell forIndexPath:indexPath];
	} completionHandler:nil];
	
	if (cell.superview == nil) {
		[self.documentView addSubview:cell];
	} else {
		[cell setHidden:NO];
	}
		
	if (_collectionViewFlags.delegateObjectValueForCell) {
		if (cell.objectController) {
			cell.objectController.content = [self.delegate collectionView:self objectValueForItemAtIndexPath:indexPath];
		}
		cell.objectValue = [self.delegate collectionView:self objectValueForItemAtIndexPath:indexPath];
	}
	
	self.visibleCellsMap[indexPath] = cell;
	
	[self updateSelectionStateOfCell:cell];
	
	return cell;
}

- (void)removeAndEnqueueCellAtIndexPath:(NSIndexPath*)indexPath {
	JNWCollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
	[self.visibleCellsMap removeObjectForKey:indexPath];
	[self enqueueReusableCell:cell withIdentifier:cell.reuseIdentifier];
	[cell setHidden:YES];
		
	// clear objectValue and objectController.content when cells are re-used
	cell.objectValue = nil;
	if (cell.objectController) {
		cell.objectController.content = nil;
	}
	
	if (_collectionViewFlags.delegateDidEndDisplayingCell) {
		[self.delegate collectionView:self didEndDisplayingCell:cell forItemAtIndexPath:indexPath];
	}
}

- (void)updateLayoutAttributesForCell:(JNWCollectionViewCell*)cell indexPath:(NSIndexPath*)indexPath {
	JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
	[self applyLayoutAttributes:attributes toCell:cell];
}

- (void)applyLayoutAttributes:(JNWCollectionViewLayoutAttributes *)attributes toCell:(JNWCollectionViewCell *)cell {
	[cell willLayoutWithFrame:attributes.frame];
	
	cell.frame = attributes.frame;
	cell.alphaValue = attributes.alpha;
	cell.layer.zPosition = attributes.zIndex;
	
	[cell didLayoutWithFrame:attributes.frame];
}

- (void)updateCell:(JNWCollectionViewCell*)cell forIndexPath:(NSIndexPath*)indexPath {
	cell.indexPath = indexPath;
	cell.collectionView = self;
	
	[self updateLayoutAttributesForCell:cell indexPath:indexPath];
}

- (void)updateSelectionStateOfCell:(JNWCollectionViewCell *)cell {
	if ([self.selectedIndexes containsObject:cell.indexPath]) {
		cell.selected = YES;
	} else {
		cell.selected = NO;
	}
}

#pragma mark Supplementary Views

- (NSArray *)allSupplementaryViewIdentifiers {
	return [self.supplementaryViewClassMap.allKeys arrayByAddingObjectsFromArray:self.supplementaryViewNibMap.allKeys];
}

- (NSString *)supplementaryViewIdentifierWithKind:(NSString *)kind reuseIdentifier:(NSString *)reuseIdentifier {
	return [NSString stringWithFormat:@"%@/%@", kind, reuseIdentifier];
}

- (NSString *)kindForSupplementaryViewIdentifier:(NSString *)identifier {
	NSArray *components = [identifier componentsSeparatedByString:@"/"];
	return components[0];
}

- (NSString *)reuseIdentifierForSupplementaryViewIdentifier:(NSString *)identifier {
	NSArray *components = [identifier componentsSeparatedByString:@"/"];
	return components[1];
}

- (NSString *)layoutIdentifierForSupplementaryViewIdentifier:(NSString *)identifier inSection:(NSInteger)section {
	return [NSString stringWithFormat:@"%li/%@", section, identifier];
}

- (NSString *)supplementaryViewIdentifierForLayoutIdentifier:(NSString *)identifier {
	NSArray *comps = [identifier componentsSeparatedByString:@"/"];
	return [NSString stringWithFormat:@"%@/%@", comps[1], comps[2]];
}

- (NSInteger)sectionForSupplementaryLayoutIdentifier:(NSString *)identifier {
	NSArray *comps = [identifier componentsSeparatedByString:@"/"];
	return [comps[0] integerValue];
}

- (void)layoutSupplementaryViews {
	[self layoutSupplementaryViewsWithRedraw:NO];
}

- (void)layoutSupplementaryViewsWithRedraw:(BOOL)needsVisibleRedraw {
	if (!_collectionViewFlags.dataSourceViewForSupplementaryView || !_collectionViewFlags.wantsLayout)
		return;
	
	if (needsVisibleRedraw || [self.collectionViewLayout shouldApplyExistingLayoutAttributesOnLayout]) {
		NSArray *allVisibleIdentifiers = self.visibleSupplementaryViewsMap.allKeys;
		for (NSString *layoutIdentifier in allVisibleIdentifiers) {
			NSString *identifier = [self supplementaryViewIdentifierForLayoutIdentifier:layoutIdentifier];
			NSString *reuseIdentifier = [self reuseIdentifierForSupplementaryViewIdentifier:identifier];
			NSString *kind = [self kindForSupplementaryViewIdentifier:identifier];
			NSInteger section = [self sectionForSupplementaryLayoutIdentifier:layoutIdentifier];
			JNWCollectionViewReusableView *view = [self supplementaryViewForKind:kind reuseIdentifier:reuseIdentifier inSection:section];
			
			JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryItemInSection:section kind:kind];
			[self applyLayoutAttributes:attributes toSupplementaryView:view];
		}
	}
	
	// Here's the strategy. There can only be one supplementary view for each kind in every section. Now this supplementary view
	// might not be of the same type in each section, due to the fact that the user might have registered multiple classes/identifiers
	// for the same kind. So what we're wanting to do is just loop through the kinds and ask the data source for the supplementary view
	// for each section/kind.
	
	// { "index/kind/identifier" : view }
	NSArray *oldVisibleViewsIdentifiers = self.visibleSupplementaryViewsMap.allKeys;
	NSArray *updatedVisibleViewsIdentifiers = [self layoutIdentifiersForSupplementaryViewsInRect:self.documentVisibleRect];
	
	NSMutableArray *viewsToRemoveIdentifers = [NSMutableArray arrayWithArray:oldVisibleViewsIdentifiers];
	[viewsToRemoveIdentifers removeObjectsInArray:updatedVisibleViewsIdentifiers];
	
	NSMutableArray *viewsToAddIdentifiers = [NSMutableArray arrayWithArray:updatedVisibleViewsIdentifiers];
	[viewsToAddIdentifiers removeObjectsInArray:oldVisibleViewsIdentifiers];
	
	// Remove old views
	for (NSString *layoutIdentifier in viewsToRemoveIdentifers) {
		JNWCollectionViewReusableView *view = self.visibleSupplementaryViewsMap[layoutIdentifier];
		[self.visibleSupplementaryViewsMap removeObjectForKey:layoutIdentifier];
		
		[view removeFromSuperview];
		
		[self enqueueReusableSupplementaryView:view ofKind:view.kind withReuseIdentifier:view.reuseIdentifier];
	}
	
	// Add new views
	for (NSString *layoutIdentifier in viewsToAddIdentifiers) {
		NSInteger section = [self sectionForSupplementaryLayoutIdentifier:layoutIdentifier];
		NSString *identifier = [self supplementaryViewIdentifierForLayoutIdentifier:layoutIdentifier];
		NSString *kind = [self kindForSupplementaryViewIdentifier:identifier];
		
		JNWCollectionViewReusableView *view = [self.dataSource collectionView:self viewForSupplementaryViewOfKind:kind inSection:section];
		NSAssert([view isKindOfClass:JNWCollectionViewReusableView.class], @"view returned from %@ should be a subclass of %@",
				 NSStringFromSelector(@selector(collectionView:viewForSupplementaryViewOfKind:inSection:)), NSStringFromClass(JNWCollectionViewReusableView.class));
		
		JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryItemInSection:section kind:kind];
		view.frame = attributes.frame;
		view.alphaValue = attributes.alpha;
		[self.documentView addSubview:view];
		
		self.visibleSupplementaryViewsMap[layoutIdentifier] = view;
	}
}

- (void)applyLayoutAttributes:(JNWCollectionViewLayoutAttributes *)attributes toSupplementaryView:(JNWCollectionViewReusableView *)view {
	view.frame = attributes.frame;
	view.alphaValue = attributes.alpha;
	view.layer.zPosition = attributes.zIndex;
}

#pragma mark Mouse events and selection

- (BOOL)canBecomeKeyView {
	return YES;
}

- (BOOL)acceptsFirstResponder {
	return YES;
}

- (BOOL)becomeFirstResponder {
	return YES;
}

- (BOOL)resignFirstResponder {
	return YES;
}

// Returns the last object in the selection array.
- (NSIndexPath *)indexPathForSelectedItem {
	return self.selectedIndexes.lastObject;
}

- (NSArray *)indexPathsForSelectedItems {
	return self.selectedIndexes.copy;
}

- (void)deselectItemsAtIndexPaths:(NSArray *)indexPaths animated:(BOOL)animated {
	for (NSIndexPath *indexPath in indexPaths) {
		[self deselectItemAtIndexPath:indexPath animated:animated sendDelegateMessage:self.sendsMultipleSelectionCalls];
	}
	if (!self.sendsMultipleSelectionCalls && _collectionViewFlags.delegateDidDeselectMult) {
		[self.delegate collectionView:self didDeselectItemsAtIndexPaths:[NSSet setWithArray:indexPaths]];
	}
	if (_collectionViewFlags.delegateDidSelectItemsChange) {
		[self.delegate collectionView:self selectedItemsChangedToIndexPaths:[NSSet setWithArray:[self selectedIndexes]]];
	}
}

- (void)selectItemsAtIndexPaths:(NSArray *)indexPaths animated:(BOOL)animated {
	for (NSIndexPath *indexPath in indexPaths) {
		[self selectItemAtIndexPath:indexPath animated:animated sendDelegateMessage:self.sendsMultipleSelectionCalls];
	}
	if (!self.sendsMultipleSelectionCalls && _collectionViewFlags.delegateDidSelectMult) {
		[self.delegate collectionView:self didSelectItemsAtIndexPaths:[NSSet setWithArray:indexPaths]];
	}
	if (_collectionViewFlags.delegateDidSelectItemsChange) {
		[self.delegate collectionView:self selectedItemsChangedToIndexPaths:[NSSet setWithArray:indexPaths]];
	}
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated sendDelegateMessage:(BOOL)shouldSendDelegateMessage {
	if (indexPath == nil || !self.allowsSelection ||
		(_collectionViewFlags.delegateShouldDeselect && ![self.delegate collectionView:self shouldDeselectItemAtIndexPath:indexPath]) ||
		(!self.allowsEmptySelection && self.indexPathsForSelectedItems.count <= 1)) {
		return;
	}
	
	JNWCollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
	[cell setSelected:NO animated:self.animatesSelection];
	[self.selectedIndexes removeObject:indexPath];
	
	if (shouldSendDelegateMessage && _collectionViewFlags.delegateDidDeselect) {
		[self.delegate collectionView:self didDeselectItemAtIndexPath:indexPath];
	}
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated sendDelegateMessage:(BOOL)shouldSendDelegateMessage {
	if (indexPath == nil || !self.allowsSelection ||
		(_collectionViewFlags.delegateShouldSelect && ![self.delegate collectionView:self shouldSelectItemAtIndexPath:indexPath])) {
		return;
	}
	
	JNWCollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
	[cell setSelected:YES animated:self.animatesSelection];
	
	if (![self.selectedIndexes containsObject:indexPath])
		[self.selectedIndexes addObject:indexPath];
	
	if (shouldSendDelegateMessage && _collectionViewFlags.delegateDidSelect) {
		[self.delegate collectionView:self didSelectItemAtIndexPath:indexPath];
	}
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath
			 atScrollPosition:(JNWCollectionViewScrollPosition)scrollPosition
					 animated:(BOOL)animated {
	[self selectItemAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated selectionType:JNWCollectionViewSelectionTypeSingle];
}

- (NSIndexPath *)indexPathForNextSelectableItemAfterIndexPath:(NSIndexPath *)indexPath {
	if (indexPath == nil && [self validateIndexPath:[NSIndexPath jnw_indexPathForItem:0 inSection:0]]) {
		// Passing `nil` will select the very first index path
		return [NSIndexPath jnw_indexPathForItem:0 inSection:0];
	} else if (indexPath.jnw_item + 1 >= self.data.sections[indexPath.jnw_section].numberOfItems) {
		// Jump up to the next section
		NSIndexPath *newIndexPath = [NSIndexPath jnw_indexPathForItem:0 inSection:indexPath.jnw_section + 1];
		if ([self validateIndexPath:newIndexPath])
			return newIndexPath;
	} else {
		return [NSIndexPath jnw_indexPathForItem:indexPath.jnw_item + 1 inSection:indexPath.jnw_section];
	}
	return nil;
}

- (NSIndexPath *)indexPathForNextSelectableItemBeforeIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.jnw_item - 1 >= 0) {
		return [NSIndexPath jnw_indexPathForItem:indexPath.jnw_item - 1 inSection:indexPath.jnw_section];
	} else if(indexPath.jnw_section - 1 >= 0 && self.data.numberOfSections) {
		NSInteger numberOfItems = self.data.sections[indexPath.jnw_section - 1].numberOfItems;
		NSIndexPath *newIndexPath = [NSIndexPath jnw_indexPathForItem:numberOfItems - 1 inSection:indexPath.jnw_section - 1];
		if ([self validateIndexPath:newIndexPath])
			return newIndexPath;
	}
	return nil;
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath
			 atScrollPosition:(JNWCollectionViewScrollPosition)scrollPosition
					 animated:(BOOL)animated
				selectionType:(JNWCollectionViewSelectionType)selectionType {
	if (indexPath == nil)
		return;
	if ((!self.allowsMultipleSelection && selectionType != JNWCollectionViewSelectionTypeSingle))
		return;
	NSMutableSet *indexesToSelect = [NSMutableSet set];
	
	if (selectionType == JNWCollectionViewSelectionTypeSingle) {
		[indexesToSelect addObject:indexPath];
	} else if (selectionType == JNWCollectionViewSelectionTypeMultiple) {
		[indexesToSelect addObjectsFromArray:self.selectedIndexes];
		if ([indexesToSelect containsObject:indexPath]) {
			[indexesToSelect removeObject:indexPath];
		} else {
			[indexesToSelect addObject:indexPath];
		}
	} else if (selectionType == JNWCollectionViewSelectionTypeExtending) {
		// From what I have determined, this behavior should be as follows.
		// Take the index selected first, and select all items between there and the
		// last selected item.
		NSIndexPath *firstIndex = (self.selectedIndexes.count > 0 ? self.selectedIndexes[0] : nil);
		if (firstIndex != nil) {
			[indexesToSelect addObject:firstIndex];
			
			if (![firstIndex isEqual:indexPath]) {
				NSComparisonResult order = [firstIndex compare:indexPath];
				NSIndexPath *nextIndex = firstIndex;
				
				while (nextIndex != nil && ![nextIndex isEqual:indexPath]) {
					[indexesToSelect addObject:nextIndex];
					
					if (order == NSOrderedAscending) {
						nextIndex = [self indexPathForNextSelectableItemAfterIndexPath:nextIndex];
					} else if (order == NSOrderedDescending) {
						nextIndex = [self indexPathForNextSelectableItemBeforeIndexPath:nextIndex];
					}
				}
			}
		}
		
		[indexesToSelect addObject:indexPath];
	}
	
	NSMutableSet *indexesToDeselect = [NSMutableSet setWithArray:self.selectedIndexes];
	[indexesToDeselect minusSet:indexesToSelect];
	
	[self selectItemsAtIndexPaths:indexesToSelect.allObjects animated:animated];
	[self deselectItemsAtIndexPaths:indexesToDeselect.allObjects animated:animated];
	[self scrollToItemAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
	if (_collectionViewFlags.delegateDidSelectItemsChange) {
		[self.delegate collectionView:self selectedItemsChangedToIndexPaths:[NSSet setWithArray:self.selectedIndexes]];
	}
}

- (void)mouseDownInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event {
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    if (indexPath == nil) {
        NSLog(@"***index path not found for selection.");
    }
	if (_collectionViewFlags.delegateMouseDownWithEvent) {
		[self.delegate collectionView:self mouseDownInItemAtIndexPath:indexPath withEvent:event];
	} else if (_collectionViewFlags.delegateMouseDown) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[self.delegate collectionView:self mouseDownInItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
	}
    [self.window makeFirstResponder:self];
    
    // Detect if modifier flags are held down.
    // We prioritize the command key over the shift key.
    BOOL isSingleSelect = YES;
    if (self.allowsMultipleSelection) {
        if (event.modifierFlags & NSCommandKeyMask) {
            [self selectItemAtIndexPath:indexPath atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES selectionType:JNWCollectionViewSelectionTypeMultiple];
            isSingleSelect = NO;
        } else if (event.modifierFlags & NSShiftKeyMask) {
            [self selectItemAtIndexPath:indexPath atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES selectionType:JNWCollectionViewSelectionTypeExtending];
            isSingleSelect = NO;
        }
    }
    if (isSingleSelect) {
        [self selectItemAtIndexPath:indexPath atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES];
    }
}

- (void)mouseUpInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event {
	[self.window makeFirstResponder:self];
	
	NSIndexPath *indexPath = [self indexPathForCell:cell];
	if (indexPath == nil) {
		NSLog(@"***index path not found for selection.");
	}
	
	if (_collectionViewFlags.delegateMouseUpWithEvent) {
		[self.delegate collectionView:self mouseUpInItemAtIndexPath:indexPath withEvent:event];
	} else if (_collectionViewFlags.delegateMouseUp) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[self.delegate collectionView:self mouseUpInItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
	}
}

- (void)mouseMovedInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event {
	if (_collectionViewFlags.delegateMouseMoved) {
		NSIndexPath *indexPath = [self indexPathForCell:cell];
		[self.delegate collectionView:self mouseMovedInItemAtIndexPath:indexPath withEvent:event];
	}
    cell.hovered = YES;
}

- (void)mouseEnteredInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event {
	if (_collectionViewFlags.delegateMouseEntered) {
		NSIndexPath *indexPath = [self indexPathForCell:cell];
		[self.delegate collectionView:self mouseEnteredInItemAtIndexPath:indexPath withEvent:event];
	}
	
	[[self.visibleCellsMap allValues] enumerateObjectsUsingBlock:^(JNWCollectionViewCell *innerCell, NSUInteger index, BOOL *stop) {
        if (cell != innerCell) {
            innerCell.hovered = NO;
        }
	}];
	cell.hovered = YES;
}

- (void)mouseExitedInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event {
	if (_collectionViewFlags.delegateMouseExited) {
		NSIndexPath *indexPath = [self indexPathForCell:cell];
		[self.delegate collectionView:self mouseExitedInItemAtIndexPath:indexPath withEvent:event];
	}
	
	cell.hovered = NO;
}

- (void)doubleClickInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event {
	if (_collectionViewFlags.delegateDidDoubleClick) {
		NSIndexPath *indexPath = [self indexPathForCell:cell];
		[self.delegate collectionView:self didDoubleClickItemAtIndexPath:indexPath];
	}
}

- (void)rightClickInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event {
	if (_collectionViewFlags.delegateDidRightClick) {
		NSIndexPath *indexPath = [self indexPathForCell:cell];
		[self.delegate collectionView:self didRightClickItemAtIndexPath:indexPath];
	}
}

- (void)moveUp:(id)sender {
	NSIndexPath *toSelect = [self.collectionViewLayout indexPathForNextItemInDirection:JNWCollectionViewDirectionUp currentIndexPath:[self indexPathForSelectedItem]];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES];
}

- (void)moveUpAndModifySelection:(id)sender {
	NSIndexPath *toSelect = [self.collectionViewLayout indexPathForNextItemInDirection:JNWCollectionViewDirectionUp currentIndexPath:[self indexPathForSelectedItem]];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES selectionType:JNWCollectionViewSelectionTypeExtending];
}

- (void)moveDown:(id)sender {
	NSIndexPath *toSelect = [self.collectionViewLayout indexPathForNextItemInDirection:JNWCollectionViewDirectionDown currentIndexPath:[self indexPathForSelectedItem]];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES];
}

- (void)moveDownAndModifySelection:(id)sender {
	NSIndexPath *toSelect = [self.collectionViewLayout indexPathForNextItemInDirection:JNWCollectionViewDirectionDown currentIndexPath:[self indexPathForSelectedItem]];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES selectionType:JNWCollectionViewSelectionTypeExtending];
}

- (void)moveRight:(id)sender {
	NSIndexPath *toSelect = [self.collectionViewLayout indexPathForNextItemInDirection:JNWCollectionViewDirectionRight currentIndexPath:[self indexPathForSelectedItem]];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES];
}

- (void)moveRightAndModifySelection:(id)sender {
	NSIndexPath *toSelect = [self.collectionViewLayout indexPathForNextItemInDirection:JNWCollectionViewDirectionRight currentIndexPath:[self indexPathForSelectedItem]];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES selectionType:JNWCollectionViewSelectionTypeExtending];
}

- (void)moveLeft:(id)sender {
	NSIndexPath *toSelect = [self.collectionViewLayout indexPathForNextItemInDirection:JNWCollectionViewDirectionLeft currentIndexPath:[self indexPathForSelectedItem]];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES];
}

- (void)moveLeftAndModifySelection:(id)sender {
	NSIndexPath *toSelect = [self.collectionViewLayout indexPathForNextItemInDirection:JNWCollectionViewDirectionLeft currentIndexPath:[self indexPathForSelectedItem]];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES selectionType:JNWCollectionViewSelectionTypeExtending];
}

// TODO: make these ask the layout for "where's the beginning/end?" in case of non-ltr layouts
- (void)moveToBeginningOfDocument:(id)sender {
	NSIndexPath *toSelect = [self firstIndexPath];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES];
}

- (void)moveToEndOfDocument:(id)sender {
	NSIndexPath *toSelect = [self lastIndexPath];
	[self selectItemAtIndexPath:toSelect atScrollPosition:JNWCollectionViewScrollPositionNearest animated:YES];
}

- (void)selectAll:(id)sender {
	if (self.allowsMultipleSelection) {
		[self selectItemsAtIndexPaths:[self allIndexPaths] animated:YES];
		if (_collectionViewFlags.delegateDidSelectItemsChange) {
			[self.delegate collectionView:self selectedItemsChangedToIndexPaths:[NSSet setWithArray:self.selectedIndexes]];
		}
	}
}

- (void)deselectAllItems {
	[self deselectItemsAtIndexPaths:[self allIndexPaths] animated:YES];
	if (_collectionViewFlags.delegateDidSelectItemsChange) {
		[self.delegate collectionView:self selectedItemsChangedToIndexPaths:[NSSet setWithArray:self.selectedIndexes]];
	}
}

- (void)selectAllItems {
	[self selectAll:nil];
}

#pragma mark Drag and drop

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
	return NSDragOperationEvery;
}

- (void)mouseDraggedInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event {
    if (_collectionViewFlags.delegateMouseDragged) {
        NSIndexPath *indexPath = [self indexPathForCell:cell];
        [self.delegate collectionView:self mouseDraggedInItemAtIndexPath:indexPath withEvent:event];
    }
    if (self.dragDropDelegate) {
        // for some reason on El Capitan, this function is called 2x for 2 drag operations. On High Sierra, this is
        // only called once. Strange...
        BOOL didDragContextAlreadyExist = _dragContext != nil;
        if (!didDragContextAlreadyExist) {
            NSMutableArray *dragItems = [NSMutableArray arrayWithCapacity:self.selectedIndexes.count];
            if (_collectionViewFlags.dragDropDelegateAllowsDragDrop && ![self.dragDropDelegate collectionView:self shouldAllowDragDropForIndices:self.selectedIndexes]) {
                return;
            }
            for (NSIndexPath *indexPath in self.selectedIndexes) {
                id<NSPasteboardWriting> pasteboardWriter = [self.dragDropDelegate collectionView:self pasteboardWriterForItemAtIndexPath:indexPath];
                if (pasteboardWriter == nil) {
                    continue;
                }
                
                JNWCollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
                NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pasteboardWriter];
                dragItem.draggingFrame = [self convertRect:cell.frame fromView:self.documentView];
                dragItem.imageComponentsProvider = ^ {
                    NSImage *image = cell.draggingImageRepresentation;
                    NSSize size = image.size;
                    NSDraggingImageComponent *component = [[NSDraggingImageComponent alloc] initWithKey:NSDraggingImageComponentIconKey];
                    component.contents = image;
                    component.frame = NSMakeRect(0, 0, size.width, size.height);
                    return @[ component ];
                };
                [dragItems addObject:dragItem];
            }
            
            _dragContext = [[JNWCollectionViewDragContext alloc] init];
            [self.dragContext setDragPaths:[self.selectedIndexes copy]];
            if (![self beginDraggingSessionWithItems:dragItems event:event source:self]) {
                _dragContext = nil;
            }
        }
	}
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	//NSLog(@"Dragging entered");
	if (!self.dragContext) {
		// We've got a drag operation from outside the app.
		_dragContext = [[JNWCollectionViewDragContext alloc] init];
	}
	return [sender draggingSourceOperationMask]; // we're only supposed to return 1 NSDragOperation, but this could potentially return multiple. TODO:
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
	//NSLog(@"Dragging updated");
	NSPoint windowPoint = [sender draggingLocation];
	NSPoint viewPoint = [self.documentView convertPoint:windowPoint fromView:nil];
	JNWCollectionViewDropIndexPath *dropPath = [_collectionViewLayout dropIndexPathAtPoint:viewPoint];
	
	// Check whether the drop path has changed. Avoid repeated calls when both the old and new path are nil.
	if (![self.dragContext.dropPath isEqual:dropPath] && !(dropPath == nil && _dragContext.dropPath == nil)) {
		self.dragContext.dropPath = dropPath;
		[self.collectionViewLayout prepareLayout];
		[self updateDropMarker];
	}
	return [sender draggingSourceOperationMask]; // we're only supposed to return 1 NSDragOperation, but this could potentially return multiple. TODO:
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
	//NSLog(@"Dragging exited");
	// Drag has left the view. If it was an external drag operation, clean up
	// the context.
	if (!_dragContext.dragPaths) {
		_dragContext = nil;
		[self.collectionViewLayout prepareLayout];
		[self updateDropMarker];
	}
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	//NSLog(@"Dragging ended at point");
	if (self.dragContext) {
		_dragContext = nil;
		[self.collectionViewLayout prepareLayout];
		[self updateDropMarker];
	}
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
	return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	BOOL result = NO;
	//NSLog(@"Perform drag operation");
	if (self.dragContext) {
		NSArray *fromIndexPath = self.dragContext.dragPaths;
		JNWCollectionViewDropIndexPath *toIndexPath = self.dragContext.dropPath;
		
		_dragContext = nil;
		[self.collectionViewLayout prepareLayout];
		[self updateDropMarker];
		
		result = [self.dragDropDelegate collectionView:self performDragOperation:sender fromIndexPaths:fromIndexPath toIndexPath:toIndexPath];
	}
	
	return result;
}

- (void)updateDropMarker {
	if (_collectionViewFlags.dragDropDelegateDropMarker || _collectionViewFlags.dragDropDelegateDropMarkerForIndexPath) {
		JNWCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForDropMarker];
		NSView *markerView;
		if (attributes) {
			// Ideally, dropMarkerViewWithFrame would know the JNWCollectionViewDropRelation so that it could draw itself differently
			// depending on where the item should be dropped.
			if (_collectionViewFlags.dragDropDelegateDropMarkerForIndexPath) {
				markerView = [self.dragDropDelegate collectionView:self dropMarkerViewWithFrame:attributes.frame forIndexPath:self.dragContext.dropPath];
			}
			else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
				markerView = [self.dragDropDelegate collectionView:self dropMarkerViewWithFrame:attributes.frame];
#pragma clang diagnostic pop
			}
			markerView.alphaValue = attributes.alpha;
		} else {
			markerView = nil;
		}
		
		[self.dropMarker removeFromSuperview];
		if (markerView) {
			[self.documentView addSubview:markerView];
		}
		self.dropMarker = markerView;
	}
}

- (BOOL)wantsPeriodicDraggingUpdates {
	return YES;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
	if (_collectionViewFlags.delegateMenuForEvent) {
		NSMenu *menu = [self.delegate collectionView:self menuForEvent:event];
		return menu;
	}
	return nil;

}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p; frame = %@; layer = <%@: %p>; content offset: %@> collection view layout: %@",
			self.class, self, NSStringFromRect(self.frame), self.layer.class, self.layer,
			NSStringFromPoint(self.documentVisibleRect.origin), self.collectionViewLayout];
}

#pragma mark NSResponder

// TODO: make these ask the layout for "where's the beginning/end?" in case of non-ltr layouts
- (void)scrollToBeginningOfDocument:(id)sender {
	[self.clipView scrollRectToVisible:NSMakeRect(0, 0, 0, 0) animated:self.animatesSelection];
}

- (void)scrollToEndOfDocument:(id)sender {
	NSSize documentSize = ((JNWCollectionViewDocumentView *)self.clipView.documentView).frame.size;
	NSRect scrollToRect = NSMakeRect(documentSize.width, documentSize.height, 0, 0);
	[self.clipView scrollRectToVisible:scrollToRect animated:self.animatesSelection];
}

#pragma mark Insert & Delete

- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath*> *)insertedIndexPaths {
	[self.insertedItems addObjectsFromArray:insertedIndexPaths];
	[self animateUpdates:NULL];
}

- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath*> *)deletedIndexPaths {
	[self.deletedItems addObjectsFromArray:deletedIndexPaths];
	[self animateUpdates:NULL];
	
}

- (void)reloadItemsAtIndexPaths:(NSArray<NSIndexPath*> *)reloadedIndexPaths {
	for (NSIndexPath* indexPath in reloadedIndexPaths) {
		if ([self cellForItemAtIndexPath:indexPath] != nil) {
			[self removeAndEnqueueCellAtIndexPath:indexPath];
			[self addCellForIndexPath:indexPath];
		}
	}
}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
	self.willBeginBatchUpdates = YES;
	updates();
	self.willBeginBatchUpdates = NO;
	[self animateUpdates:completion];
}

- (void)restoreSelectionIfPossible:(NSArray *)indexPaths {
	[self deselectItemsAtIndexPaths:indexPaths animated:NO];
	for (NSIndexPath *indexPath in indexPaths) {
		BOOL sectionOutOfBounds = indexPath.jnw_section >= self.data.numberOfSections || indexPath.jnw_section < 0;
		if (sectionOutOfBounds) continue;
		JNWCollectionViewSection *section = &self.data.sections[(NSUInteger) indexPath.jnw_section];
		BOOL itemOutOfBounds = indexPath.jnw_item >= section->numberOfItems || indexPath.jnw_item < 0;
		if (itemOutOfBounds) continue;
		[self selectItemAtIndexPath:indexPath atScrollPosition:JNWCollectionViewScrollPositionNone animated:NO];
	}
	if (!self.selectedIndexes.count/* && !self.selectionCanBeEmpty*/) {
		[self selectItemAtIndexPath:[NSIndexPath jnw_indexPathForItem:0 inSection:0]
				   atScrollPosition:JNWCollectionViewScrollPositionNone animated:NO];
	}
}

- (void)animateUpdates:(void (^)(BOOL))completion {
	if (self.willBeginBatchUpdates) {
		return;
	}
	
	if (self.isAnimating) {
		NSLog(@"TODO: multiple simultaneous animations are not supported yet");
		return;
	}
	
	self.isAnimating = YES;
	NSArray *insertedIndexPaths = [self.insertedItems sortedArrayUsingSelector:@selector(compare:)];
	NSArray *deletedIndexPaths = self.deletedItems;
	
	// TODO: Use IndexSet?
	NSIndexPath*(^existingIndexPathMapping)(NSIndexPath*) = ^NSIndexPath*(NSIndexPath* oldIndexPath) {
		NSInteger newItem = oldIndexPath.jnw_item;
		for (NSIndexPath *deletedIndexPath in deletedIndexPaths) {
			if (deletedIndexPath.jnw_section == oldIndexPath.jnw_section && oldIndexPath.jnw_item > deletedIndexPath.jnw_item) {
				newItem--;
			}
		}
		for (NSIndexPath *insertedIndexPath in insertedIndexPaths) {
			if (insertedIndexPath.jnw_section == oldIndexPath.jnw_section && newItem >= insertedIndexPath.jnw_item) {
				newItem++;
			}
		}
		return [NSIndexPath jnw_indexPathForItem:newItem inSection:0];
	};
	
	
	NSArray* deletedCells = [deletedIndexPaths map:^id (id indexPath) {
								 JNWCollectionViewCell* cell = [self cellForItemAtIndexPath:indexPath];
								 [self.visibleCellsMap removeObjectForKey:indexPath];
								 return cell;
							 }];
	
	
	
	NSDictionary* dictionary = self.visibleCellsMap;
	self.visibleCellsMap = [[dictionary uint_dictionaryByMappingKeys:existingIndexPathMapping] mutableCopy];
	
	
	
	NSArray *sortedVisibleIndexPaths = [self.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)] ;
	NSMutableSet *visibleIndexPathsWithoutDeletions = [NSMutableSet setWithArray:sortedVisibleIndexPaths];
	[visibleIndexPathsWithoutDeletions minusSet:[NSSet setWithArray:deletedIndexPaths]];
	NSSet *oldVisibleItems = [visibleIndexPathsWithoutDeletions map:existingIndexPathMapping];
	
	
	// Add existing cells that were not visible before
	NSMutableSet* newVisibleItems = [NSMutableSet set];
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
		 // Animate in from the top
		 NSIndexPath* oldFirstVisibleIndexPath = sortedVisibleIndexPaths.firstObject;
		 NSInteger numberOfItemsToBeInsertedAtBeginning = existingIndexPathMapping(oldFirstVisibleIndexPath).jnw_item - oldFirstVisibleIndexPath.jnw_item;
		 if (numberOfItemsToBeInsertedAtBeginning > 0) {
			 for (NSUInteger i = 1; i <= numberOfItemsToBeInsertedAtBeginning; i++) {
				 NSIndexPath *oldIndexPath = [NSIndexPath jnw_indexPathForItem:oldFirstVisibleIndexPath.jnw_item-i inSection:0];
				 if (oldIndexPath.jnw_item < 0) continue;
				 NSIndexPath *indexPath = existingIndexPathMapping(oldIndexPath);
				 [self addCellForIndexPath:indexPath];
				 JNWCollectionViewCell* cell = [self cellForItemAtIndexPath:indexPath];
				 [self updateLayoutAttributesForCell:cell indexPath:oldIndexPath];
				 [newVisibleItems addObject:indexPath];
			 }
		 }
		 
		 // Animate in from the bottom
		 NSIndexPath* oldLastVisibleIndexPath = sortedVisibleIndexPaths.lastObject;
		 NSInteger numberOfItemsToBeInsertedAtEnd = oldLastVisibleIndexPath.jnw_item - existingIndexPathMapping(oldLastVisibleIndexPath).jnw_item;
		 if (numberOfItemsToBeInsertedAtEnd > 0) {
			 
			 for (NSUInteger i = 1; numberOfItemsToBeInsertedAtEnd > 0 && oldLastVisibleIndexPath.jnw_item+i < [self.data numberOfItemsInSection:0]; i++) {
				 NSIndexPath* oldIndexPath = [NSIndexPath jnw_indexPathForItem:oldLastVisibleIndexPath.jnw_item+i inSection:0];
				 
				 if (![deletedIndexPaths containsObject:oldIndexPath]) {
					 context.duration = 0;
					 NSIndexPath *indexPath = existingIndexPathMapping(oldIndexPath);
					 JNWCollectionViewCell *cell = [self addCellForIndexPath:indexPath];
					 [self updateLayoutAttributesForCell:cell indexPath:oldIndexPath];
					 [newVisibleItems addObject:indexPath];
					 numberOfItemsToBeInsertedAtEnd--;
				 }
			 }
		 }
	} completionHandler:^{self.selectedIndexes = [self.selectedIndexes map:existingIndexPathMapping].mutableCopy;
		[self.data recalculateAndPrepareLayout:YES];
		[self restoreSelectionIfPossible:[self.selectedIndexes copy]];
		
		NSArray *visibleIndexPaths = self.indexPathsForVisibleItems;
		
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
			context.duration = 0;
			for (NSIndexPath *indexPath in insertedIndexPaths) {
				if ([visibleIndexPaths containsObject:indexPath]) {
					[self addCellForIndexPath:indexPath];
					JNWCollectionViewCell* cell = [self cellForItemAtIndexPath:indexPath];
					cell.alphaValue = 0;
				}
			}
		} completionHandler:^{
			NSMutableArray *indexPathsToBeRemoved = [NSMutableArray array];
			NSSet *movingCells = [oldVisibleItems setByAddingObjectsFromSet:newVisibleItems];
			
			[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
				 context.allowsImplicitAnimation = YES;
				 
				 for (NSIndexPath *indexPath in movingCells) {
					 JNWCollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
					 [self updateCell:cell forIndexPath:indexPath];
					 [indexPathsToBeRemoved addObject:indexPath];
					 
				 }
				 
				 for(NSIndexPath *indexPath in insertedIndexPaths) {
					 if ([visibleIndexPaths containsObject:indexPath]) {
						 JNWCollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
						 cell.alphaValue = 1;
					 }
				 }
				 
				 for (JNWCollectionViewCell *cell in deletedCells) {
					 cell.alphaValue = 0;
				 }
				 
			 } completionHandler:^ {
				 NSArray *visibleItems = self.indexPathsForVisibleItems;
				 for (NSIndexPath *indexPath in indexPathsToBeRemoved) {
					 if (![visibleItems containsObject:indexPath]) {
						 [self removeAndEnqueueCellAtIndexPath:indexPath];
					 } else {
						 [self updateSelectionStateOfCell:[self cellForItemAtIndexPath:indexPath]];
					 }
				 }
				 for (JNWCollectionViewCell *cell in deletedCells) {
					 cell.alphaValue = 1;
					 [self enqueueReusableCell:cell withIdentifier:cell.reuseIdentifier];
					 [cell setHidden:YES];
				 }
				 self.isAnimating = NO;
				 [self layoutDocumentView];
				 // In theory, this layoutCellsWithRedraw: call shouldn't be necessary. Not sure what the problem is yet...
				 [self layoutCellsWithRedraw:YES];
				 if (completion != NULL) {
					 completion(YES);
				 }
			 }];
			
			[self.insertedItems removeAllObjects];
			[self.deletedItems removeAllObjects];
		}];
	}];
}


@end
