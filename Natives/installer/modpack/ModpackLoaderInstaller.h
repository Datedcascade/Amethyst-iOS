#import <Foundation/Foundation.h>
@class MinecraftResourceDownloadTask;
@interface ModpackLoaderInstaller : NSObject
+ (NSDictionary *)prepareDependencies:(NSDictionary *)dependencies downloader:(MinecraftResourceDownloadTask *)downloader error:(NSError **)error;
+ (NSString *)pendingPath;
@end

