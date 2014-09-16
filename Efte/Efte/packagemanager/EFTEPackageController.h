//
//  EFTEPackageController.h
//  CRM-Mobile
//
//  Created by ZhouHui on 14-5-26.
//  Copyright (c) 2014年 dianping.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 package download & patch finished notification
 */
#define kEFTEPackageUpdateFinishedNotification  @"EFTEPackageUpdateFinished"

typedef enum {
    EFTEPackageConfigHttpError = 100,   // config request error
    EFTEPackageConfigParseError,        // config parse error
    EFTEPackagePackageTypeError,        // package type error
    EFTEPackageDownloadHttpError,       // download package error
    EFTEPackageDownloadValidateError,   // downloaded package validate error
    EFTEPackageUnzipError,              // package unzip with error
    EFTEPackageChecksumError,           // package checksum erro
    EFTEPackageFileError,               // package file error
} EFTEPackageUpdateErrorCode;

typedef enum {
    EFTEPackageTypeFull = 0,
    EFTEPackageTypePatch
} EFTEPackageType;

typedef void (^EFTEBlock)(void);

@protocol EFTEPackageDelegate;
@interface EFTEPackageController : NSObject

@property (nonatomic, weak) id <EFTEPackageDelegate> delegate;
@property (nonatomic, readonly) BOOL isUpdating;
@property (nonatomic, strong) NSString *appName;

+ (instancetype)sharedInstance;

- (NSString *)pathForPkg:(NSString *)pkgName;
- (BOOL)setPackageDownloadURL:(NSString *)url;

// for impliment
- (NSDictionary *)deviceInfo;

// force
- (void)updatePackages:(BOOL)force;

@end



@protocol EFTEPackageDelegate <NSObject>

@optional
// update failed, will stop update
- (void)eftePackageUpdateFailed:(EFTEPackageUpdateErrorCode)errorCode;
// update with warning, will continue update process
- (void)eftePackageUpdateWarning:(EFTEPackageUpdateErrorCode)errorCode;
- (void)eftePackageUpdateFinishedWithUsingNetwork:(NSUInteger)networkCount;
- (void)efteWaitDownloadingEftePackages:(EFTEBlock)startBlock cancelBlock:(EFTEBlock)cancelBlock;
- (void)efteDownloadCanceled;

- (void)eftePackageStartDownloading:(NSString *)packageName type:(EFTEPackageType)type version:(NSString *)version;
- (void)eftePackageDownloadFinished:(NSString *)packageName dataLength:(NSUInteger)dataLength;

@end


void EFTEInternalSetDefaultPackageController(EFTEPackageController *pkgController);

