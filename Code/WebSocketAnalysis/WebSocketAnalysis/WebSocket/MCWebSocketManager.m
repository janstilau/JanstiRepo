//
//  MCWebSocketManager.m
//  MCFriends
//
//  Created by JustinLau on 2019/1/10.
//  Copyright © 2019年 Moca Inc. All rights reserved.
//

#import "MCWebSocketManager.h"
#import "SRWebSocket.h"

#define DLOG NSLog

@interface MCWebSocketManager()<SRWebSocketDelegate>

@property (nonatomic, strong) SRWebSocket *socket;
@property (nonatomic, weak) NSTimer *heartbeatTimer;
@property (nonatomic, strong) NSDictionary *payload;

@end

@implementation MCWebSocketManager

+ (instancetype)defaultManager {
    static dispatch_once_t onceToken;
    static MCWebSocketManager *mgr;
    dispatch_once(&onceToken, ^{
        mgr = [[self alloc] init];
    });
    return mgr;
}

#pragma mark - Interact

- (void)openWithPayload:(NSDictionary *)payload {
    _payload = payload;
    [self open];
}

- (void)open {
    if (_socket) {
        [self close];
    }
    NSURL *url = [NSURL URLWithString:@"http://10.0.5.85:9512"];
    _socket = [[SRWebSocket alloc] initWithURL:url];
    _socket.delegate = self;
    [_socket open];
}

- (void)close {
    if (!_socket) {
        return;
    }
    [_socket close];
    _socket = nil;
    [self stopTimer];
}

#pragma mark - Timer

- (void)startTimer {
    if (_heartbeatTimer) {
        return;
    }
    _heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(sendPayload) userInfo:nil repeats:true];
    [[NSRunLoop mainRunLoop] addTimer:_heartbeatTimer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    if (!_heartbeatTimer) {
        return;
    }
    [_heartbeatTimer invalidate];
    _heartbeatTimer = nil;
}

- (void)sendPayload {
    NSString *jsonText = nil;
    if (_payload) {
        jsonText = @"payload to json";
    } else {
        jsonText = @"heartbeat";
    }
    [self sendData:jsonText];
}

- (void)sendData:(id)data {
    if (!_socket) { return; }
    if (self.socket.readyState == SR_OPEN) {
        [self.socket send:data];
    } else if (self.socket.readyState == SR_CONNECTING) {
        // waiting for connected
    } else if (self.socket.readyState == SR_CLOSING || self.socket.readyState == SR_CLOSED) {
        [self reconnect];
    }
}

- (void)reconnect {
    [self close];
    [self open];
}

#pragma mark - SocketRocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    DLOG(@"webSocketDidOpen");
    [self startTimer];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    DLOG(@"webSocketDidReceiveMessage => %@", message);
}

// 源码显示这个回调不是主动调用 close 的回调, 应该重连
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    DLOG(@"webSocketDidCloseWithCode => %@, reason => %@", @(code), reason);
    [self reconnect];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    NSString *pongPayloadStr = [[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding];
    DLOG(@"webSocketDidReceivePong%@", pongPayloadStr);
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    DLOG(@"webSocketDidFailWithError => %@", error);
    [self reconnect];
}

@end
