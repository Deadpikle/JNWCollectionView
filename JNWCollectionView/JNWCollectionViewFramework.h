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

#import <Cocoa/Cocoa.h>
#import "JNWCollectionViewCell.h"
#import "JNWCollectionViewReusableView.h"
#import "NSIndexPath+JNWAdditions.h"
#if defined(COCOAPODS)
#import <JNWScrollView/JNWScrollView.h>
#else
#import "JNWScrollView.h"
#import "JNWCollectionViewDragContext.h"
#endif

typedef NS_ENUM(NSInteger, JNWCollectionViewScrollPosition) {
	/// Does not scroll, only selects.
	JNWCollectionViewScrollPositionNone,
	/// Scrolls the minimum amount necessary to make visible.
	JNWCollectionViewScrollPositionNearest,
	/// Scrolls the rect to be at the top of the screen, if possible.
	JNWCollectionViewScrollPositionTop,
	/// Center the rect in the center of the screen, if possible.
	JNWCollectionViewScrollPositionMiddle,
	/// Scrolls the rect to be at the bottom of the screen, if possible.
	JNWCollectionViewScrollPositionBottom
};

@class JNWCollectionView;

#pragma mark - Data Source Protocol

/// The data source is the protocol which defines a set of methods for both information about the data model
/// and the views needed for creating the collection view.
///
/// The object that conforms to the data source must implement both `-collectionView:numberOfItemsInSection:`
/// and `-collectionView:cellForItemAtIndexPath:`, otherwise an exception will be thrown.
@protocol JNWCollectionViewDataSource <NSObject>

/// Asks the data source how many items are in the section index specified. The first section begins at 0.
///
/// Required.
- (NSUInteger)collectionView:(JNWCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;

/// Asks the data source for the view that should be used for the cell at the specified index path. The returned
/// view must be non-nil, and it must be a subclass of JNWCollectionViewCell, otherwise an exception will be thrown.
///
/// Required.
- (JNWCollectionViewCell *)collectionView:(JNWCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;

@optional
/// Asks the data source for the number of sections in the collection view.
///
/// If this method is not implemented, the collection view will default to 1 section.
- (NSInteger)numberOfSectionsInCollectionView:(JNWCollectionView *)collectionView;

/// Asks the data source for the view used for the supplementary view for the specified section. The returned
/// view must be a subclass of JNWCollectionViewReusableView, otherwise an exception will be thrown.
///
/// Note that this data source method will *not* be called unless a class has been registered for a supplementary
/// view kind. So if you wish to use supplementary views, you must register at least one class using
/// -registerClass:forSupplementaryViewOfKind:withReuseIdentifier:.
- (JNWCollectionViewReusableView *)collectionView:(JNWCollectionView *)collectionView viewForSupplementaryViewOfKind:(NSString *)kind inSection:(NSInteger)section;

@end

#pragma mark Delegate Protocol

/// The delegate is the protocol which defines a set of methods with information about mouse clicks and selection.
///
/// All delegate methods are optional.
@protocol JNWCollectionViewDelegate <NSObject>

@optional
/// Tells the delegate that the mouse is down inside of the item at the specified index path with triggering event.
- (void)collectionView:(JNWCollectionView *)collectionView mouseDownInItemAtIndexPath:(NSIndexPath *)indexPath withEvent:(NSEvent *)event;

/// Tells the delegate that the mouse click originating from the item at the specified index path is now up with triggering event.
///
/// The mouse up event can occur outside of the originating cell.
- (void)collectionView:(JNWCollectionView *)collectionView mouseUpInItemAtIndexPath:(NSIndexPath *)indexPath withEvent:(NSEvent *)event;

- (void)collectionView:(JNWCollectionView *)collectionView mouseDownInItemAtIndexPath:(NSIndexPath *)indexPath __deprecated_msg("Use collectionView:mouseDownInItemAtIndexPath:withEvent: instead.");
- (void)collectionView:(JNWCollectionView *)collectionView mouseUpInItemAtIndexPath:(NSIndexPath *)indexPath __deprecated_msg("Use collectionView:mouseUpInItemAtIndexPath:withEvent: instead.");

/// Tells the delegate that the mouse moved inside the specified index path cell.
- (void)collectionView:(JNWCollectionView *)collectionView mouseMovedInItemAtIndexPath:(NSIndexPath *)indexPath withEvent:(NSEvent *)event;

/// Tells the delegate that the mouse started a drag session inside the specified index path cell.
- (void)collectionView:(JNWCollectionView *)collectionView mouseDraggedInItemAtIndexPath:(NSIndexPath *)indexPath withEvent:(NSEvent *)event;

/// Tells the delegate that the mouse entered in the specified index path cell.
- (void)collectionView:(JNWCollectionView *)collectionView mouseEnteredInItemAtIndexPath:(NSIndexPath *)indexPath withEvent:(NSEvent *)event;

/// Tells the delegate that the mouse exited from the specified index path cell.
- (void)collectionView:(JNWCollectionView *)collectionView mouseExitedInItemAtIndexPath:(NSIndexPath *)indexPath withEvent:(NSEvent *)event;

/// Asks the delegate if the item at the specified index path should be selected.
- (BOOL)collectionView:(JNWCollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath;

/// Tells the delegate that the item at the specified index path has been selected.
- (void)collectionView:(JNWCollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;

/// Tells the delegate that the item(s) at the specified index path have been selected.
- (void)collectionView:(JNWCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths;

/// Asks the delegate if the item at the specified index path should be deselected.
- (BOOL)collectionView:(JNWCollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath;

/// Tells the delegate that the item at the specified index path has been deselected.
- (void)collectionView:(JNWCollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath;

/// Tells the delegate that the item(s) at the specified index path have been deselected.
- (void)collectionView:(JNWCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths;

/// Tells the delegate that the number of selected items have changed to the given index path(s).
- (void)collectionView:(JNWCollectionView *)collectionView selectedItemsChangedToIndexPaths:(NSSet<NSIndexPath *> *)indexPaths;

/// Tells the delegate that the item at the specified index path has been double-clicked.
- (void)collectionView:(JNWCollectionView *)collectionView didDoubleClickItemAtIndexPath:(NSIndexPath *)indexPath;

/// Tells the delegate that the item at the specified index path has been right-clicked.
- (void)collectionView:(JNWCollectionView *)collectionView didRightClickItemAtIndexPath:(NSIndexPath *)indexPath;

/// Asks the delegate if the item at the specified index path should be scrolled to.
- (BOOL)collectionView:(JNWCollectionView *)collectionView shouldScrollToItemAtIndexPath:(NSIndexPath *)indexPath;

/// Tells the delegate that the specified index path has been scrolled to.
- (void)collectionView:(JNWCollectionView *)collectionView didScrollToItemAtIndexPath:(NSIndexPath *)indexPath;

/// Tells the delegate that the cell for the specified index path has been put
/// back into the reuse queue.
- (void)collectionView:(JNWCollectionView *)collectionView didEndDisplayingCell:(JNWCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;

/// Asks the delegate if a contextual menu should be used for the given event.
- (NSMenu *)collectionView:(JNWCollectionView *)collectionView menuForEvent:(NSEvent *)event;

/// Asks the delegate for an objectValue for the JNWCollectionViewCell at the given indexPath.
/// The objectValue object is used for data binding. 
- (id)collectionView:(JNWCollectionView *)collectionView objectValueForItemAtIndexPath:(NSIndexPath *)indexPath;

@end

#pragma mark Drag and Drop Delegate Protocol

@protocol JNWCollectionViewDragDropDelegate <NSObject>

@required

/// Asks the data source which UTI (uniform type identifiers) to support.
- (NSArray *)draggedTypesForCollectionView:(JNWCollectionView *)collectionView;

/// Asks the data source to conclude the drag and drop operation at the specified index path.
///
/// See -[NSDraggingDestination performDragOperation:] for details about the sender and return value semenatics.
///
/// The dragIndexPaths array may be nil or empty if the the drag started outside the view or application.
/// The dropIndexPath specifies where the user wants to drag to. See JNWCollectionViewDropIndexPath for more details.
- (BOOL)collectionView:(JNWCollectionView *)collectionView performDragOperation:(id<NSDraggingInfo>)sender fromIndexPaths:(NSArray *)dragIndexPaths toIndexPath:(JNWCollectionViewDropIndexPath *)dropIndexPath;

/// Asks the data source for a pasteboard representation of the item at the specified index path.
- (id<NSPasteboardWriting>)collectionView:(JNWCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath;

@optional

- (BOOL)collectionView:(JNWCollectionView *)collectionView shouldAllowDragDropForIndices:(NSArray *)dragIndexPaths;

/// Asks the data source to return an appropriate view for marking a drop location.
/// The returned view may have a different frame but should somehow emphasize the specified frame.
/// Ideally, dropMarkerViewWithFrame would know the JNWCollectionViewDropRelation so that it could draw itself differently
/// depending on where the item should be dropped. Unfortunately, that's still a TODO:. 
- (NSView *)collectionView:(JNWCollectionView *)collectionView dropMarkerViewWithFrame:(NSRect)frame forIndexPath:(JNWCollectionViewDropIndexPath*)indexPath;

- (NSView *)collectionView:(JNWCollectionView *)collectionView dropMarkerViewWithFrame:(NSRect)frame __deprecated_msg("Use collectionView:dropMarkerViewWithFrame:forIndexPath: instead.");

@end

#pragma mark Reloading and customizing

@class JNWCollectionViewLayout;
@interface JNWCollectionView : JNWScrollView 

/// The delegate for the collection view.
@property (nonatomic, unsafe_unretained) IBOutlet id<JNWCollectionViewDelegate> delegate;

/// The data source for the collection view.
///
/// Required.
@property (nonatomic, unsafe_unretained) IBOutlet id<JNWCollectionViewDataSource> dataSource;

@property (nonatomic, unsafe_unretained) IBOutlet id<JNWCollectionViewDragDropDelegate> dragDropDelegate;

/// Calling this method will cause the collection view to clean up all the views and
/// recalculate item info. It will then perform a layout pass.
///
/// This method should be called after the data source has been set and initial setup on the collection
/// view has been completed.
- (void)reloadData;

/// In order for cell or supplementary view dequeueing to occur, a class must be registered with the appropriate
/// registration method.
///
/// The class passed in will be used to initialize a new instance of the view, as needed. The class
/// must be a subclass of JNWCollectionViewCell for the cell class, and JNWCollectionViewReusableView
/// for the supplementary view class, otherwise an exception will be thrown.
///
/// Registering a class or nib are exclusive: registering one will unregister the other.
- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)reuseIdentifier;
- (void)registerClass:(Class)supplementaryViewClass forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)reuseIdentifier;

/// You can also register a nib instead of a class to be able to dequeue a cell or supplementary view.
///
/// The nib must contain a top-level object of a subclass of JNWCollectionViewCell for the cell, and
/// JNWCollectionViewReusableView for the supplementary view, otherwise an exception will be thrown when dequeuing.
///
/// Registering a class or nib are exclusive: registering one will unregister the other.
- (void)registerNib:(NSNib *)cellNib forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(NSNib *)supplementaryViewNib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)reuseIdentifier;

/// These methods are used to create or reuse a new view. Cells should not be created manually. Instead,
/// these methods should be called with a reuse identifier previously registered using
/// -registerClass:forCellWithReuseIdentifier: or -registerClass:forSupplementaryViewOfKind:withReuseIdentifier:.
///
/// If a class was not previously registered, the base cell class will be used to create the view.
/// However, for supplementary views, the class must be registered, otherwise the collection view
/// will not attempt to load any supplementary views for that kind.
///
/// The identifer must not be nil, otherwise an exception will be thrown.
- (JNWCollectionViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier;
- (JNWCollectionViewReusableView *)dequeueReusableSupplementaryViewOfKind:(NSString *)kind withReuseIdentifer:(NSString *)identifier;

/// The layout is responsible for providing the positioning and layout attributes for cells and views.
/// It is also responsible for handling selection changes that are performed via the keyboard. See the
/// documentation in JNWCollectionViewLayout.h.
///
/// A valid layout must be set before calling -reloadData, otherwise an exception will be thrown.
///
/// Layouts must not be reused between separate collection view instances. A single layout can be
/// associated with only one collection view at any given time.
///
/// Defaults to nil.
@property (nonatomic, strong) JNWCollectionViewLayout *collectionViewLayout;

/// The background color determines what is drawn underneath any cells that might be visible
/// at the time. If this is a repeating pattern image, it will scroll along with the content.
///
/// Defaults to a white color.
@property (copy) NSColor *backgroundColor;

/// Whether or not the collection view draws the background color. If the collection view
/// background color needs to be transparent, this should be disabled.
///
/// Defaults to YES.
@property (assign) BOOL drawsBackground;

/// When the user selects more than one item at once (such as via the command key or shift key), the delegate method(s)
/// for didSelect/didDeselect are called multiple times, one for each item. This can be problematic if the user needs
/// an accurate count for indexPathsForSelectedItems when didSelect/didDeselect is called, as the user does not know when the last
/// delegate callback has been made.
/// If this property is set to NO, instead of performing multiple calls, the JNWCollectionView will make one (single)
/// callback to the client to the delegate method(s) didSelectItems/didDeselectItems. When the didDeselectItems
/// callback has been made, the indexPathsForSelectedItems will have an accurate count.
/// If you want to have an accurate count after all selection changes have occurred and do not care about selection/deselection,
/// use the collectionView:selectedItemsChangedToIndexPaths delegate method.
/// Note that when this property is set to NO, the methods for single selection/deselection will not be called.
/// This option defaults to YES for legacy applications.
@property (assign) BOOL sendsMultipleSelectionCalls;

#pragma mark - Information

/// Returns the total number of sections.
- (NSInteger)numberOfSections;

/// Returns the number of items in the specified section.
- (NSInteger)numberOfItemsInSection:(NSInteger)section;

/// The following methods will return frames in flipped coordinates, where the origin is the
/// top left point in the scroll view. All of these methods will return CGRectZero if an invalid
/// index path or section is specified.
- (CGRect)rectForItemAtIndexPath:(NSIndexPath *)indexPath;
- (CGRect)rectForSupplementaryViewWithKind:(NSString *)kind inSection:(NSInteger)section;
- (CGRect)rectForSection:(NSInteger)section; /// the frame encompassing the cells and views in the specified section

/// Provides the size of the visible document area in which the collection view is currently
/// displaying cells and other supplementary views.
///
/// Equivalent to the size of -documentVisibleRect.
@property (nonatomic, assign, readonly) CGSize visibleSize;

/// Returns the index path for the item at the specified point, otherwise nil if no item is found.
- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point;

/// Returns the index path for the specified cell, otherwise returns nil if the cell isn't visible.
- (NSIndexPath *)indexPathForCell:(JNWCollectionViewCell *)cell;

/// Returns an array of all of the index paths contained within the specified frame.
- (NSArray *)indexPathsForItemsInRect:(CGRect)rect;

/// Returns an index set containing the indexes for all sections that intersect the specified rect.
- (NSIndexSet *)indexesForSectionsInRect:(CGRect)rect;

/// Returns the cell at the specified index path, otherwise returns nil if the index path
/// is invalid or if the cell is not visible.
- (JNWCollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;

/// Returns the supplementary view of the specified kind and reuse identifier in the section, otherwise returns nil if
/// the supplementary view is no longer visible or if the kind and reuse identifier are invalid or have not been
/// previously registered in -registerClass:forSupplementaryViewOfKind:reuseIdentifier:.
- (JNWCollectionViewReusableView *)supplementaryViewForKind:(NSString *)kind reuseIdentifier:(NSString *)reuseIdentifier inSection:(NSInteger)section;

/// Returns an array of all the currently visible cells. The cells are not guaranteed to be in any order.
- (NSArray *)visibleCells;

/// Returns the index paths for all the items in the visible rect. Order is not guaranteed.
- (NSArray *)indexPathsForVisibleItems;

/// Returns the index paths for any selected items. Order is not guaranteed.
- (NSArray *)indexPathsForSelectedItems;

#pragma mark - Selection

/// If set to YES, any changes to the backgroundImage or backgroundColor properties of the collection view cell
/// will be animated with a crossfade.
///
/// Defaults to NO.
@property (nonatomic, assign) BOOL animatesSelection;

/// If set to NO, the collection view will not automatically select cells either through clicks or
/// through keyboard actions.
///
/// Defaults to YES.
@property (nonatomic, assign) BOOL allowsSelection;

/// If set to NO, the collection view will force at least one cell to be selected as long as the
/// collection view isn't empty. If no cells are selected, the first one will be selected automatically.
///
/// Defaults to YES.
@property (nonatomic, assign) BOOL allowsEmptySelection;

/// If set to NO, the collection view will enforce only 1 cell being selected at a time.
///
/// Defaults to YES.
@property (nonatomic, assign) BOOL allowsMultipleSelection;

/// If set to NO, the collection view will not respond to ⌘ + A (select all) with allowsMultipleSelection = YES.
///
/// Defaults to YES.
@property (nonatomic, assign) BOOL allowsSelectAll;

/// Returns the list of indexPaths of the selected items
@property (nonatomic, readonly) NSMutableArray *selectedIndexes;

/// Scrolls the collection view to the item at the specified path, optionally animated. The scroll position determines
/// where the item is positioned on the screen.
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(JNWCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated;

/// Selects the item at the specified index path, deselecting any other selected items in the process, optionally animated.
/// The collection view will then scroll to that item in the position as determined by scrollPosition. If no scroll is
/// desired, pass in JNWCollectionViewScrollPositionNone to prevent the scroll..
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(JNWCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated;

/// Selects multiple items in the collection view. Does not perform any extra scrolling.
- (void)selectItemsAtIndexPaths:(NSArray *)indexPaths animated:(BOOL)animated;

/// Selects all items in the collection view.
- (void)selectAllItems;

/// Deselects all items in the collection view.
- (void)deselectAllItems;

#pragma mark - Drag and Drop

// During a drag and drop operation, returns context information.
@property (nonatomic, readonly) JNWCollectionViewDragContext *dragContext;

#pragma mark - Insert & Delete
- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath*> *)insertedIndexPaths;
- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath*> *)deletedIndexPaths;
- (void)reloadItemsAtIndexPaths:(NSArray<NSIndexPath*> *)reloadedIndexPaths;
- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion;
    
#pragma mark - Other
    
- (void)mouseDownInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event;
- (void)mouseUpInCollectionViewCell:(JNWCollectionViewCell *)cell withEvent:(NSEvent *)event;

@end
