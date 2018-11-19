//
//  GBPing.h
//  GBPing
//
//  Created by Luka Mirosevic on 05/11/2012.
//  Copyright (c) 2012 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GBPingSummary.h"
//#import "ICMPHeader.h"


@class GBPingSummary;
@protocol GBPingDelegate;

NS_ASSUME_NONNULL_BEGIN

typedef void(^StartupCallback)(BOOL success, NSError * _Nullable error);

@interface GBPing : NSObject

@property (weak, nonatomic, nullable) id<GBPingDelegate>      delegate;

@property (copy, nonatomic, nullable) NSString                *host;
@property (assign, atomic) NSTimeInterval           pingPeriod;
@property (assign, atomic) NSTimeInterval           timeout;
@property (assign, atomic) NSUInteger               payloadSize;
@property (assign, atomic) NSUInteger               ttl;
@property (assign, atomic) BOOL           isPinging;
@property (assign, atomic) BOOL           isReady;
@property (strong,nullable) NSThread *sendThread;
@property (strong,nullable) NSThread *listenThread;
@property (assign, atomic) BOOL           isSendThread;
@property (assign, atomic) BOOL           isListenThread;

@property (assign, atomic) BOOL                     debug;
@property (strong, nonatomic) NSString                  *hostAddressString;
@property (strong, atomic) NSMutableDictionary          *pendingPings;
@property (strong, nonatomic) NSData                    *hostAddress;
@property (assign, nonatomic) uint16_t                  identifier;
@property (assign, nonatomic) NSUInteger                nextSequenceNumber;
@property (strong, nonatomic) NSMutableDictionary       *timeoutTimers;
@property (assign, atomic) int                          socket;

@property (strong, nonatomic) dispatch_queue_t          setupQueue;

@property (assign, atomic) BOOL                         isStopped;

-(void)setupWithBlock:(StartupCallback)callback;
-(void)startPinging;
-(void)stop;
-(void)sendPing;
-(void)listenOnce;

@end

@protocol GBPingDelegate <NSObject>

@optional

-(void)ping:(GBPing *)pinger didFailWithError:(NSError *)error;

-(void)ping:(GBPing *)pinger didSendPingWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didFailToSendPingWithSummary:(GBPingSummary *)summary error:(NSError *)error;
-(void)ping:(GBPing *)pinger didTimeoutWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary;
-(void)ping:(GBPing *)pinger didReceiveUnexpectedReplyWithSummary:(GBPingSummary *)summary;
-(void)stopPing:(GBPing *)pinger;

@end

NS_ASSUME_NONNULL_END
