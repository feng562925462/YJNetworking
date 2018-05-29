//
//  YJNetworkItem.h
//  YJNetworking
//
//  Created by cool on 2018/5/12.
//  Copyright © 2018 cool. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/*! 使用枚举NS_ENUM:区别可判断编译器是否支持新式枚举,支持就使用新的,否则使用旧的 */
typedef NS_ENUM(NSUInteger, YJNetworkStatus)
{
    /*! 未知网络 */
    YJNetworkStatusUnknown           = 0,
    /*! 没有网络 */
    YJNetworkStatusNotReachable,
    /*! 手机 3G/4G 网络 */
    YJNetworkStatusReachableViaWWAN,
    /*! wifi 网络 */
    YJNetworkStatusReachableViaWiFi
};

/*！定义请求类型的枚举 */
typedef NS_ENUM(NSUInteger, YJHttpRequestType)
{
    /*! get请求 */
    YJHttpRequestTypeGet = 0,
    /*! post请求 */
    YJHttpRequestTypePost,
    /*! put请求 */
    YJHttpRequestTypePut,
    /*! delete请求 */
    YJHttpRequestTypeDelete
};

typedef NS_ENUM(NSUInteger, YJHttpRequestSerializer) {
    /** 设置请求数据为JSON格式*/
    YJHttpRequestSerializerJSON,
    /** 设置请求数据为HTTP格式*/
    YJHttpRequestSerializerHTTP,
};

typedef NS_ENUM(NSUInteger, YJHttpResponseSerializer) {
    /** 设置响应数据为JSON格式*/
    YJHttpResponseSerializerJSON,
    /** 设置响应数据为HTTP格式*/
    YJHttpResponseSerializerHTTP,
};

/*! 实时监测网络状态的 block */
typedef void(^YJNetworkStatusBlock)(YJNetworkStatus status);

/*! 定义请求成功的 block */
typedef void( ^YJResponseSuccessBlock)(id response);
/*! 定义请求失败的 block */
typedef void( ^YJResponseFailBlock)(NSError *error);

/*! 定义进度 block */
typedef void( ^YJProgressBlock)(int64_t bytesProgress,
                                       int64_t totalBytesProgress);


/** 请求实体，承载请求参数 */
@interface YJNetworkItem : NSObject
/** 请求路径 */
@property (nonatomic, copy) NSString *urlString;
/** 请求参数 */
@property (nonatomic, copy) id parameters;
/** 是否缓存响应,只有 get / post 请求有缓存配置*/
@property (nonatomic, assign, getter=isNeedCache) BOOL needCache;

/**
 创建的请求的超时间隔（以秒为单位)默认超时时间间隔为30秒。
 */
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

/** 请求类型 get / post / put / delete */
@property (nonatomic, assign) YJHttpRequestType httpRequestType;
/** 请求成功的回调 */
@property (nonatomic, assign) YJResponseSuccessBlock successBlock;
/** 请求失败的回调 */
@property (nonatomic, assign) YJResponseFailBlock failureBlock;
/** 进度 */
@property (nonatomic, assign) YJProgressBlock progressBlock;
@end

@interface YJNetworkFileItem : YJNetworkItem

/** 文件名字 */
@property (nonatomic, copy) NSString *fileName;

/**
 1、如果是上传操作，为上传文件的本地沙河路径
 2、如果是下载操作，为下载文件保存路径
 */
@property (nonatomic, copy) NSString *filePath;

@end

@interface YJNetworkImageItem : YJNetworkItem

/** 上传的图片数组 */
@property (nonatomic, copy) NSArray *imageArray;
/** 图片名称 */
@property (nonatomic, copy) NSArray<NSString *> *fileNames;
/** 图片类型 png、jpg、gif */
@property (nonatomic, copy) NSString *imageType;
/** 图片压缩比率（0~1.0）*/
@property (nonatomic, assign) CGFloat imageScale;

@end
