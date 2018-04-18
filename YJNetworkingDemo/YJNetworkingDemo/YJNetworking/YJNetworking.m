//
//  YJNetworking.m
//  YJNetworking
//
//  Created by cool on 2018/4/12.
//  Copyright © 2018年 cool. All rights reserved.
//

#import "YJNetworking.h"
#import "AFNetworking.h"
#import "AFNetworkActivityIndicatorManager.h"

static AFNetworkReachabilityStatus networkReachabilityStatus = 0;
static NSMutableArray<NSURLSessionTask *>  *allSessionTask;//请求任务池

@interface YJNetworking()

@property (assign, nonatomic) AFHTTPSessionManager *manager;
@end

@implementation YJNetworking

- (NSArray<NSURLSessionTask *> *)yj_allSessionTask {
    return allSessionTask.copy;
}

+ (void)load{
    //开始监听网络
    // 检测网络连接的单例,网络变化时的回调方法
    AFNetworkReachabilityManager *manager = [AFNetworkReachabilityManager sharedManager];
    [manager startMonitoring];
    [manager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        networkReachabilityStatus = status;
    }];
}

+ (instancetype)sharedInstance{
    static YJNetworking *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        instance = [[self alloc] init];
        allSessionTask = [NSMutableArray array];
    });
    return instance;
}

#pragma mark - manager
- (AFHTTPSessionManager *)manager {
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    if (!_manager) {
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        //默认解析模式
        manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        
        /// 默认响应数据为二进制
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
        
        //配置响应序列化
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithArray:@[@"application/json", @"text/html", @"text/json", @"text/plain", @"text/javascript", @"text/xml", @"image/*", @"application/octet-stream", @"application/zip"]];
        _manager = manager;
    }
    
    return _manager;
}

- (NSDictionary *)yj_processingParameters:(NSDictionary *)parameters URLStr:(NSString *)URLStr {
    return parameters;
}

- (NSString *)yj_processingURLStr:(NSString *)URLStr {
    
    if (URLStr == nil || URLStr.length <= 0) {
        return URLStr;
    }
    
    if ([URLStr hasPrefix:@"http://"] || [URLStr hasPrefix:@"https://"]) {
        return URLStr;
    }
    
    if ([URLStr hasPrefix:@"http:"]) {
        return [URLStr stringByReplacingOccurrencesOfString:@"http:" withString:@"http://"];
    }
    
    if ([URLStr hasPrefix:@"https:"]) {
        return [URLStr stringByReplacingOccurrencesOfString:@"https:" withString:@"https://"];
    }
    
    if ([URLStr hasPrefix:@"//"]) {
        return [URLStr stringByReplacingOccurrencesOfString:@"//" withString:@"http://"];
    }
    
    return [NSString stringWithFormat:@"http://%@", URLStr];
}

- (NSTimeInterval)yj_timeoutIntervalWithURLStr:(NSString *)URLStr {
    return 30.f;
}

- (BOOL)yj_network:(NSString *)url params:(NSDictionary *)params task:(NSURLSessionTask *)task result:(id)result error:(NSError *)error {
    
    if (task && allSessionTask.count > 0) {
        [allSessionTask removeObject:task];
    }
    
    return NO;
}

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

- (NSData *)yj_sampleData:(NSString *)url params:(NSDictionary *)params {
    return nil;
}

- (NSURLSessionTask *)GET:(NSString *)url params:(NSDictionary *)params successBlock:(YJResponseSuccessBlock)successBlock failBlock:(YJResponseFailBlock)failBlock {
    
    return [self yj_network:(YJRequestTypeGET) url:url params:params timeoutInterval:0 responseDataType:(kYJResponseDataTypeJSON) progressBlock:nil successBlock:successBlock failBlock:failBlock];
}

- (NSURLSessionTask *)POST:(NSString *)url params:(NSDictionary *)params successBlock:(YJResponseSuccessBlock)successBlock failBlock:(YJResponseFailBlock)failBlock {
    return [self yj_network:(YJRequestTypePOST) url:url params:params timeoutInterval:0 responseDataType:(kYJResponseDataTypeJSON) progressBlock:nil successBlock:successBlock failBlock:failBlock];
}

- (NSURLSessionTask *)yj_network:(YJRequestType)requestType
                          url:(NSString *)url
                       params:(NSDictionary *)params
              timeoutInterval:(NSTimeInterval)timeoutInterval
             responseDataType:(YJResponseDataType)responseDataType
                progressBlock:(YJDownloadProgress)progressBlock
                 successBlock:(YJResponseSuccessBlock)successBlock
                    failBlock:(YJResponseFailBlock)failBlock {
    
    url = [self yj_processingURLStr:url];
    
    params = [self yj_processingParameters:params URLStr:url];
    
    //将session拷贝到堆中，block内部才可以获取得到session
    __block NSURLSessionTask *session = nil;
    AFHTTPSessionManager *manager = [self manager];
    
    manager.requestSerializer.timeoutInterval = timeoutInterval > 0 ? timeoutInterval :[self yj_timeoutIntervalWithURLStr:url];
    
    /// 如果url为空直接返回error
    if (url == nil || url.length <= 0) {
        NSError *urlNULL = [NSError errorWithDomain:@"domain" code:999 userInfo:@{NSLocalizedDescriptionKey:@"url error"}];
        
        BOOL isValid = [self yj_network:url params:params task:session result:nil error:urlNULL];
        
        if (failBlock && isValid) {
            failBlock(urlNULL);
        }
        return session;
    }
    
    // 获取样本数据
    NSData *data = [self yj_sampleData:url params:params];
    
    if (data && data.length > 0) {
        
        id result = data;
        
        if (responseDataType == kYJResponseDataTypeJSON) {
            result = [self dataFormat:data];
        }
        
        BOOL isValid = [self yj_network:url params:params task:session result:result error:nil];
        
        if (successBlock && isValid) {
            successBlock(result);
        }
        
        return session;
    }
    
    //网络验证
    if (networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
        NSError *urlNULL = [NSError errorWithDomain:@"domain" code:998 userInfo:@{NSLocalizedDescriptionKey:@"no network"}];
        
        BOOL isValid = [self yj_network:url params:params task:session result:nil error:urlNULL];
        
        if (failBlock && isValid) {
            failBlock(urlNULL);
        }
        return session;
    }
    
    if (requestType == YJRequestTypeGET) {
        session = [manager GET:url parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progressBlock) {
                progressBlock(downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
            }
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            id result = responseObject;
            
            if (responseDataType == kYJResponseDataTypeJSON) {
                result = [self dataFormat:responseObject];
            }
            
            BOOL isValid = [self yj_network:url params:params task:task result:result error:nil];
            
            if (successBlock && isValid) {
                successBlock(result);
            }
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
            BOOL isValid = [self yj_network:url params:params task:task result:nil error:error];
            
            if (failBlock && isValid) {
                failBlock(error);
            }
        }];
    }
    
    if (requestType == YJRequestTypePOST) {
        session = [manager POST:url parameters:params progress:^(NSProgress * _Nonnull uploadProgress) {
            if (progressBlock) {
                progressBlock(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
            }
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            id result = responseObject;
            
            if (responseDataType == kYJResponseDataTypeJSON) {
                result = [self dataFormat:responseObject];
            }
            
            BOOL isValid = [self yj_network:url params:params task:task result:result error:nil];
            
            if (successBlock && isValid) {
                successBlock(result);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            BOOL isValid = [self yj_network:url params:params task:task result:nil error:error];
            
            if (failBlock && isValid) {
                failBlock(error);
            }
        }];
    }
    
    //判断重复请求，如果有重复请求，取消新请求
//    if ([self haveSameRequestInTasksPool:session]) {
//        [session cancel];
//        return session;
//    }
    
    if ([allSessionTask containsObject:session]) {
    }
    
    [allSessionTask addObject:session];
    
    return session;
}

@end


