//
//  YJNetworkManager.m
//  test2
//
//  Created by cool on 2018/5/14.
//  Copyright © 2018 cool. All rights reserved.
//

#import "YJNetworkManager.h"
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetExportSession.h>
#import <AVFoundation/AVMediaFormat.h>

/*! 系统相册 */
#import <Photos/Photos.h>
#import "AFNetworking.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "YJNetworkCache.h"

static NSMutableArray *tasks;
static NSTimeInterval _timeoutInterval = 30;
static YJHttpResponseSerializer _httpResponseSerializer = YJHttpResponseSerializerJSON;

@implementation NSString (YJNetworkManager)

/**
 *  判断是否包含中文
 */
- (BOOL)yj_isContainChinese {
    NSUInteger length = [self length];
    for (NSUInteger i = 0; i < length; i++) {
        NSRange range = NSMakeRange(i, 1);
        NSString *subString = [self substringWithRange:range];
        const char *cString = [subString UTF8String];
        if (strlen(cString) == 3) {
            return YES;
        }
    }
    return NO;
}

/**
 *  中文转码，如果不含有中文直接返回
 */
- (NSString *)yj_UTF8String {
    
    if (self.yj_isContainChinese == NO) {
        return self;
    }
    return [self stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

/**
 *  URL 自动补全
 */
- (NSString *)yj_URLAutomaticCompletion {
    if (self == nil || self.length <= 0) {
        return self;
    }
    
    if ([self hasPrefix:@"http://"] || [self hasPrefix:@"https://"]) {
        return self;
    }
    
    if ([self hasPrefix:@"http:"]) {
        return [self stringByReplacingOccurrencesOfString:@"http:" withString:@"http://"];
    }
    
    if ([self hasPrefix:@"https:"]) {
        return [self stringByReplacingOccurrencesOfString:@"https:" withString:@"https://"];
    }
    
    if ([self hasPrefix:@"//"]) {
        return [self stringByReplacingOccurrencesOfString:@"//" withString:@"http://"];
    }
    
    return [NSString stringWithFormat:@"http://%@", self];
}

@end
@interface YJNetworkManager ()

@property(nonatomic, strong) AFHTTPSessionManager *sessionManager;

@end

@implementation YJNetworkManager

- (AFHTTPSessionManager *)sessionManager {
    if (!_sessionManager) {
        _sessionManager = [AFHTTPSessionManager manager];
        /*! 打开状态栏的等待菊花 */
        [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
        _sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/css", @"text/xml", @"text/plain", @"application/javascript", @"application/x-www-form-urlencoded", @"image/*", nil];
        //        配置自建证书的Https请求
        _sessionManager.securityPolicy = [self yj_setupSecurityPolicy];
        _sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    }
    
    return _sessionManager;
}

- (AFHTTPSessionManager *)currentSessionManagerWithItem:(YJNetworkItem *)item {
    return self.sessionManager;
}

/**
 配置自建证书的Https请求，只需要将CA证书文件放入根目录就行
 */
- (AFSecurityPolicy *)yj_setupSecurityPolicy {
    //    NSData *cerData = [NSData dataWithContentsOfFile:cerPath];
    NSSet <NSData *> *cerSet = [AFSecurityPolicy certificatesInBundle:[NSBundle mainBundle]];
    
    if (cerSet.count == 0)
    {
        /*!
         采用默认的defaultPolicy就可以了. AFN默认的securityPolicy就是它, 不必另写代码. AFSecurityPolicy类中会调用苹果security.framework的机制去自行验证本次请求服务端放回的证书是否是经过正规签名.
         */
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
        securityPolicy.allowInvalidCertificates = YES;
        securityPolicy.validatesDomainName = NO;
        return securityPolicy;
    }
    else
    {
        /*! 自定义的CA证书配置如下： */
        /*! 自定义security policy, 先前确保你的自定义CA证书已放入工程Bundle */
        /*!
         https://api.github.com网址的证书实际上是正规CADigiCert签发的, 这里把Charles的CA根证书导入系统并设为信任后, 把Charles设为该网址的SSL Proxy (相当于"中间人"), 这样通过代理访问服务器返回将是由Charles伪CA签发的证书.
         */
        // 使用证书验证模式
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:cerSet];
        // 如果需要验证自建证书(无效证书)，需要设置为YES
        securityPolicy.allowInvalidCertificates = YES;
        // 是否需要验证域名，默认为YES
        //    securityPolicy.pinnedCertificates = [[NSSet alloc] initWithObjects:cerData, nil];
        return securityPolicy;
        
        
        /*! 如果服务端使用的是正规CA签发的证书, 那么以下几行就可去掉: */
        //            NSSet <NSData *> *cerSet = [AFSecurityPolicy certificatesInBundle:[NSBundle mainBundle]];
        //            AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:cerSet];
        //            policy.allowInvalidCertificates = YES;
        //            YJNetManagerShare.sessionManager.securityPolicy = policy;
    }
    
}

+ (instancetype)sharedYJNetManager
{
    /*! 为单例对象创建的静态实例，置为nil，因为对象的唯一性，必须是static类型 */
    static id sharedYJNetManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedYJNetManager = [[super allocWithZone:NULL] init];
    });
    return sharedYJNetManager;
}

#pragma mark - 网络请求的类方法 --- get / post / put / delete

/// 对返回的数据进行格式化处理
- (id)dataFormat:(id)responseObject {
    
    if (![responseObject isKindOfClass:[NSData class]]) {
        return responseObject;
    }
    
    NSData *data = responseObject;
    if (data.length <= 0) {
        return data;
    }
    
    NSString *string = [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
    
    string = [self format:string character:@[@"\n",@"\r",@"\t"]];
    
    if (string.length <= 0) {
        return data;
    }
    
    NSError * error ;
    
    NSData * data1 = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    if (data1.length <= 0) {
        return data;
    }
    
    id result = [NSJSONSerialization JSONObjectWithData:data1 options:NSJSONReadingMutableContainers error: &error ];
    
    if (error) {
        return data;
    }
    
    return result;
}

/// 字符串格式化
- (NSString *)format:(NSString *)content character:(NSArray<NSString *> *)character {
    
    if (character.count <= 0) {
        return content;
    }
    
    __block NSString *string = content;
    
    [character enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        string = [string stringByReplacingOccurrencesOfString:obj withString:@""];
    }];
    
    return string;
}

- (NSDictionary *)yj_processingWithItem:(YJNetworkItem *)item{
    return item.parameters;
}

/// 样本数据
- (NSData *)yj_sampleWithItem:(YJNetworkItem *)item {
    return nil;
}

/// 是否执行网络请求结果的回掉
- (BOOL)yj_network:(YJNetworkItem *)item task:(NSURLSessionTask *)task result:(id)result error:(NSError *)error {
    return YES;
}

- (NSURLSessionTask *)yj_requestWithItem:(YJNetworkItem *)item {
    
    YJWeak;
    /* 地址中文处理 */
    NSString *URLString = item.urlString.yj_URLAutomaticCompletion.yj_UTF8String;
    
    /// 参数处理
    item.parameters = [self yj_processingWithItem:item];
    
    NSURLSessionTask *sessionTask = nil;
    AFHTTPSessionManager *sessionManager = [self currentSessionManagerWithItem:item];
    // 获取样本数据
//    NSData *data = [self yj_sampleWithItem:item];
//
//    if (data && data.length > 0) {
//
//        id result = data;
//
//        if (responseDataType == kYJResponseDataTypeJSON) {
//            result = [self dataFormat:data];
//        }
//
//        BOOL isValid = [self yj_network:url params:params task:session result:result error:nil];
//
//        if (successBlock && isValid) {
//            successBlock(result);
//        }
//
//        return session;
//    }
    
    // 读取缓存
    id responseCacheData = [YJNetworkCache yj_httpCacheWithUrlString:item.urlString parameters:item.parameters];
    
    if (item.isNeedCache && responseCacheData != nil)
    {
        if (item.successBlock)
        {
            item.successBlock([self dataFormat:responseCacheData]);
        }
        [[weakSelf tasks] removeObject:sessionTask];
        return nil;
    }
    
    if (item.httpRequestType == YJHttpRequestTypeGet)
    {
        sessionTask = [sessionManager GET:URLString parameters:item.parameters  progress:^(NSProgress * _Nonnull downloadProgress) {
            /*! 回到主线程刷新UI */
            dispatch_async(dispatch_get_main_queue(), ^{
                if (item.progressBlock)
                {
                    item.progressBlock(downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
                }
            });
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            if (item.successBlock)
            {
                item.successBlock([self dataFormat:responseObject]);
            }
            // 对数据进行异步缓存
            [YJNetworkCache yj_setHttpCache:responseObject urlString:item.urlString parameters:item.parameters];
            [[weakSelf tasks] removeObject:sessionTask];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
            if (item.failureBlock)
            {
                item.failureBlock(error);
            }
            [[weakSelf tasks] removeObject:sessionTask];
        }];
    }
    else if (item.httpRequestType == YJHttpRequestTypePost)
    {
        sessionTask = [sessionManager POST:URLString parameters:item.parameters progress:^(NSProgress * _Nonnull uploadProgress) {
            NSLog(@"上传进度--%lld, 总进度---%lld",uploadProgress.completedUnitCount,uploadProgress.totalUnitCount);
            
            /*! 回到主线程刷新UI */
            dispatch_async(dispatch_get_main_queue(), ^{
                if (item.progressBlock)
                {
                    item.progressBlock(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
                }
            });
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            NSLog(@"post 请求数据结果： *** %@", responseObject);
            
            if (item.successBlock)
            {
                item.successBlock([self dataFormat:responseObject]);
            }
            
            // 对数据进行异步缓存
            [YJNetworkCache yj_setHttpCache:responseObject urlString:item.urlString parameters:item.parameters];
            [[weakSelf tasks] removeObject:sessionTask];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"错误信息：%@",error);
            
            if (item.failureBlock)
            {
                item.failureBlock(error);
            }
            [[weakSelf tasks] removeObject:sessionTask];
            
        }];
    }
    else if (item.httpRequestType == YJHttpRequestTypePut)
    {
        sessionTask = [sessionManager PUT:URLString parameters:item.parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            if (item.successBlock)
            {
                item.successBlock([self dataFormat:responseObject]);
            }
            
            [[weakSelf tasks] removeObject:sessionTask];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
            if (item.failureBlock)
            {
                item.failureBlock(error);
            }
            [[weakSelf tasks] removeObject:sessionTask];
            
        }];
    }
    else if (item.httpRequestType == YJHttpRequestTypeDelete)
    {
        sessionTask = [sessionManager DELETE:URLString parameters:item.parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if (item.successBlock)
            {
                item.successBlock([self dataFormat:responseObject]);
            }
            
            [[weakSelf tasks] removeObject:sessionTask];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
            if (item.failureBlock)
            {
                item.failureBlock(error);
            }
            [[weakSelf tasks] removeObject:sessionTask];
            
        }];
    }
    
    if (sessionTask)
    {
        [[weakSelf tasks] addObject:sessionTask];
    }
    
    return sessionTask;
}

+ (NSURLSessionTask *)yj_request:(NSString *)url
                          params:(NSDictionary *)params
                 httpRequestType:(YJHttpRequestType)httpRequestType
                   progressBlock:(YJProgressBlock)progressBlock
                    successBlock:(YJResponseSuccessBlock)successBlock
                       failBlock:(YJResponseFailBlock)failBlock {
    YJNetworkItem *item = [[YJNetworkItem alloc] init];
    item.urlString = url;
    item.parameters = params;
    item.httpRequestType = httpRequestType;
    item.progressBlock = progressBlock;
    item.successBlock = successBlock;
    item.failureBlock = failBlock;
    return [[YJNetworkManager sharedYJNetManager] yj_requestWithItem:item];
}

#pragma mark get

+ (NSURLSessionTask *)yj_GET:(NSString *)url
                      params:(NSDictionary *)params
                successBlock:(YJResponseSuccessBlock)successBlock
                   failBlock:(YJResponseFailBlock)failBlock {
    return [self yj_request:url params:params httpRequestType:YJHttpRequestTypeGet progressBlock:nil successBlock:successBlock failBlock:failBlock];
}

#pragma mark post

+ (NSURLSessionTask *)yj_POST:(NSString *)url
                       params:(NSDictionary *)params
                progressBlock:(YJProgressBlock)progressBlock
                 successBlock:(YJResponseSuccessBlock)successBlock
                    failBlock:(YJResponseFailBlock)failBlock {
    return [self yj_request:url params:params httpRequestType:YJHttpRequestTypePost progressBlock:progressBlock successBlock:successBlock failBlock:failBlock];
}

#pragma mark put

+ (NSURLSessionTask *)yj_PUT:(NSString *)url
                      params:(NSDictionary *)params
               progressBlock:(YJProgressBlock)progressBlock
                successBlock:(YJResponseSuccessBlock)successBlock
                   failBlock:(YJResponseFailBlock)failBlock {
    return [self yj_request:url params:params httpRequestType:YJHttpRequestTypePut progressBlock:progressBlock successBlock:successBlock failBlock:failBlock];
}

#pragma mark delete

+ (NSURLSessionTask *)yj_DELRTE:(NSString *)url
                         params:(NSDictionary *)params
                  progressBlock:(YJProgressBlock)progressBlock
                   successBlock:(YJResponseSuccessBlock)successBlock
                      failBlock:(YJResponseFailBlock)failBlock {
    return [self yj_request:url params:params httpRequestType:YJHttpRequestTypeDelete progressBlock:progressBlock successBlock:successBlock failBlock:failBlock];
}


#pragma mark - 取消 Http 请求
/*!
 *  取消所有 Http 请求
 */
+ (void)yj_cancelAllRequest
{
    [YJNetManagerShare yj_cancelAllRequest];
}

- (void)yj_cancelAllRequest {
    // 锁操作
    @synchronized(self)
    {
        [[self tasks] enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            [task cancel];
        }];
        [[self tasks] removeAllObjects];
    }
}

/*!
 *  取消指定 URL 的 Http 请求
 */
+ (void)yj_cancelRequestWithURL:(NSString *)URL{
    [YJNetManagerShare yj_cancelRequestWithURLString:URL];
}

- (void)yj_cancelRequestWithURLString:(NSString *)URLString {
    if (!URLString || URLString.length <= 0){return;}
    @synchronized (self)
    {
        [[self tasks] enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if ([task.currentRequest.URL.absoluteString hasPrefix:URLString])
            {
                [task cancel];
                [[self tasks] removeObject:task];
                *stop = YES;
            }
        }];
    }
}

#pragma mark - setter / getter

/**
 存储着所有的请求task数组
 
 @return 存储着所有的请求task数组
 */
- (NSMutableArray *)tasks
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        NSLog(@"创建数组");
        tasks = [[NSMutableArray alloc] init];
    });
    return tasks;
}

+ (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval
{
    _timeoutInterval = timeoutInterval;
}

//设置网络请求参数的格式
+ (void)setRequestSerializer:(YJHttpRequestSerializer)requestSerializer {
    YJNetManagerShare.sessionManager.requestSerializer = requestSerializer==YJHttpRequestSerializerHTTP ? [AFHTTPRequestSerializer serializer] : [AFJSONRequestSerializer serializer];
}
//设置服务器响应数据格式
+ (void)setResponseSerializer:(YJHttpResponseSerializer)responseSerializer
{
    _httpResponseSerializer = responseSerializer;
}
/**
 *  自定义请求头
 */
+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [YJNetManagerShare.sessionManager.requestSerializer setValue:value forHTTPHeaderField:field];
}

+ (void)setHttpHeaderFieldDictionary:(NSDictionary *)httpHeaderFieldDictionary
{
    if (![httpHeaderFieldDictionary isKindOfClass:[NSDictionary class]])
    {
        NSLog(@"请求头数据有误，请检查！");
        return;
    }
    NSArray *keyArray = httpHeaderFieldDictionary.allKeys;
    
    if (keyArray.count <= 0)
    {
        NSLog(@"请求头数据有误，请检查！");
        return;
    }
    
    for (NSInteger i = 0; i < keyArray.count; i ++)
    {
        NSString *keyString = keyArray[i];
        NSString *valueString = httpHeaderFieldDictionary[keyString];
        
        [YJNetworkManager yj_setValue:valueString forHTTPHeaderKey:keyString];
    }
}


+ (void)yj_setValue:(NSString *)value forHTTPHeaderKey:(NSString *)HTTPHeaderKey
{
    [YJNetManagerShare.sessionManager.requestSerializer setValue:value forHTTPHeaderField:HTTPHeaderKey];
}

/**
 删除所有请求头
 */
+ (void)yj_clearAuthorizationHeader
{
    [[YJNetworkManager sharedYJNetManager] yj_clearAuthorizationHeader];
}

- (void)yj_clearAuthorizationHeader {
    [self.sessionManager.requestSerializer clearAuthorizationHeader];
}

/**
 清空缓存：此方法可能会阻止调用线程，直到文件删除完成。
 */
- (void)yj_clearAllHttpCache
{
    [YJNetworkCache yj_clearAllHttpCache];
}

@end

