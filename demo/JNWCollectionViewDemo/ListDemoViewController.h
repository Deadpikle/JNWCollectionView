//
//  ListDemoViewController.h
//  JNWCollectionViewDemo
//
//  Created by Jonathan Willing on 4/12/13.
//  Copyright (c) 2013 AppJon. All rights reserved.
//
// Drag and drop implementation modified from https://github.com/DarkDust/JNWCollectionView (MIT licensed)

#import <Cocoa/Cocoa.h>
#import <JNWCollectionView/JNWCollectionView.h>

@interface ListDemoViewController : NSViewController <JNWCollectionViewDataSource, JNWCollectionViewListLayoutDelegate, JNWCollectionViewDragDropDelegate>

@end
