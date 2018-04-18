//
//  YJNetworking.h
//  YJNetworking
//
//  Created by cool on 2018/4/12.
//  Copyright © 2018年 cool. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 待完成：重复请求自动取消
 */

/**
 *  成功回调
 *
 *  @param response 成功后返回的数据
 */
typedef void(^YJResponseSuccessBlock)(id response);

/**
 *  失败回调
 *
 *  @param error 失败后返回的错误信息
 */
typedef void(^YJResponseFailBlock)(NSError *error);

/*
 *  下载进度
 *
 *  @param bytesRead                 已下载的大小
 *  @param totalBytesRead            文件总大小
 */
typedef void (^YJDownloadProgress)(int64_t bytesRead,
                                   int64_t totalBytesRead);

//请求类型
typedef NS_ENUM(NSInteger, YJRequestType) {
    YJRequestTypeGET          = 0,//默认类型
    YJRequestTypePOST     = 1
};

// 响应数据格式
typedef NS_ENUM(NSUInteger,YJResponseDataType) {
    kYJResponseDataTypeJSON = 0, // 默认
    kYJResponseDataTypeData = 1,
};

@interface YJNetworking : NSObject

@property(nonatomic, strong, readonly) NSArray<NSURLSessionTask *> *allSessionTask;

+ (instancetype)sharedInstance;

/// 参数处理
- (NSDictionary *)processingParameters:(NSDictionary *)parameters
                                URLStr:(NSString *)URLStr;

/// url 处理
- (NSString *)processingURLStr:(NSString *)URLStr;

/// 请求超时时间
- (NSTimeInterval)timeoutIntervalWithURLStr:(NSString *)URLStr;

/// 样本数据
- (NSData *)sampleData:(NSString *)url params:(NSDictionary *)params;

/// 是否执行网络请求结果的回掉
- (BOOL)network:(NSString *)url params:(NSDictionary *)params task:(NSURLSessionTask *)task result:(id)result error:(NSError *)error;

- (NSURLSessionTask *)GET:(NSString *)url
                   params:(NSDictionary *)params
             successBlock:(YJResponseSuccessBlock)successBlock
                failBlock:(YJResponseFailBlock)failBlock;

- (NSURLSessionTask *)POST:(NSString *)url
                   params:(NSDictionary *)params
             successBlock:(YJResponseSuccessBlock)successBlock
                failBlock:(YJResponseFailBlock)failBlock;

- (NSURLSessionTask *)network:(YJRequestType)requestType
                          url:(NSString *)url
                       params:(NSDictionary *)params
              timeoutInterval:(NSTimeInterval)timeoutInterval
             responseDataType:(YJResponseDataType)responseDataType
                progressBlock:(YJDownloadProgress)progressBlock
                 successBlock:(YJResponseSuccessBlock)successBlock
                    failBlock:(YJResponseFailBlock)failBlock;

@end
