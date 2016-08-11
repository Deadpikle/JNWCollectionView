//
//  ManipulateItemsViewController.m
//  JNWCollectionViewDemo
//
//  Created by Deadpikle on 8/10/16.
//  Copyright © 2016 AppJon. All rights reserved.
//

#import "ManipulateItemsViewController.h"

#import "GridCell.h"

@interface ManipulateItemsViewController()

@property (nonatomic, weak) IBOutlet JNWCollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *items;

- (IBAction)addItem:(id)sender;
- (IBAction)removeItem:(id)sender;
- (IBAction)clearAllItems:(id)sender;

@end

static NSString * const identifier = @"CELL";

@implementation ManipulateItemsViewController

- (id)init {
	return [self initWithNibName:NSStringFromClass(self.class) bundle:nil];
}

- (void)awakeFromNib {
	self.items = [NSMutableArray array];
	for (NSUInteger i = 0; i < 5; i++) {
		[self.items addObject:[self generateSingleImage]];
	}
	
	JNWCollectionViewGridLayout *gridLayout = [[JNWCollectionViewGridLayout alloc] init];
	gridLayout.delegate = self;
	gridLayout.verticalSpacing = 10.f;
	
	self.collectionView.collectionViewLayout = gridLayout;
	self.collectionView.delegate = self;
	self.collectionView.dataSource = self;
	self.collectionView.animatesSelection = NO; // (this is the default option)
	
	[self.collectionView registerClass:GridCell.class forCellWithReuseIdentifier:identifier];
	
	[self.collectionView reloadData];
}

#pragma mark JNWCollectionView Delegate

#pragma mark Data source

- (JNWCollectionViewCell *)collectionView:(JNWCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	GridCell *cell = (GridCell *)[collectionView dequeueReusableCellWithIdentifier:identifier];
	cell.image = self.items[indexPath.jnw_item];
	return cell;
}

- (NSInteger)numberOfSectionsInCollectionView:(JNWCollectionView *)collectionView {
	return 1;
}

- (NSUInteger)collectionView:(JNWCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return self.items.count;
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
}

- (IBAction)removeItem:(id)sender {
	if (self.items.count) {
		[self.items removeObjectAtIndex:0];
		[self.collectionView deleteItemsAtIndexPaths:@[[NSIndexPath jnw_indexPathForItem:0 inSection:0]]];
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
}
@end
