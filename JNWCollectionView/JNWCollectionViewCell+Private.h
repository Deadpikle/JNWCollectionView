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

@interface JNWCollectionViewCell ()

@property (nonatomic, copy, readwrite) NSString *reuseIdentifier;
@property (nonatomic, weak, readwrite) JNWCollectionView *collectionView;
@property (nonatomic, strong, readwrite) NSIndexPath *indexPath;

/// The image displayed on the dragging item when a cell is dragged out of its collection view.
/// You can subclass and override this to return a different image, or nil to display nothing.
- (NSImage *)draggingImageRepresentation;

@end
