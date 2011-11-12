//
//  HMViewInspector.m
//  HMViewInspector
//
//  Created by Jan Ilavsky on 11/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "HMViewInspector.h"
#import "HMViewInspectorHierarchyView.h"
#import <QuartzCore/QuartzCore.h>

#define HORIZONTAL_SEPARATOR 16
#define VERTICAL_SEPARATOR 8
#define MINIMUM_ZOOM_SCALE 0.5

@implementation HMViewInspector {

    // UI
    UIScrollView *contentScrollView;
    UIView *contentView;
    UIWindow *mainWindow;
    
    // New hierarchy
    HMViewInspectorHierarchyView *rootItem;
    
    // Gesture recognizer
    UITapGestureRecognizer *tapGestureRecognizer;
    
    // State
    BOOL inspectorViewHierarchyIsPresented;
}

static HMViewInspector *sharedHMViewInspector = nil;

#pragma mark - Shared

+ (HMViewInspector*)sharedHMViewInspector {
    
    if (!sharedHMViewInspector) {
        sharedHMViewInspector = [[HMViewInspector alloc] init];
    }
    
    return sharedHMViewInspector;
}

#pragma mark - Init

- (id)init {
    
    self = [super init];
    if (self) {
        
        mainWindow = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        
        tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
        tapGestureRecognizer.numberOfTapsRequired = 2;
    }
    return self;
}

#pragma mark - Enable / Disable

- (void)enableInspectionTrigger {
    
    [mainWindow addGestureRecognizer:tapGestureRecognizer];

}

- (void)disableInspectionTrigger {
    
    [mainWindow removeGestureRecognizer:tapGestureRecognizer];
}

#pragma mark - Creating inspector hierarchy

- (UIImageView*)grabViewIntoImage:(UIView*)view {
    
    // Save hidden status
    NSMutableArray *hidenStatusArray = [[NSMutableArray alloc] initWithCapacity:[view.subviews count]];
    for (UIView *subView in view.subviews) {
        [hidenStatusArray addObject:[NSNumber numberWithBool:subView.hidden]];
        subView.hidden = YES;
    }
    
    // Grab to image
    int width = roundf(view.frame.size.width);
    int height = roundf(view.frame.size.height);
    
    // Prepare BitmapContext
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    GLubyte *textureData = malloc(width * height * 4);
    memset_pattern4(textureData, "\0\0\0\0", width * height * 4);
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef bitmapContext = CGBitmapContextCreate(textureData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextTranslateCTM(bitmapContext, 0, height);
    CGContextScaleCTM(bitmapContext, 1, -1);
    
    // draw layer
    [view.layer renderInContext:bitmapContext];
    
    // create image
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    CGContextRelease(bitmapContext);
    free(textureData);      
    
    // Restore hidden status
    NSInteger i = 0;
    for (UIView *subView in view.subviews) {
        subView.hidden = [[hidenStatusArray objectAtIndex:i] boolValue];
        ++i;
    }    
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.layer.borderWidth = 2;
    imageView.layer.borderColor = [UIColor blackColor].CGColor;
    
    return imageView;
}

- (HMViewInspectorHierarchyView*)createInspectorHierarchyFromView:(UIView*)view {
    
    HMViewInspectorHierarchyView *newItem = [[HMViewInspectorHierarchyView alloc] init];
    newItem.imageView = [self grabViewIntoImage:view];
    newItem.originalFrame = view.frame;
    newItem.imageView.frame = [mainWindow convertRect:view.bounds fromView:view];
    
    // SubItems
    if (view.subviews) {
        NSMutableArray *newSubItems = [[NSMutableArray alloc] initWithCapacity:[view.subviews count]];
        for (UIView *subView in view.subviews) {
            [newSubItems addObject:[self createInspectorHierarchyFromView:subView]];
        }
        newItem.subItems = newSubItems;
    }

    return newItem;
}

- (CGFloat)placeholderHeightForHierarchyItem:(HMViewInspectorHierarchyView*)hierarchyItem {
    
    hierarchyItem.placeholderHeight = HORIZONTAL_SEPARATOR + hierarchyItem.originalFrame.size.height;
        
    // Compute new size by using all subTtems (recursively)
    CGFloat subItemsPlaceHolderHeight = 0;
    for (HMViewInspectorHierarchyView *subItem in hierarchyItem.subItems) {
        
        subItemsPlaceHolderHeight += [self placeholderHeightForHierarchyItem:subItem];
    }
    
    if (subItemsPlaceHolderHeight > hierarchyItem.placeholderHeight) {
        hierarchyItem.placeholderHeight = subItemsPlaceHolderHeight;
    }
    
    return hierarchyItem.placeholderHeight;
}

// Returns maxX
- (CGFloat)computeNewFramesForHierarchyItem:(HMViewInspectorHierarchyView*)hierarchyItem offset:(CGPoint)offset {
    
    // Compute hierarchy frame for hierarchy item
    CGRect newHierarchyFrame;
    newHierarchyFrame.origin.x = offset.x;
    newHierarchyFrame.origin.y = offset.y + roundf(hierarchyItem.placeholderHeight * 0.5 - hierarchyItem.originalFrame.size.height * 0.5);
    newHierarchyFrame.size = hierarchyItem.originalFrame.size;

    CGFloat maxX = offset.x + newHierarchyFrame.size.width;
    
    hierarchyItem.hierarchyFrame = newHierarchyFrame;
    
    // Compute hierarchy frame for all subItems
    CGPoint newOffset = offset;
    newOffset.x += hierarchyItem.originalFrame.size.width + VERTICAL_SEPARATOR;
    
    for (HMViewInspectorHierarchyView *subItem in hierarchyItem.subItems) {
        CGFloat newMaxX = [self computeNewFramesForHierarchyItem:subItem offset:newOffset];
        if (newMaxX > maxX) {
            maxX = newMaxX;
        }
        newOffset.y += subItem.placeholderHeight;
    }
    
    return maxX;
}

- (void)createInspectorViewHierarchyForHierarchyItem:(HMViewInspectorHierarchyView*)hierarchyItem {
    
    [contentView addSubview:hierarchyItem.imageView];
    
    for (HMViewInspectorHierarchyView *subItem in hierarchyItem.subItems) {
        [self createInspectorViewHierarchyForHierarchyItem:subItem];
    }
}

- (void)updateFramesFromHierarchyItem:(HMViewInspectorHierarchyView*)hierarchyItem {

    hierarchyItem.imageView.frame = hierarchyItem.hierarchyFrame;
    
    for (HMViewInspectorHierarchyView *subItem in hierarchyItem.subItems) {
        [self updateFramesFromHierarchyItem:subItem];
    }    
}

#pragma mark - 

- (void)presentInspectorViewHierarchy {
    
    if (inspectorViewHierarchyIsPresented) {
        return;
    }
    inspectorViewHierarchyIsPresented = YES;
    
    // Create hierarchy
    UIView *rootView = [mainWindow.subviews lastObject];
    rootItem = [self createInspectorHierarchyFromView:rootView];
    
    // Compute placeholders
    [self placeholderHeightForHierarchyItem:rootItem];
    
    // New frames
    CGFloat maxX = [self computeNewFramesForHierarchyItem:rootItem offset:CGPointZero];
    CGSize contentSize = CGSizeMake(maxX, rootItem.placeholderHeight);
      
    // Prepare UI
    contentScrollView = [[UIScrollView alloc] initWithFrame:mainWindow.bounds];
    contentScrollView.contentSize = contentSize;
    contentScrollView.alwaysBounceHorizontal = YES;
    contentScrollView.alwaysBounceVertical = YES;
    contentScrollView.opaque = YES;
    contentScrollView.maximumZoomScale = 1.0;
    contentScrollView.minimumZoomScale = MINIMUM_ZOOM_SCALE;
    contentScrollView.delegate = self;
    contentScrollView.backgroundColor = [UIColor darkGrayColor];
    [mainWindow addSubview:contentScrollView];
    
    contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, contentSize.width, contentSize.height)];
    contentView.opaque = YES;
    contentView.backgroundColor = [UIColor darkGrayColor];
    [contentScrollView addSubview:contentView];
    
    // Create new view hierarchy
    [self createInspectorViewHierarchyForHierarchyItem:rootItem];
    
    // Animate transition
    [UIView animateWithDuration:2.0
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self updateFramesFromHierarchyItem:rootItem]; 
                     }
                     completion:^(BOOL finished) {
                     }];
    
    [contentScrollView setZoomScale:MINIMUM_ZOOM_SCALE animated:YES];
}

- (void)restoreOriginalViewHierarchy {
    
    if (!inspectorViewHierarchyIsPresented) {
        return;
    }
    inspectorViewHierarchyIsPresented = NO;
    
    [contentScrollView removeFromSuperview];
    contentScrollView = nil;
    
    rootItem = nil;
}

#pragma mark - Tap

- (void)tapRecognized:(UIGestureRecognizer*)gestureRecognizer {
    
    if (inspectorViewHierarchyIsPresented) {
        [self restoreOriginalViewHierarchy];
    }
    else {
        [self presentInspectorViewHierarchy];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    
    return contentView;
}

@end
