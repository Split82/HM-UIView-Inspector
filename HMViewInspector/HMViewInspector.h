//
//  HMViewInspector.h
//  HMViewInspector
//
//  Created by Jan Ilavsky on 11/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HMViewInspector : NSObject <UIScrollViewDelegate>

+ (HMViewInspector*)sharedHMViewInspector;

- (void)enableInspectionTrigger;
- (void)disableInspectionTrigger;

@end
