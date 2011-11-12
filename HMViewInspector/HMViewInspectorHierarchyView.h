//
//  HMViewInspectorHierarchyView.h
//  HMViewInspector
//
//  Created by Jan Ilavsky on 11/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HMViewInspectorHierarchyView : UIView

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, assign) CGRect hierarchyFrame;
@property (nonatomic, assign) CGFloat placeholderHeight;
@property (nonatomic, strong) NSArray *subItems;

@end
