//
//  EFTEPackageController.m
//  CRM-Mobile
//
//  Created by ZhouHui on 14-5-26.
//  Copyright (c) 2014年 dianping.com. All rights reserved.
//

#import "EFTEPackageController.h"
#import "EFTEUtil.h"
#import "ZipArchive.h"
#import <MD5Digest/NSString+MD5.h>
#import <CommonCrypto/CommonDigest.h> // Need to import for CC_MD5 access
#import "EFTEEnvironment.h"
#import "EFTEDefines.h"

#define kUserDefaultsPackageManagerUrlKey @"packagemanagerurl"

static EFTEPackageController *gNVHybridController = nil;

void EFTEInternalSetDefaultPackageController(EFTEPackageController *pkgController) {
    gNVHybridController = pkgController;
}

@interface EFTEPackageController ()
@property int atomicTaskCount;
@end

@implementation EFTEPackageController {
    volatile BOOL _canceled;
    dispatch_queue_t _queue;
    
    NSString *_docPath;
    NSString *_docPkgsPath;
    NSString *_configPlistPath;
    NSDictionary *_latestConfig;
    NSString *_url;
}

+ (instancetype)sharedInstance {
    if (gNVHybridController == nil) {
        gNVHybridController = [self new];
    }
    return gNVHybridController;
}

- (id)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        NSString *savedUrl = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaultsPackageManagerUrlKey];
        if (savedUrl.length<1) {
            _url = kEFTEDefaultDownloadURL;
        } else {
            _url = savedUrl;
        }
        
        _queue = dispatch_queue_create("com.efte.packagedownloader", 0);
        
        NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        _docPath = [doc stringByAppendingPathComponent:@"hybrid"];
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDic = NO;
        if (![fm fileExistsAtPath:_docPath isDirectory:&isDic]) {
            [fm createDirectoryAtPath:_docPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        _docPkgsPath = [_docPath stringByAppendingPathComponent:@"packages"];
        _configPlistPath = [_docPath stringByAppendingPathComponent:@"config"];
        [self loadConfig];
        
        [self checkPackages];
    }
    return self;
}

- (NSDictionary *)loadConfig {
    NSString *content = [NSString stringWithContentsOfFile:_configPlistPath encoding:NSUTF8StringEncoding error:nil];
    if (content.length<1) {
        _latestConfig = nil;
    } else {
        _latestConfig = [EFTEUtil string2json:content];
    }
    return _latestConfig;
}

- (void)applicationWillEnterForeground {
    dispatch_resume(_queue);
    if (self.atomicTaskCount<1) {
        [self checkPackages];
    }
}

- (void)applicationDidEnterBackground {
    dispatch_suspend(_queue);
}

//- (void)onDebugChanged {
//    [self checkPackages];
//}

- (BOOL)setPackageDownloadURL:(NSString *)urlString {
    if (![NSURL URLWithString:urlString]) {
        return NO;
    }
    _url = urlString;
    [[NSUserDefaults standardUserDefaults] setObject:urlString forKey:kUserDefaultsPackageManagerUrlKey];
    [self checkPackages];
    return YES;
}

- (BOOL)isCanceled {
    if (_canceled) {
        if ([self.delegate respondsToSelector:@selector(efteDownloadCanceled)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate efteDownloadCanceled];
            });
        }
    }
    return _canceled;
}

#define CHECKCANCEL {if([self isCanceled]) return;}

- (void)checkPackages {
    
    dispatch_async(_queue, ^{
        self.atomicTaskCount++;
        if (![[NSFileManager defaultManager] fileExistsAtPath:_configPlistPath]) {
            if ([self unpackLocalPackages]) {
                [self loadConfig];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kEFTEPackageUpdateFinishedNotification object:nil];
                });
                
            }
        }
        [self main];
        self.atomicTaskCount--;
    });
}

- (BOOL)isUpdating {
    return self.atomicTaskCount>0;
}

#define FileHashDefaultChunkSizeForReadingData 1024*8
CFStringRef FileMD5HashCreateWithPath(CFStringRef filePath,size_t chunkSizeForReadingData) {
    // Declare needed variables
    CFStringRef result = NULL;
    CFReadStreamRef readStream = NULL;
    // Get the file URL
    CFURLRef fileURL =
    CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                  (CFStringRef)filePath,
                                  kCFURLPOSIXPathStyle,
                                  (Boolean)false);
    if (!fileURL) goto done;
    // Create and open the read stream
    readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault,
                                            (CFURLRef)fileURL);
    if (!readStream) goto done;
    bool didSucceed = (bool)CFReadStreamOpen(readStream);
    if (!didSucceed) goto done;
    // Initialize the hash object
    CC_MD5_CTX hashObject;
    CC_MD5_Init(&hashObject);
    // Make sure chunkSizeForReadingData is valid
    if (!chunkSizeForReadingData) {
        chunkSizeForReadingData = FileHashDefaultChunkSizeForReadingData;
    }
    // Feed the data to the hash object
    bool hasMoreData = true;
    while (hasMoreData) {
        uint8_t buffer[chunkSizeForReadingData];
        CFIndex readBytesCount = CFReadStreamRead(readStream,(UInt8 *)buffer,(CFIndex)sizeof(buffer));
        if (readBytesCount == -1) break;
        if (readBytesCount == 0) {
            hasMoreData = false;
            continue;
        }
        CC_MD5_Update(&hashObject,(const void *)buffer,(CC_LONG)readBytesCount);
    }
    // Check if the read operation succeeded
    didSucceed = !hasMoreData;
    // Compute the hash digest
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &hashObject);
    // Abort if the read operation failed
    if (!didSucceed) goto done;
    // Compute the string result
    char hash[2 * sizeof(digest) + 1];
    for (size_t i = 0; i < sizeof(digest); ++i) {
        snprintf(hash + (2 * i), 3, "%02x", (int)(digest[i]));
    }
    result = CFStringCreateWithCString(kCFAllocatorDefault,(const char *)hash,kCFStringEncodingUTF8);
    
done:
    if (readStream) {
        CFReadStreamClose(readStream);
        CFRelease(readStream);
    }
    if (fileURL) {
        CFRelease(fileURL);
    }
    return result;
}

+ (NSString*)getFileMD5WithPath:(NSString*)path
{
    return (__bridge_transfer NSString *)FileMD5HashCreateWithPath((__bridge CFStringRef)path, FileHashDefaultChunkSizeForReadingData);
}

- (BOOL)unpackLocalPackages {
    NSString *localPackagePath = [[EFTEEnvironment defaultEnvironment] localPackageZipPath];
    ZipArchive *zipArchive = [[ZipArchive alloc] init];
    if(![zipArchive UnzipOpenFile:localPackagePath]) {
        EFTELOG(@"unzip fail: open local zip failed");
        return NO;
    }
    if(![zipArchive UnzipFileTo:_docPath overWrite:YES]) {
        [zipArchive UnzipCloseFile];
        EFTELOG(@"unzip fail: unzip local zip failed");
        return NO;
    }
    [zipArchive UnzipCloseFile];
    return YES;
}

- (NSArray *)recursiveRelativePathsInDirectory:(NSString *)directoryPath{
    NSMutableArray *filePaths = [[NSMutableArray alloc] init];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:directoryPath];
    NSString *filePath;
    while ((filePath = [enumerator nextObject]) != nil){
        [filePaths addObject:filePath];
    }
    return filePaths;
}

- (NSString *)checksumOfPackageDic:(NSString *)packageDic {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDic = NO;
    if (![fm fileExistsAtPath:packageDic isDirectory:&isDic] || !isDic) {
        return nil;
    }
    NSError *error = nil;
    NSArray *filesPathList = [self recursiveRelativePathsInDirectory:packageDic];
    if (filesPathList.count<1 || error) {
        return nil;
    }
    NSMutableArray *md5ListOfPathAndContent = [NSMutableArray array];
    //    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    for (NSString *relativePath in filesPathList) {
        NSString *absolutPath = [packageDic stringByAppendingPathComponent:relativePath];
        if (![fm fileExistsAtPath:absolutPath isDirectory:&isDic] || isDic) {
            continue;
        }
        if ([relativePath hasPrefix:@"."]) {
            continue;
        }
        NSString *md5OfPath = [relativePath MD5Digest];
        NSString *md5OfContent = [self checksumOfFile:absolutPath];
        NSString *md5OfPathAndContent = [md5OfPath stringByAppendingString:md5OfContent];
        [md5ListOfPathAndContent addObject:md5OfPathAndContent];
        //        [dict setObject:md5OfContent forKey:relativePath];
    }
    [md5ListOfPathAndContent sortUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj1 compare:obj2];
    }];
    NSString *wholeString = [md5ListOfPathAndContent componentsJoinedByString:@""];
    return [wholeString MD5Digest];
}

- (NSString *)checksumOfFile:(NSString *)filePath {
    return [[self class] getFileMD5WithPath:filePath];
}

- (NSString *)checksumOfFileContent:(NSData *)fileContent {
    if (!fileContent) {
        return nil;
    }
	unsigned char result[16];
	CC_MD5( [fileContent bytes], [fileContent length], result ); // This is the md5 call
	return [NSString stringWithFormat:
			@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			result[0], result[1], result[2], result[3],
			result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11],
			result[12], result[13], result[14], result[15]
			];
}

- (BOOL)validateZipFile:(NSData *)zip withMd5:(NSString *)zipMd5 {
    if ([zip length]>4) {
        const char *zipBytes = (const char *)[zip bytes];
        if (zipBytes[0] == 'P' && zipBytes[1] == 'K' && zipBytes[2] == 3 && zipBytes[3] == 4) {
            // 校验
            if ([[self checksumOfFileContent:zip] isEqualToString:zipMd5]) {
                EFTELOG(@"zip download succ!");
                return YES;
            } else {
                EFTELOG(@"zip file checksum error!");
                return NO;
            }
        } else {
            EFTELOG(@"zip file invalid!");
            return NO;
        }
    } else {
        EFTELOG(@"zip file invalid!");
        return NO;
    }
}

- (NSString *)requestConfig:(NSDictionary **)packageInfo {
    BOOL isDic = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableDictionary *packageInfoDic = [NSMutableDictionary dictionary];
    if ([fm fileExistsAtPath:_docPkgsPath isDirectory:&isDic]) {
        if ([fm fileExistsAtPath:_configPlistPath]) {
            NSDictionary *lastConfig = [self loadConfig];
            NSDictionary *packages = [lastConfig objectForKey:@"packages"];
            for (NSString *key in [packages allKeys]) {
                NSDictionary *package = packages[key];
                NSString *name = [package objectForKey:@"name"];
                NSString *latestVersion = [package objectForKey:@"version"];
                NSString *packageDicPath = [_docPkgsPath stringByAppendingPathComponent:name];
                NSString *checksumOfDic = [self checksumOfPackageDic:[packageDicPath stringByAppendingPathComponent:latestVersion]];
                if (checksumOfDic.length>0) {
                    NSDictionary *info = @{@"name":name, @"version":latestVersion, @"checksum":checksumOfDic};
                    [packageInfoDic setObject:info forKey:name];
                }
            }
        } else {
            EFTELOG(@"no config file");
        }
    } else {
        [fm createDirectoryAtPath:_docPkgsPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    // 构建post包体&发送请求
    NSData *responseData = nil;
    {
        NSMutableDictionary *postDic = [NSMutableDictionary dictionary];
        [postDic setObject:kEFTEAppName forKey:@"appName"];
        [postDic setObject:packageInfoDic forKey:@"packages"];
        [postDic setObject:[self deviceInfo] forKey:@"deviceInfo"];
        EFTELOG(@"hybrid post body:\n%@", postDic);
        NSData *bodyData = [[EFTEUtil json2string:postDic] dataUsingEncoding:NSUTF8StringEncoding];
        //bodyData = [bodyData encodeMobileData];
        
        NSURL *url = [NSURL URLWithString:_url];
        EFTELOG(@"hybrid query config:%@", url);
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60*5];
        [request setHTTPMethod:@"POST"];
        [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        //#ifdef DEBUG
        //            [request addValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
        //#endif
        [request setHTTPBody:bodyData];
        NSURLResponse *response;
        NSError *error = nil;
        responseData = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&error];
        if(error || ([(NSHTTPURLResponse *)response statusCode] != 200) || !responseData) {
            return nil;
        }
    }
    
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    if (packageInfo) {
        *packageInfo = packageInfoDic;
    }
    return responseString;
}

- (NSDictionary *)deviceInfo {
    return @{};
}

- (void)main {
    // check last config file, remove expired packages
    _canceled = NO;
    
    //[_noticeBar showNoticeWithActivityView:@"更新包配置..."];
    BOOL isDic = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tempDicPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"hybrid_temp"];
    if (![fm fileExistsAtPath:tempDicPath isDirectory:&isDic]) {
        [fm createDirectoryAtPath:tempDicPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSDictionary *localPkgInfo = nil;
    NSString *responseString = [self requestConfig:&localPkgInfo];
    if (responseString.length<1) {
        EFTELOG(@"config http failed!");
        if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate eftePackageUpdateFailed:EFTEPackageConfigHttpError];
            });
        }
        return;
    }
    NSDictionary *newConfig = [EFTEUtil string2json:responseString];
    if (!newConfig) {
        EFTELOG(@"config parse failed!");
        if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate eftePackageUpdateFailed:EFTEPackageConfigParseError];
            });
        }
        return;
    }
    EFTELOG(@"receive response:\n%@", newConfig);
    
    NSDictionary *packageConfigs = [newConfig objectForKey:@"packages"];
    NSUInteger needDownloadPackageCount = 0;
    for (NSString *key in [packageConfigs allKeys]) {
        NSDictionary *packageConfig = packageConfigs[key];
        NSString *pkgName = packageConfig[@"name"];
        if (pkgName.length<1) continue;
        NSString *pkgVersion = packageConfig[@"version"];
        if (pkgVersion.length<1) continue;
        NSDictionary *localPackageInfo = localPkgInfo[pkgName];
        NSString *pkgChecksum = packageConfig[@"checksum"];
        if ([pkgVersion isEqualToString:localPackageInfo[@"version"]] && [pkgChecksum isEqualToString:localPackageInfo[@"checksum"]]) {
            // 版本校验相同，无需处理
            EFTELOG(@"package(%@[%@]) no need to update", pkgName, pkgVersion);
            continue;
        }
        needDownloadPackageCount++;
    }
    
    if (needDownloadPackageCount == 0) {
        // 本次不需要更新
        EFTELOG(@"update finished! no package need update");
        if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFinishedWithUsingNetwork:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate eftePackageUpdateFinishedWithUsingNetwork:0];
            });
        }
        return;
    }
    
    // wait update choose
    if ([self.delegate respondsToSelector:@selector(efteWaitDownloadingEftePackages:cancelBlock:)]) {
        static int updateChoose = -1;
        updateChoose = -1;
        [self.delegate efteWaitDownloadingEftePackages:^{
            updateChoose = 1;
        } cancelBlock:^{
            updateChoose = 0;
        }];
        while (updateChoose==-1) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01f]];
        }
        if (updateChoose == 0) {
            EFTELOG(@"download canceled!");
            if ([self.delegate respondsToSelector:@selector(efteDownloadCanceled)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate efteDownloadCanceled];
                });
            }
            return;
        }
    }
    
    // 校验package
    BOOL patchSucc = YES;
    BOOL needMovePatch = NO;
    NSUInteger totalContentLength = 0;
    for (NSString *key in [packageConfigs allKeys]) {
        NSDictionary *packageConfig = packageConfigs[key];
        NSString *pkgName = packageConfig[@"name"];
        if (pkgName.length<1) continue;
        NSString *pkgVersion = packageConfig[@"version"];
        if (pkgVersion.length<1) continue;
        NSDictionary *localPackageInfo = localPkgInfo[pkgName];
        NSString *pkgZipPath = packageConfig[@"zipPath"];
        NSString *pkgTypeString = packageConfig[@"type"];
        EFTEPackageType pkgType;
        if ([pkgTypeString isEqualToString:@"full"]) {
            pkgType = EFTEPackageTypeFull;
        } else if ([pkgTypeString isEqualToString:@"patch"]) {
            pkgType = EFTEPackageTypePatch;
        } else {
            patchSucc = NO;
            EFTELOG(@"unknown type:\"%@\"", pkgTypeString);
            if ([self.delegate respondsToSelector:@selector(eftePackageUpdateWarning:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate eftePackageUpdateWarning:EFTEPackagePackageTypeError];
                });
            }
            break;
        }
        
        NSString *pkgChecksum = packageConfig[@"checksum"];
        if ([pkgVersion isEqualToString:localPackageInfo[@"version"]] && [pkgChecksum isEqualToString:localPackageInfo[@"checksum"]]) {
            // 版本校验相同，无需处理
            continue;
        }
        NSData *zip = nil;
        do {
            EFTELOG(@"begin download zip: %@", pkgZipPath);
            if ([self.delegate respondsToSelector:@selector(eftePackageStartDownloading:type:version:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate eftePackageStartDownloading:pkgName type:pkgType version:pkgVersion];
                });
            }
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:pkgZipPath] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60*5];
            NSURLResponse *response;
            NSError *error = nil;
            zip = [NSURLConnection sendSynchronousRequest:request
                                        returningResponse:&response
                                                    error:&error];
            CHECKCANCEL;
            // content-md5
            if(zip && (!error) && ([(NSHTTPURLResponse *)response statusCode] == 200)) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSUInteger contentLenth = [[[httpResponse allHeaderFields] objectForKey:@"Content-Length"] integerValue];
                totalContentLength += contentLenth;
                NSString *zipMd5 = [[httpResponse allHeaderFields] objectForKey:@"content-md5"];
                if ([self validateZipFile:zip withMd5:zipMd5]) {
                    // validate succ
                    if ([self.delegate respondsToSelector:@selector(eftePackageDownloadFinished:dataLength:)]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate eftePackageDownloadFinished:pkgName dataLength:contentLenth];
                        });
                    }
                    break;
                }
                EFTELOG(@"zip download validate failed!");
                // validate failed
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageDownloadValidateError];
                    });
                }
            } else {
                // http error
                EFTELOG(@"zip download fail! error code:%ld", (long)[(NSHTTPURLResponse *)response statusCode]);
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageDownloadHttpError];
                    });
                }
            }
            zip = nil;
        } while (NO);
        
        // 解压package
        CHECKCANCEL;
        if (!zip) {
            patchSucc = NO;
            break;
        }
        
        NSString *tempPkgDic = [tempDicPath stringByAppendingPathComponent:pkgName];
        if ([fm fileExistsAtPath:tempPkgDic isDirectory:&isDic]) {
            [fm removeItemAtPath:tempPkgDic error:nil];
        }
        [fm createDirectoryAtPath:tempPkgDic withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *tmpZipPath = [tempPkgDic stringByAppendingPathComponent:@"zip"];
        [zip writeToFile:tmpZipPath atomically:YES];
        NSString *tmpZipDic = [tempPkgDic stringByAppendingPathComponent:@"zipfiles"];
        BOOL unzipSucc = NO;
        do {
            ZipArchive *zipArchive = [[ZipArchive alloc] init];
            if(![zipArchive UnzipOpenFile:tmpZipPath]) {
                EFTELOG(@"unzip fail: open file(%@) failed", tmpZipPath);
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageUnzipError];
                    });
                }
                patchSucc = NO;
                break;
            }
            if(![zipArchive UnzipFileTo:tmpZipDic overWrite:YES]) {
                [zipArchive UnzipCloseFile];
                EFTELOG(@"unzip fail: unzip file(%@) failed", tmpZipPath);
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageUnzipError];
                    });
                }
                patchSucc = NO;
                break;
            }
            [zipArchive UnzipCloseFile];
            unzipSucc = YES;
        } while (NO);
        [fm removeItemAtPath:tmpZipPath error:NULL];
        if (!unzipSucc) {
            patchSucc = NO;
            break;
        }
        
        // Patch
        CHECKCANCEL;
        if (EFTEPackageTypeFull == pkgType) {
            /****** full type package ******/
            // checksum
            NSString *realChecksum = [self checksumOfPackageDic:tmpZipDic];
            if (![realChecksum isEqualToString:pkgChecksum]) {
                [fm removeItemAtPath:tmpZipDic error:nil];
                EFTELOG(@"full pkg checksum failed:\nrequire:%@, \nreal   :%@", pkgChecksum, realChecksum);
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageChecksumError];
                    });
                }
                patchSucc = NO;
                break;
            }
            NSString *tmpPkgVersionDic = [tempPkgDic stringByAppendingPathComponent:pkgVersion];
            if ([fm fileExistsAtPath:tmpPkgVersionDic isDirectory:&isDic]) {
                [fm removeItemAtPath:tmpPkgVersionDic error:nil];
            }
            NSError *error = nil;
            // 将解压的文件夹修改成对应的版本文件夹
            if (![fm moveItemAtPath:tmpZipDic toPath:tmpPkgVersionDic error:&error]) {
                EFTELOG(@"full pkg move files failed:%@", error);
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageFileError];
                    });
                }
                patchSucc = NO;
                break;
            }
            needMovePatch = YES;
        } else {
            /****** patch type package ******/
            NSString *patchDir = [tempPkgDic stringByAppendingPathComponent:@"__temp_patch_dic"];
            if (![self patchForPkg:pkgName withTempPkgDir:tempPkgDic withPatchDir:patchDir]) {
                EFTELOG(@"patch pkg(%@) failed", pkgName);
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageFileError];
                    });
                }
                patchSucc = NO;
                break;
            }
            // checksum
            NSString *realChecksum = [self checksumOfPackageDic:patchDir];
            if (![realChecksum isEqualToString:pkgChecksum]) {
                [fm removeItemAtPath:patchDir error:nil];
                EFTELOG(@"patch pkg checksum failed:{requal:%@, real:%@}", pkgChecksum, realChecksum);
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageChecksumError];
                    });
                }
                patchSucc = NO;
                break;
            }
            NSError *error = nil;
            // 将解压的文件夹修改成对应的版本文件夹
            NSString *tmpPkgVersionDic = [tempPkgDic stringByAppendingPathComponent:pkgVersion];
            if ([fm fileExistsAtPath:tmpPkgVersionDic isDirectory:&isDic]) {
                [fm removeItemAtPath:tmpPkgVersionDic error:nil];
            }
            if (![fm moveItemAtPath:patchDir toPath:tmpPkgVersionDic error:&error]) {
                EFTELOG(@"patch pkg move files failed:%@", error);
                if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eftePackageUpdateFailed:EFTEPackageFileError];
                    });
                }
                patchSucc = NO;
                break;
            }
            needMovePatch = YES;
        }
    }
    
    // 完成
    CHECKCANCEL;
    if (patchSucc) {
        if (needMovePatch) {
            NSError *error = nil;
            for (NSString *key in [packageConfigs allKeys]) {
                NSDictionary *packageConfig = packageConfigs[key];
                NSString *pkgName = packageConfig[@"name"];
                NSString *pkgVersion = packageConfig[@"version"];
                NSString *tempPkgDicPath = [[tempDicPath stringByAppendingPathComponent:pkgName] stringByAppendingPathComponent:pkgVersion];
                if ([fm fileExistsAtPath:tempPkgDicPath isDirectory:&isDic]) {
                    NSString *documentPkgNamePath = [_docPkgsPath stringByAppendingPathComponent:pkgName];
                    if (![fm fileExistsAtPath:documentPkgNamePath]) {
                        [fm createDirectoryAtPath:documentPkgNamePath withIntermediateDirectories:YES attributes:nil error:&error];
                    }
                    NSString *documentPkgVersionPath = [documentPkgNamePath stringByAppendingPathComponent:pkgVersion];
                    if ([fm fileExistsAtPath:documentPkgVersionPath]) {
                        [fm removeItemAtPath:documentPkgVersionPath error:&error];
                    }
                    
                    
                    if (![fm moveItemAtPath:tempPkgDicPath toPath:documentPkgVersionPath error:&error]) {
                        EFTELOG(@"move pkg(%@:%@) error: %@", pkgName, pkgVersion, error);
                        if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFailed:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.delegate eftePackageUpdateFailed:EFTEPackageFileError];
                            });
                        }
                        return;
                    }
                    [fm removeItemAtPath:[tempDicPath stringByAppendingPathComponent:pkgName] error:&error];
                }
            }
        }
        [responseString writeToFile:_configPlistPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        _latestConfig = newConfig;
        EFTELOG(@":-):-):-):-):-):-):-):-):-)patch succ, la la la!");
        if ([self.delegate respondsToSelector:@selector(eftePackageUpdateFinishedWithUsingNetwork:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate eftePackageUpdateFinishedWithUsingNetwork:totalContentLength];
            });
        }
        if (needMovePatch) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kEFTEPackageUpdateFinishedNotification object:nil];
            });
        } else {
            //[_noticeBar showNotice:[NSString stringWithFormat:@"所有模块已是最新，无需更新"] autoHide:YES activityHide:YES];
        }
    } else {
        EFTELOG(@":-(:-(:-(:-(:-(:-(:-(:-(:-(patch fail, shit!");
    }
}

- (BOOL)patchForPkg:(NSString *)pkgName withTempPkgDir:(NSString *)tempPkgDic withPatchDir:(NSString *)tmpPatchDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmpZipDic = [tempPkgDic stringByAppendingPathComponent:@"zipfiles"];
    NSString *directivesPath = [tmpZipDic stringByAppendingPathComponent:@"directives.txt"];
    if (![fm fileExistsAtPath:directivesPath]) {
        EFTELOG(@"patch pkg directives.txt file not exist!");
        return NO;
    }
    NSString *originPath = [self pathForUnit:pkgName];
    NSError *error = nil;
    if (![fm copyItemAtPath:originPath toPath:tmpPatchDir error:&error]) {
        EFTELOG(@"patch pkg copy files failed:%@", error);
        return NO;
    }
    
    NSString *directives = [NSString stringWithContentsOfFile:directivesPath encoding:NSUTF8StringEncoding error:&error];
    NSArray *commandList = [directives componentsSeparatedByString:@"\n"];
    if (commandList.count < 1) {
        EFTELOG(@"patch pkg no directives in directives.txt");
        return NO;
    }
    BOOL isDic;
    for (NSString *commandString in commandList) {
        NSArray *command = [commandString componentsSeparatedByString:@" "];
        if (command.count<2 || [command[0] length]<1) {
            EFTELOG(@"wrong patch command: [%@]", commandString);
            return NO;
        }
        switch ([command[0] UTF8String][0]) {
            case 'R':
            {
                if (command.count<3) {
                    EFTELOG(@"wrong patch command: [%@]", commandString);
                    return NO;
                }
                NSString *toPath = [tmpPatchDir stringByAppendingPathComponent:command[2]];
                NSString *lastDir = [toPath stringByDeletingLastPathComponent];
                if (![fm fileExistsAtPath:lastDir isDirectory:&isDic]) {
                    [fm createDirectoryAtPath:lastDir withIntermediateDirectories:YES attributes:nil error:nil];
                }
                if (![fm moveItemAtPath:[tmpPatchDir stringByAppendingPathComponent:command[1]] toPath:toPath error:&error]) {
                    EFTELOG(@"patch command [%@] error:%@", commandString, error);
                    return NO;
                }
                break;
            }
            case 'C':
            {
                if (command.count<3) {
                    EFTELOG(@"wrong patch command: [%@]", commandString);
                    return NO;
                }
                NSString *toPath = [tmpPatchDir stringByAppendingPathComponent:command[2]];
                NSString *lastDir = [toPath stringByDeletingLastPathComponent];
                if (![fm fileExistsAtPath:lastDir isDirectory:&isDic]) {
                    [fm createDirectoryAtPath:lastDir withIntermediateDirectories:YES attributes:nil error:nil];
                }
                if (![fm copyItemAtPath:[tmpPatchDir stringByAppendingPathComponent:command[1]] toPath:toPath error:&error]) {
                    EFTELOG(@"patch command [%@] error:%@", commandString, error);
                    return NO;
                }
                break;
            }
            case 'M':
            case 'A':
            {
                if (command.count<2) {
                    EFTELOG(@"wrong patch command: [%@]", commandString);
                    return NO;
                }
                NSString *toPath = [tmpPatchDir stringByAppendingPathComponent:command[1]];
                NSString *lastDir = [toPath stringByDeletingLastPathComponent];
                if (![fm fileExistsAtPath:lastDir isDirectory:&isDic]) {
                    [fm createDirectoryAtPath:lastDir withIntermediateDirectories:YES attributes:nil error:nil];
                }
                if (![fm copyItemAtPath:[tmpZipDic stringByAppendingPathComponent:command[1]] toPath:toPath error:&error]) {
                    EFTELOG(@"patch command [%@] error:%@", commandString, error);
                    return NO;
                }
                break;
            }
            case 'D':
            {
                if (command.count<2) {
                    EFTELOG(@"wrong patch command: [%@]", commandString);
                    return NO;
                }
                if (![fm removeItemAtPath:[tmpPatchDir stringByAppendingPathComponent:command[1]] error:&error]) {
                    EFTELOG(@"patch command [%@] error:%@", commandString, error);
                    return NO;
                }
                break;
            }
            default:
                break;
        }
    }
    return YES;
}

- (NSString *)pathForUnit:(NSString *)pkgName {
    if (_docPkgsPath.length<1 || _latestConfig.allKeys.count<1) {
        return nil;
    }
    NSDictionary *packageConfig = _latestConfig[@"packages"][pkgName];
    NSString *name = packageConfig[@"name"];
    if (name.length<1) return nil;
    NSString *version = packageConfig[@"version"];
    if (version.length<1) return nil;
    return [[_docPkgsPath stringByAppendingPathComponent:pkgName] stringByAppendingPathComponent:version];
}

- (NSString *)pathForPkg:(NSString *)pkgName {
    if (_docPkgsPath.length<1 || _latestConfig.allKeys.count<1) {
        return nil;
    }
    NSDictionary *packageConfig = _latestConfig[@"packages"][pkgName];
    NSString *name = packageConfig[@"name"];
    if (name.length<1) return nil;
    NSString *version = packageConfig[@"version"];
    if (version.length<1) return nil;
    return [self pathForPkg:name withVersion:version];
}

- (NSString *)currentVersionOfPkg:(NSString *)pkgName {
    if (_docPkgsPath.length<1 || _latestConfig.allKeys.count<1) {
        return nil;
    }
    NSDictionary *packageConfig = _latestConfig[@"packages"][pkgName];
    NSString *version = packageConfig[@"version"];
    if (version.length<1) return nil;
    return version;
}

- (NSString *)pathForPkg:(NSString *)pkgName withVersion:(NSString *)version {
    if (_docPkgsPath.length<1) {
        return nil;
    }
    return [[[[_docPkgsPath stringByAppendingPathComponent:pkgName] stringByAppendingPathComponent:version] stringByAppendingPathComponent:pkgName] stringByAppendingPathComponent:version];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
