//
//  COperation.h
//  ThreeTab
//
//  Created by wenyu on 2018/11/17.
//  Copyright © 2018年 ThreeTab. All rights reserved.
//

#import <Foundation/Foundation.h>

union SchroedingersCat {
    int isAlive;
    UInt32 isDead;
};
NS_ASSUME_NONNULL_BEGIN


@interface COperation : NSObject
+(uint16_t)In_cksum:(const void *)buffer bufferLen: (size_t)bufferLen;
@end

NS_ASSUME_NONNULL_END
