//
//  GridDemoViewController.m
//  JNWCollectionViewDemo
//
//  Created by Jonathan Willing on 4/15/13.
//  Copyright (c) 2013 AppJon. All rights reserved.
//

#import "GridDemoViewController.h"
#import "GridCell.h"
#import "ListMarker.h"

@interface GridDemoViewController() <JNWCollectionViewDelegate, JNWCollectionViewDragDropDelegate>
@property (nonatomic, strong) NSMutableArray *images;
@property (nonatomic, strong) IBOutlet NSSlider *sizeSlider;
@end

static NSString * const identifier = @"CELL";

@implementation GridDemoViewController

- (id)init {
	return [self initWithNibName:NSStringFromClass(self.class) bundle:nil];
}

- (void)awakeFromNib {
	[self generateImages];
	
	JNWCollectionViewGridLayout *gridLayout = [[JNWCollectionViewGridLayout alloc] init];
	gridLayout.delegate = self;
	gridLayout.verticalSpacing = 10.f;
    gridLayout.shouldAutoScroll = YES;
	
	self.collectionView.collectionViewLayout = gridLayout;
    self.collectionView.delegate = self;
	self.collectionView.dataSource = self;
    self.collectionView.dragDropDelegate = self;
	self.collectionView.animatesSelection = NO; // (this is the default option)
    //self.collectionView.allowsMultipleSelection = NO; // uncomment to only allow single selection of one item
    self.collectionView.sendsMultipleSelectionCalls = NO;
	
	[self.collectionView registerClass:GridCell.class forCellWithReuseIdentifier:identifier];
	
	[self.collectionView reloadData];
}

- (IBAction)updateSizeSliderValue:(id)sender {
	[self.collectionView.collectionViewLayout invalidateLayout];
}

- (NSView *)collectionView:(JNWCollectionView *)collectionView dropMarkerViewWithFrame:(NSRect)frame forIndexPath:(JNWCollectionViewDropIndexPath *)indexPath {
    frame.size.width += 2;
    frame.origin.x -= 5;
    ListMarker *marker = [[ListMarker alloc] initWithFrame:frame];
    [marker setColor:[NSColor blueColor]];
    return marker;
}

#pragma mark JNWCollectionView Delegate

- (void)collectionView:(JNWCollectionView *)collectionView selectedItemsChangedToIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    //NSLog(@"%ld items are selected", [collectionView.indexPathsForSelectedItems count]); // this count is always accurate
}

#pragma mark Data source

- (JNWCollectionViewCell *)collectionView:(JNWCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	GridCell *cell = (GridCell *)[collectionView dequeueReusableCellWithIdentifier:identifier];
	cell.image = self.images[indexPath.jnw_item % self.images.count];
	return cell;
}

- (NSInteger)numberOfSectionsInCollectionView:(JNWCollectionView *)collectionView {
	return 5;
}

- (NSUInteger)collectionView:(JNWCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return 500;
}

- (CGSize)sizeForItemInCollectionView:(JNWCollectionView *)collectionView {
	CGFloat sizeSliderValue = self.sizeSlider.floatValue;
	return CGSizeMake(sizeSliderValue, sizeSliderValue);
}

#pragma mark Image creation

// To simulate at least something realistic, this just generates some randomly tinted images so that not every
// cell has the same image.
- (void)generateImages {
	NSInteger numberOfImages = 30;
	NSMutableArray *images = [NSMutableArray array];
	
	for (int i = 0; i < numberOfImages; i++) {
		
		// Just get a randomly-tinted template image.
		NSImage *image = [NSImage imageWithSize:CGSizeMake(150.f, 150.f) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
			[[NSImage imageNamed:NSImageNameUser] drawInRect:dstRect fromRect:CGRectZero operation:NSCompositingOperationSourceOver fraction:1];
			
			CGFloat hue = arc4random() % 256 / 256.0;
			CGFloat saturation = arc4random() % 128 / 256.0 + 0.5;
			CGFloat brightness = arc4random() % 128 / 256.0 + 0.5;
			NSColor *color = [NSColor colorWithCalibratedHue:hue saturation:saturation brightness:brightness alpha:1];
			
			[color set];
			NSRectFillUsingOperation(dstRect, NSCompositingOperationDestinationAtop);
			
			return YES;
		}];
		
		[images addObject:image];
	}
	
	self.images = images;
}

- (NSArray *)draggedTypesForCollectionView:(JNWCollectionView *)collectionView {
    return @[ NSStringPboardType ];
}

- (BOOL)collectionView:(JNWCollectionView *)collectionView performDragOperation:(id<NSDraggingInfo>)sender fromIndexPaths:(NSArray *)dragIndexPaths toIndexPath:(JNWCollectionViewDropIndexPath *)dropIndexPath {
    if ([dragIndexPaths count] > 0 && dropIndexPath) {
        // TODO: update demo to allow for multiple item movement
        long fromIndex = ((NSIndexPath*)dragIndexPaths[0]).jnw_item % 30;
        long toIndex = dropIndexPath.jnw_item % 30;
        // moving to the right? must adjust index to be one less because we erase an item before inserting an item.
        long finalDesination = toIndex;
        if (toIndex > fromIndex && dropIndexPath.jnw_relation != JNWCollectionViewDropRelationAfter) {
            finalDesination = toIndex - 1;
        }
        if (fromIndex != finalDesination) {
            NSImage *image = [self.images objectAtIndex:fromIndex];
            [self.images removeObjectAtIndex:fromIndex];
            [self.images insertObject:image atIndex:finalDesination];
            [self.collectionView reloadData];
            return YES;
        }
    }
    return NO;
}

- (id<NSPasteboardWriting>)collectionView:(JNWCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];
    [pboardItem setString:[NSString stringWithFormat:@"%ld - %ld", (long)indexPath.jnw_section, (long)indexPath.jnw_item] forType:NSPasteboardTypeString];
    return pboardItem;
}

@end
