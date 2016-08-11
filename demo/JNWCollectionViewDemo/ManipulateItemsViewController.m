//
//  ManipulateItemsViewController.m
//  JNWCollectionViewDemo
//
//  Created by Deadpikle on 8/10/16.
//  Copyright © 2016 AppJon. All rights reserved.
//

#import "ManipulateItemsViewController.h"

#import "ListCell.h"
#import "GridCell.h"

@interface ManipulateItemsViewController()

@property (nonatomic, weak) IBOutlet JNWCollectionView *collectionView;
@property (nonatomic, weak) IBOutlet JNWCollectionView *listView;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSMutableArray *listItems;
@property NSUInteger listItemCounter;

- (IBAction)addItem:(id)sender;
- (IBAction)removeItem:(id)sender;
- (IBAction)clearAllItems:(id)sender;

@end

static NSString * const identifier = @"CELL";
static NSString * const listCellIdentifier = @"LISTCELL";

@implementation ManipulateItemsViewController

- (id)init {
	return [self initWithNibName:NSStringFromClass(self.class) bundle:nil];
}

- (void)awakeFromNib {
	self.listItemCounter = 1;
	self.items = [NSMutableArray array];
	self.listItems = [NSMutableArray array];
	for (NSUInteger i = 0; i < 5; i++) {
		[self.items addObject:[self generateSingleImage]];
		[self.listItems addObject:[NSString stringWithFormat:@"%lu", (unsigned long)self.listItemCounter++]];
	}
	
	JNWCollectionViewGridLayout *gridLayout = [[JNWCollectionViewGridLayout alloc] init];
	gridLayout.delegate = self;
	gridLayout.verticalSpacing = 10.f;
	
	self.collectionView.collectionViewLayout = gridLayout;
	self.collectionView.delegate = self;
	self.collectionView.dataSource = self;
	self.collectionView.animatesSelection = NO; // (this is the default option)
	[self.collectionView registerClass:GridCell.class forCellWithReuseIdentifier:identifier];
	
	JNWCollectionViewListLayout *listLayout = [[JNWCollectionViewListLayout alloc] init];
	listLayout.rowHeight = 44.f;
	//layout.delegate = self;
	self.listView.collectionViewLayout = listLayout;
	self.listView.delegate = self;
	self.listView.dataSource = self;
	self.listView.animatesSelection = NO;
	[self.listView registerClass:ListCell.class forCellWithReuseIdentifier:listCellIdentifier];
	
	[self.collectionView reloadData];
	[self.listView reloadData];
}

#pragma mark JNWCollectionView Delegate

#pragma mark Data source

- (JNWCollectionViewCell *)collectionView:(JNWCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	if (collectionView == self.collectionView) {
		GridCell *cell = (GridCell *)[collectionView dequeueReusableCellWithIdentifier:identifier];
		cell.image = self.items[indexPath.jnw_item];
		return cell;
	}
	else {
		ListCell *cell = (ListCell *)[collectionView dequeueReusableCellWithIdentifier:listCellIdentifier];
		cell.cellLabelText = self.listItems[indexPath.jnw_item];
		return cell;
	}
}

- (NSInteger)numberOfSectionsInCollectionView:(JNWCollectionView *)collectionView {
	return 1;
}

- (NSUInteger)collectionView:(JNWCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	if (collectionView == self.collectionView) {
		return self.items.count;
	}
	else {
		return self.listItems.count;
	}
}

- (CGSize)sizeForItemInCollectionView:(JNWCollectionView *)collectionView {
	return CGSizeMake(100, 100);
}

#pragma mark Image creation

- (NSImage *)generateSingleImage {
	return [NSImage imageWithSize:CGSizeMake(150.f, 150.f) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		[[NSImage imageNamed:NSImageNameUser] drawInRect:dstRect fromRect:CGRectZero operation:NSCompositeSourceOver fraction:1];
		
		CGFloat hue = arc4random() % 256 / 256.0;
		CGFloat saturation = arc4random() % 128 / 256.0 + 0.5;
		CGFloat brightness = arc4random() % 128 / 256.0 + 0.5;
		NSColor *color = [NSColor colorWithCalibratedHue:hue saturation:saturation brightness:brightness alpha:1];
		
		[color set];
		NSRectFillUsingOperation(dstRect, NSCompositeDestinationAtop);
		
		return YES;
	}];
}

- (NSArray *)draggedTypesForCollectionView:(JNWCollectionView *)collectionView {
	return @[ NSStringPboardType ];
}

- (id<NSPasteboardWriting>)collectionView:(JNWCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath {
	NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];
	[pboardItem setString:[NSString stringWithFormat:@"%ld - %ld", (long)indexPath.jnw_section, (long)indexPath.jnw_item] forType:NSPasteboardTypeString];
	return pboardItem;
}

- (IBAction)addItem:(id)sender {
	[self.items insertObject:[self generateSingleImage] atIndex:0];
	[self.collectionView insertItemsAtIndexPaths:@[[NSIndexPath jnw_indexPathForItem:0 inSection:0]]];
	
	[self.listItems insertObject:[NSString stringWithFormat:@"%lu", (unsigned long)self.listItemCounter++] atIndex:0];
	[self.listView insertItemsAtIndexPaths:@[[NSIndexPath jnw_indexPathForItem:0 inSection:0]]];
}

- (IBAction)removeItem:(id)sender {
	if (self.items.count) {
		[self.items removeObjectAtIndex:0];
		[self.collectionView deleteItemsAtIndexPaths:@[[NSIndexPath jnw_indexPathForItem:0 inSection:0]]];
	}
	if (self.listItems.count) {
		[self.listItems removeObjectAtIndex:0];
		[self.listView deleteItemsAtIndexPaths:@[[NSIndexPath jnw_indexPathForItem:0 inSection:0]]];
	}
}

- (IBAction)clearAllItems:(id)sender {
	if (self.items.count) {
		NSMutableArray *indexPaths = [NSMutableArray array];
		for (NSUInteger i = 0; i < self.items.count; i++) {
			[indexPaths addObject:[NSIndexPath jnw_indexPathForItem:i inSection:0]];
		}
		[self.items removeAllObjects];
		[self.collectionView deleteItemsAtIndexPaths:indexPaths];
	}
	if (self.listItems.count) {
		NSMutableArray *indexPaths = [NSMutableArray array];
		for (NSUInteger i = 0; i < self.listItems.count; i++) {
			[indexPaths addObject:[NSIndexPath jnw_indexPathForItem:i inSection:0]];
		}
		[self.listItems removeAllObjects];
		[self.listView deleteItemsAtIndexPaths:indexPaths];
	}
}
@end
