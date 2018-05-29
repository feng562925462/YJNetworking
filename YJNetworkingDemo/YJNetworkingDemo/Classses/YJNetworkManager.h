//
//  YJNetworkManager.h
//  test2
//
//  Created by cool on 2018/5/14.
//  Copyright © 2018 cool. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "YJNetworkItem.h"

#define YJNetManagerShare [YJNetworkManager sharedYJNetManager]

#define YJWeak  __weak __typeof(self) weakSelf = self

@interface YJNetworkManager : NSObject

/*!
 *  获得全局唯一的网络请求实例单例方法
 *
 *  @return 网络请求类YJNetManager单例
 */
+ (instancetype)sharedYJNetManager;

#pragma mark - 网络请求的类方法 --- get / post / put / delete

- (NSDictionary *)yj_processingWithItem:(YJNetworkItem *)item;

- (NSURLSessionTask *)yj_requestWithItem:(YJNetworkItem *)item;

#pragma mark get

+ (NSURLSessionTask *)yj_GET:(NSString *)url
                      params:(NSDictionary *)params
                successBlock:(YJResponseSuccessBlock)successBlock
                   failBlock:(YJResponseFailBlock)failBlock;

#pragma mark post

+ (NSURLSessionTask *)yj_POST:(NSString *)url
                      params:(NSDictionary *)params
                progressBlock:(YJProgressBlock)progressBlock
                successBlock:(YJResponseSuccessBlock)successBlock
                   failBlock:(YJResponseFailBlock)failBlock;

#pragma mark put

+ (NSURLSessionTask *)yj_PUT:(NSString *)url
                       params:(NSDictionary *)params
               progressBlock:(YJProgressBlock)progressBlock
                 successBlock:(YJResponseSuccessBlock)successBlock
                    failBlock:(YJResponseFailBlock)failBlock;

#pragma mark delete

+ (NSURLSessionTask *)yj_DELRTE:(NSString *)url
                       params:(NSDictionary *)params
                  progressBlock:(YJProgressBlock)progressBlock
                 successBlock:(YJResponseSuccessBlock)successBlock
                    failBlock:(YJResponseFailBlock)failBlock;


#pragma mark - 自定义请求头
/**
 *  自定义请求头
 */
+ (void)yj_setValue:(NSString *)value forHTTPHeaderKey:(NSString *)HTTPHeaderKey;

/**
 删除所有请求头
 */
+ (void)yj_clearAuthorizationHeader;

#pragma mark - 取消 Http 请求
/*!
 *  取消所有 Http 请求
 */
+ (void)yj_cancelAllRequest;

/*!
 *  取消指定 URL 的 Http 请求
 */
+ (void)yj_cancelRequestWithURL:(NSString *)URL;

/**
 清空缓存：此方法可能会阻止调用线程，直到文件删除完成。
 */
- (void)yj_clearAllHttpCache;

@end
