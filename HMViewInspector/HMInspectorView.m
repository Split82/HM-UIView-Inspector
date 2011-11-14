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

#import "HMInspectorView.h"
#import <QuartzCore/QuartzCore.h>

#define BORDER 8
#define INFO_VIEW_WIDTH 300
#define INFO_VIEW_HEIGHT 200

@implementation HMInspectorView {
    
    UITextView *infoView;
    UIView *backgroundView;
}

@synthesize inspectorSubviews;
@synthesize imageView;
@synthesize originalView;
@synthesize originalFrame;
@synthesize originalClipsToBounds;
@synthesize inspectorFrame;
@synthesize placeholderHeight;
@synthesize expanded;

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        inspectorSubviews = [[NSMutableArray alloc] init];
        self.opaque = NO;
        self.imageView.layer.borderColor = [UIColor blackColor].CGColor; 
        self.backgroundColor = [UIColor clearColor];
        
        // Info View
        infoView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, INFO_VIEW_WIDTH, INFO_VIEW_HEIGHT)];
        infoView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        infoView.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        infoView.opaque = YES;
        infoView.editable = NO;
        infoView.clearsContextBeforeDrawing = NO;
        
        // Background view
        backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        backgroundView.opaque = YES;
        backgroundView.clearsContextBeforeDrawing = NO;
        backgroundView.layer.borderWidth = roundf(BORDER * 0.25);
        backgroundView.layer.borderColor = [UIColor blackColor].CGColor;
    }
    return self;
}

- (void)layoutSubviews {
    
    [imageView sizeToFit];
    
    if (expanded) {
        CGRect rect = infoView.frame;
        rect.origin = CGPointMake(BORDER, BORDER);
        infoView.frame = rect;
        imageView.frame = CGRectMake(BORDER, infoView.frame.size.height + 2 * BORDER, imageView.frame.size.width, imageView.frame.size.height);
    }
    else {
        imageView.frame = CGRectMake(0, 0, imageView.frame.size.width, imageView.frame.size.height);
    }
}

- (CGSize)sizeThatFits:(CGSize)size {
    
    [imageView sizeToFit];
    
    if (expanded) {
        return CGSizeMake(MAX(infoView.frame.size.width + 2 * BORDER, imageView.frame.size.width + 2 * BORDER), infoView.frame.size.height + imageView.frame.size.height + 3 * BORDER);
    }
    else {
        return imageView.bounds.size;
    }

}

#pragma mark - Helpers

- (void)refreshContent {
    
    if (expanded) {
        self.imageView.layer.borderWidth = 1;
        self.imageView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"BGTile.png"]]; 
        self.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
        self.clipsToBounds = NO;
        [self insertSubview:infoView belowSubview:imageView];        
        self.hidden = NO;
    }
    else if (![self.superview isKindOfClass:[HMInspectorView class]] || ([self.superview isKindOfClass:[HMInspectorView class]] && ((HMInspectorView*)self.superview).expanded)) {
        
        self.imageView.layer.borderWidth = 1;
        self.imageView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"BGTile.png"]]; 
        self.backgroundColor = [UIColor clearColor];        
        self.clipsToBounds = originalClipsToBounds;
        [infoView removeFromSuperview];
        self.hidden = NO;        
    }
    else {        
        self.imageView.layer.borderWidth = 0;
        self.imageView.backgroundColor = [UIColor clearColor]; 
        self.backgroundColor = [UIColor clearColor];        
        self.clipsToBounds = originalClipsToBounds;
        [infoView removeFromSuperview];     
        self.hidden = originalView.hidden;        
    }    
}

#pragma mark - Getters

- (HMInspectorView*)findFirstInspectorViewWithPoint:(CGPoint)point tolerance:(CGFloat)tolerance {
    
    CGRect toleranceBounds = self.bounds;
    if (expanded) {
        toleranceBounds.origin.y -= roundf((placeholderHeight - self.bounds.size.height) * 0.5 - BORDER * 0.5);
        toleranceBounds.size.height = placeholderHeight - BORDER;    
    }
    toleranceBounds.origin.x -= tolerance;
    toleranceBounds.origin.y -= tolerance;
    toleranceBounds.size.width += 2 * tolerance;
    toleranceBounds.size.height += 2 * tolerance;
    if (CGRectContainsPoint(toleranceBounds, point)) {
        return self;
    }
    
    for (HMInspectorView *subview in self.inspectorSubviews) {
        
        HMInspectorView *foundView = [subview findFirstInspectorViewWithPoint:[subview convertPoint:point fromView:self] tolerance:tolerance];
        if (foundView) {
            return foundView;
        }
    }  
    
    return nil;
}

- (CGFloat)maxX {
   
    CGFloat maxX = CGRectGetMaxX(self.bounds);    
    
    for (HMInspectorView *subview in self.inspectorSubviews) {

        CGFloat newMaxX = [subview maxX] + subview.frame.origin.x;
        if (newMaxX > maxX) {
            maxX = newMaxX;
        }
    }         
    
    return maxX;
}

- (CGRect)containerBoundsForSelfAndFirstLevelSubviews {
    
    CGRect frame = self.bounds;
    
    for (HMInspectorView *subview in self.inspectorSubviews) {
        frame = CGRectUnion(frame, [self convertRect:subview.bounds fromView:subview]);
    }
    
    return frame;
}

#pragma mark - Setters

- (void)setOriginalView:(UIView *)newOriginalView {
    
    originalView = newOriginalView;
    
    infoView.text = [originalView description];    
    [infoView sizeToFit];
}

- (void)setExpanded:(BOOL)value {
    
    if (value) {
    
        // If superview is not inspector view, we can expand
        if (![self.superview isKindOfClass:[HMInspectorView class]]) {
            
            expanded = YES;
        }  
        // Or superview is expanded
        else if (((HMInspectorView*)self.superview).expanded) {
            
            expanded = YES;
        }
    }
    else {
        
        expanded = NO;
        // Recursively colaps all inspectorSubviews
        for (HMInspectorView *subview in self.inspectorSubviews) {
            subview.expanded = NO;
        }        
    }
    
    [self refreshContent];
    for (HMInspectorView *subview in self.inspectorSubviews) {
        [subview refreshContent];
    }
}

- (void)addInspectorSubview:(HMInspectorView*)inspectorView {
    
    [inspectorSubviews addObject:inspectorView];
    [self addSubview:inspectorView];
}

- (void)setImageView:(UIImageView *)newImageView {
    
    [imageView removeFromSuperview];
    imageView = newImageView;
    [self addSubview:newImageView];
    [self setNeedsLayout];   
}

- (void)useInspectorFrame {
    
    BOOL superviewIsExpanded = ([self.superview isKindOfClass:[HMInspectorView class]] && ((HMInspectorView*)self.superview).expanded);
    
    if (expanded || superviewIsExpanded) {
        self.frame = inspectorFrame;
    }
    else {
        self.frame = originalFrame;
    }
    
    [self refreshContent];
    
    // Everyone knows you shouldn't call this directly. But here we need it for animation ;)
    [self layoutSubviews];
    
    // Propagate to subviews
    for (HMInspectorView *subview in self.inspectorSubviews) {
        [subview useInspectorFrame];
    }
}

- (void)updateBackgroundViewsWithLevel:(NSInteger)level spaceToMaxX:(CGFloat)spaceToMaxX {
    
    if (expanded) {
        CGRect rect = self.bounds;
        rect.origin.y -= roundf((placeholderHeight - rect.size.height) * 0.5 - BORDER * 0.5);
        rect.size.width = spaceToMaxX + BORDER;
        rect.size.height = placeholderHeight - BORDER;
        backgroundView.frame = rect;
        backgroundView.backgroundColor = [UIColor colorWithWhite:0.25 + level * 0.05 alpha:1.0];
        [self insertSubview:backgroundView atIndex:0];
    }
    else {
        [backgroundView removeFromSuperview];
    }
    
    // Do on subviews
    for (HMInspectorView *subview in self.inspectorSubviews) {
        [subview updateBackgroundViewsWithLevel:level + 1 spaceToMaxX:spaceToMaxX - subview.frame.origin.x];
    }    
}

@end
