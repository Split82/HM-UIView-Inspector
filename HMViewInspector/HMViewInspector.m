// Copyright (c) 2011 Hyperbolic Magnetism
//
// Created by Jan "Split" Ilavsky (@split82)
// http://www.hyperbolicmagnetism.com
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "HMViewInspector.h"
#import "HMInspectorView.h"
#import <QuartzCore/QuartzCore.h>

#define HORIZONTAL_SEPARATOR 16
#define VERTICAL_SEPARATOR 16
#define MINIMUM_ZOOM_SCALE 0.2

@implementation HMViewInspector {

    // UI
    UIScrollView *contentScrollView;
    UIView *contentView;
    UIWindow *mainWindow;
    
    // New hierarchy
    HMInspectorView *rootInspectorView;
    
    // Gesture recognizer
    UITapGestureRecognizer *triggerGestureRecognizer;
    
    // State
    BOOL inspectorViewHierarchyIsPresented;
    BOOL previousStatusBarHidden;
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
        
        triggerGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(triggerGestureRecognized:)];
        triggerGestureRecognizer.numberOfTapsRequired = 3;
    }
    return self;
}

#pragma mark - Enable / Disable

- (void)enableDefaultInspectionTrigger {
    
    [mainWindow addGestureRecognizer:triggerGestureRecognizer];

}

- (void)disableDefaultInspectionTrigger {
    
    [mainWindow removeGestureRecognizer:triggerGestureRecognizer];
}

#pragma mark - Creating inspector hierarchy

- (UIImageView*)grabViewIntoImageView:(UIView*)view {
    
    BOOL previousHiddenStatus = view.hidden;
    view.hidden = NO;
    
    // Save hidden status
    NSMutableArray *hidenStatusArray = [[NSMutableArray alloc] initWithCapacity:[view.subviews count]];
    for (UIView *subView in view.subviews) {
        [hidenStatusArray addObject:[NSNumber numberWithBool:subView.hidden]];
        subView.hidden = YES;
    }
    
    // Grab to image
    int width = roundf(view.bounds.size.width);
    int height = roundf(view.bounds.size.height);
    
    // Prepare BitmapContext
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    GLubyte *textureData = malloc(width * height * 4);
    memset_pattern4(textureData, "\0\0\0\0", width * height * 4);
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef bitmapContext = CGBitmapContextCreate(textureData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextTranslateCTM(bitmapContext, view.bounds.origin.x, view.bounds.origin.y);
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
    view.hidden = previousHiddenStatus;
    
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.clipsToBounds = YES;
    
    return imageView;
}

- (HMInspectorView*)createInspectorHierarchyFromView:(UIView*)view contentOffset:(CGPoint)contentOffset {
    
    // New view
    HMInspectorView *newInspectorView = [[HMInspectorView alloc] initWithFrame:CGRectZero];
    newInspectorView.originalView = view;
    newInspectorView.imageView = [self grabViewIntoImageView:view];
    newInspectorView.originalFrame = CGRectOffset(view.frame, -contentOffset.x, -contentOffset.y);
    newInspectorView.originalClipsToBounds = view.clipsToBounds;
    
    CGPoint newContentOffset = view.bounds.origin;
    
    // Subviews
    for (UIView *subview in view.subviews) {
        [newInspectorView addInspectorSubview:[self createInspectorHierarchyFromView:subview contentOffset:newContentOffset]];
    }

    return newInspectorView;
}

- (CGFloat)placeholderHeightForInspectorView:(HMInspectorView*)inspectorView {
    
    // Get size of inspectorView
    CGSize inspectorViewSize = [inspectorView sizeThatFits:CGSizeZero];
    
    inspectorView.placeholderHeight = VERTICAL_SEPARATOR + inspectorViewSize.height;
        
    // If expanded, compute new size by using all inspectorSubviews (recursively)
    if (inspectorView.expanded) {    
      
        CGFloat subViewsPlaceHolderHeight = 0;
        for (HMInspectorView *subview in inspectorView.inspectorSubviews) {
            
            subViewsPlaceHolderHeight += [self placeholderHeightForInspectorView:subview];
        }
        
        // If subviews need more space than parent view, use new value
        if (subViewsPlaceHolderHeight > inspectorView.placeholderHeight) {
            inspectorView.placeholderHeight = subViewsPlaceHolderHeight;
        }
    }
    
    return inspectorView.placeholderHeight;
}

- (void)computeInspectorViewFramesFromInspectorView:(HMInspectorView*)inspectorView offset:(CGPoint)offset {
    
    CGSize inspectorViewSize = [inspectorView sizeThatFits:CGSizeZero];    
        
    // Frame for inspectorView
    CGRect newFrame;
    newFrame.origin.x = offset.x;
    newFrame.origin.y = offset.y + roundf(inspectorView.placeholderHeight * 0.5 - inspectorViewSize.height * 0.5);
    newFrame.size = inspectorViewSize;
    
    // New frame
    inspectorView.inspectorFrame = newFrame;
    
    // If expanded, compute inspector frames for all inspectorSubviews
    if (inspectorView.expanded) {
        
        CGPoint newOffset = CGPointZero;
        newOffset.x = inspectorViewSize.width + HORIZONTAL_SEPARATOR;
        newOffset.y -= roundf(inspectorView.placeholderHeight * 0.5 - inspectorViewSize.height * 0.5);
        
        for (HMInspectorView *subview in inspectorView.inspectorSubviews) {
            [self computeInspectorViewFramesFromInspectorView:subview offset:newOffset];
            newOffset.y += subview.placeholderHeight;
        }
    }
}

- (void)refreshInspectorViewFramesAnimated:(BOOL)animated {
    
    // Compute placeholders
    [self placeholderHeightForInspectorView:rootInspectorView];    
    
    // Frame for containers
    [self computeInspectorViewFramesFromInspectorView:rootInspectorView offset:CGPointMake(HORIZONTAL_SEPARATOR, VERTICAL_SEPARATOR)]; 
        
    void (^updateFrames)(void) = ^{
        [rootInspectorView useInspectorFrame];
        
        CGFloat maxX = [rootInspectorView maxX];        
        [rootInspectorView updateBackgroundViewsWithLevel:0 spaceToMaxX:maxX];
        
        CGSize contentSize = CGSizeMake([rootInspectorView maxX] + 2 * HORIZONTAL_SEPARATOR , rootInspectorView.placeholderHeight + 2 * VERTICAL_SEPARATOR);                          
        contentScrollView.contentSize = contentSize;
        contentView.frame = CGRectMake(0, 0, contentSize.width * contentScrollView.zoomScale, contentSize.height * contentScrollView.zoomScale);  
        
    };    
    
    // Animate transition
    if (animated) {
        [UIView animateWithDuration:0.4
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:updateFrames
                         completion:^(BOOL finished) {
                         }];   
    }
    else {
        updateFrames();
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
    rootInspectorView = [self createInspectorHierarchyFromView:rootView contentOffset:CGPointZero];

    // Prepare UI    
    previousStatusBarHidden = [UIApplication sharedApplication].statusBarHidden;
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    
    // ScrollView
    contentScrollView = [[UIScrollView alloc] initWithFrame:mainWindow.bounds];
    contentScrollView.alwaysBounceHorizontal = YES;
    contentScrollView.alwaysBounceVertical = YES;
    contentScrollView.opaque = YES;
    contentScrollView.maximumZoomScale = 1.0;
    contentScrollView.minimumZoomScale = MINIMUM_ZOOM_SCALE;
    contentScrollView.delegate = self;
    contentScrollView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [mainWindow addSubview:contentScrollView];
    
    // ContentView
    contentView = [[UIView alloc] initWithFrame:CGRectZero];
    contentView.opaque = YES;
    contentView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [contentScrollView addSubview:contentView];    
    
    // Recieving taps
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
    [contentView addGestureRecognizer:tapGestureRecognizer];
    
    // Root inspector view
    [contentView addSubview:rootInspectorView];    
       
    [self refreshInspectorViewFramesAnimated:NO];
}

- (void)dismissInspectorViewHierarchy {
    
    if (!inspectorViewHierarchyIsPresented) {
        return;
    }
    inspectorViewHierarchyIsPresented = NO;
    
    [[UIApplication sharedApplication] setStatusBarHidden:previousStatusBarHidden withAnimation:UIStatusBarAnimationNone];    
    
    [contentScrollView removeFromSuperview];
    contentScrollView = nil;
    
    rootInspectorView = nil;
}

#pragma mark - Gesture recognizers

- (void)triggerGestureRecognized:(UIGestureRecognizer*)gestureRecognizer {
    
    if (inspectorViewHierarchyIsPresented) {
        [self dismissInspectorViewHierarchy];
    }
    else {
        [self presentInspectorViewHierarchy];
    }
}

- (void)tapRecognized:(UIGestureRecognizer*)gestureRecognizer {
   
    HMInspectorView *inspectorView = [rootInspectorView findFirstInspectorViewWithPoint:[gestureRecognizer locationInView:rootInspectorView] tolerance:MIN(HORIZONTAL_SEPARATOR, VERTICAL_SEPARATOR) * 0.5];

    if (!inspectorView) {
        return;
    }
        
    inspectorView.expanded = !inspectorView.expanded;
    
    // Update view hierarchy
    [self refreshInspectorViewFramesAnimated:YES];
    
    // If is expanded zoom to it and it's subviews
    if (inspectorView.expanded) {
        
        CGRect rect = [contentView convertRect:[inspectorView containerBoundsForSelfAndFirstLevelSubviews] fromView:inspectorView];
        [contentScrollView zoomToRect:rect  animated:YES];
    }
    // If no subviews, zoom to superview and it's subviews
    else if ([inspectorView.superview isKindOfClass:[HMInspectorView class]] && [inspectorView.inspectorSubviews count] == 0) {
        CGRect rect = [contentView convertRect:[((HMInspectorView*)inspectorView.superview) containerBoundsForSelfAndFirstLevelSubviews] fromView:inspectorView.superview];
        [contentScrollView zoomToRect:rect  animated:YES];        
    }
    // Else zoom to view
    else {

        CGRect rect = [contentView convertRect:inspectorView.bounds fromView:inspectorView];
        [contentScrollView zoomToRect:rect  animated:YES];        
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    
    return contentView;
}

@end