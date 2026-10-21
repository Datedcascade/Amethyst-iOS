#import "ModpackLoaderInstaller.h"
#import "LoaderInstallPlan.h"
#import "ModpackUtils.h"
#import "MinecraftResourceDownloadTask.h"
#import "LauncherNavigationController.h"
#import "UnzipKit.h"
#include <CommonCrypto/CommonDigest.h>

static NSError *AMLoaderError(NSString *message) {
    return [NSError errorWithDomain:@"ModpackLoader" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}
static NSString *AMSHA1(NSData *data) {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString new];
    for (int i=0; i<CC_SHA1_DIGEST_LENGTH; i++) [result appendFormat:@"%02x", digest[i]];
    return result;
}
static NSData *AMFetch(NSString *url, NSError **error) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *result;
    __block NSError *failure;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setValue:@"Amethyst-Personal-Build" forHTTPHeaderField:@"User-Agent"];
    request.timeoutInterval = 120;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        failure = networkError;
        if (!failure && [(NSHTTPURLResponse *)response statusCode] != 200) failure = AMLoaderError([NSString stringWithFormat:@"Loader download failed (HTTP %ld): %@", (long)[(NSHTTPURLResponse *)response statusCode], url]);
        if (!failure) result = data;
        dispatch_semaphore_signal(done);
    }];
    [task resume];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    if (error) *error = failure;
    return result;
}
static NSDictionary *AMJSON(NSData *data, NSError **error) {
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:error] : nil;
    return [object isKindOfClass:NSDictionary.class] ? object : nil;
}
static BOOL AMWrite(NSData *data, NSString *path, NSError **error) {
    return data && [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error] && [data writeToFile:path options:NSDataWritingAtomic error:error];
}

@implementation ModpackLoaderInstaller
+ (NSString *)pendingPath { return [@(getenv("GAME_DIR")) stringByAppendingPathComponent:@"amethyst-pending-loader.json"]; }
+ (NSDictionary *)prepareDependencies:(NSDictionary *)dependencies downloader:(MinecraftResourceDownloadTask *)downloader error:(NSError **)error {
    NSCAssert(!NSThread.isMainThread, @"Resolve loader downloads off the main queue");
    NSDictionary *info = [ModpackUtils infoForDependencies:dependencies];
    if (!dependencies[@"forge"] && !dependencies[@"neoforge"]) return info;
    NSDictionary *plan = AMLoaderInstallPlan(dependencies);
    if (!plan) { if (error) *error = AMLoaderError(@"The pack has an invalid loader version."); return nil; }
    NSString *root = @(getenv("GAME_DIR"));
    NSString *(^versionPath)(NSString *) = ^NSString *(NSString *identifier) {
        return [NSString stringWithFormat:@"%@/versions/%@/%@.json", root, identifier, identifier];
    };
    // Reuse the exact installed version, never silently substitute the newest.
    NSDictionary *existing = AMJSON([NSData dataWithContentsOfFile:versionPath(plan[@"id"])], nil);
    if ([existing[@"id"] isEqual:plan[@"id"]] && [existing[@"inheritsFrom"] isEqual:plan[@"minecraft"]]) return info;
    NSLog(@"[ModpackLoader] Preparing %@ %@ for Minecraft %@", plan[@"loader"], plan[@"loaderVersion"], plan[@"minecraft"]);
    NSData *checksumData = AMFetch([plan[@"url"] stringByAppendingString:@".sha1"], error);
    if (!checksumData) return nil;
    NSString *checksum = [[[NSString alloc] initWithData:checksumData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (checksum.length < 40) { if (error) *error = AMLoaderError(@"The loader server returned an invalid checksum."); return nil; }
    checksum = [[checksum substringToIndex:40] lowercaseString];
    NSData *installerData = AMFetch(plan[@"url"], error);
    if (!installerData || downloader.progress.cancelled) return nil;
    if (![AMSHA1(installerData) isEqual:checksum]) { if (error) *error = AMLoaderError(@"Forge/NeoForge installer checksum verification failed."); return nil; }
    NSString *path = [NSString stringWithFormat:@"%@/amethyst-loaders/%@/installer.jar", root, plan[@"id"]];
    if (!AMWrite(installerData, path, error)) return nil;
    installerData = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:path error:error];
    NSDictionary *install = AMJSON([archive extractDataFromFile:@"install_profile.json" error:error], error);
    if (!install) return nil;
    NSDictionary *version = install[@"versionInfo"];
    if (![version isKindOfClass:NSDictionary.class]) {
        NSString *jsonMember = install[@"json"];
        if (![jsonMember isKindOfClass:NSString.class]) { if (error) *error = AMLoaderError(@"Unsupported loader installer metadata."); return nil; }
        version = AMJSON([archive extractDataFromFile:[jsonMember stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]] error:error], error);
    }
    NSString *identifier = version[@"id"];
    if (!AMSafeVersionComponent(identifier) || ![version[@"inheritsFrom"] isEqual:plan[@"minecraft"]]) {
        if (error) *error = AMLoaderError(@"The installer does not match the pack's Minecraft version."); return nil;
    }
    // Very old installers are jarmod archives: extract their universal library,
    // publish their version JSON, and let normal Play download other libraries.
    NSDictionary *legacy = install[@"install"];
    if ([legacy isKindOfClass:NSDictionary.class]) {
        NSArray *coordinate = [legacy[@"path"] componentsSeparatedByString:@":"];
        if (coordinate.count != 3 || ![legacy[@"filePath"] isKindOfClass:NSString.class]) { if (error) *error = AMLoaderError(@"Invalid legacy Forge installer."); return nil; }
        for (NSString *part in coordinate) if (!AMSafeVersionComponent(part)) { if (error) *error = AMLoaderError(@"Invalid legacy Forge library path."); return nil; }
        NSString *library = [NSString stringWithFormat:@"%@/libraries/%@/%@/%@/%@-%@.jar", root, [coordinate[0] stringByReplacingOccurrencesOfString:@"." withString:@"/"], coordinate[1], coordinate[2], coordinate[1], coordinate[2]];
        NSData *universal = [archive extractDataFromFile:legacy[@"filePath"] error:error];
        if (!AMWrite(universal, library, error) || !AMWrite([NSJSONSerialization dataWithJSONObject:version options:0 error:error], versionPath(identifier), error)) return nil;
        return @{@"id": identifier};
    }
    // Installers may require the vanilla client even though the pack itself is
    // not launched yet. Obtain it through Mojang's official version metadata.
    NSString *minecraft = plan[@"minecraft"];
    NSDictionary *base;
    NSData *baseData;
    NSString *basePath = versionPath(minecraft);
    for (NSDictionary *entry in remoteVersionList.copy) if ([entry[@"id"] isEqual:minecraft]) {
        baseData = AMFetch(entry[@"url"], error);
        if (baseData && entry[@"sha1"] && ![AMSHA1(baseData) isEqual:entry[@"sha1"]]) { if (error) *error = AMLoaderError(@"Minecraft version metadata verification failed."); return nil; }
        base = AMJSON(baseData, error); break;
    }
    if (!base) { if (error && !*error) *error = AMLoaderError(@"Minecraft version metadata is unavailable. Reopen the launcher with an internet connection and try again."); return nil; }
    if (!AMWrite(baseData, basePath, error)) return nil;
    NSDictionary *client = base[@"downloads"][@"client"];
    NSString *clientPath = [basePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:[minecraft stringByAppendingString:@".jar"]];
    NSURLSessionDownloadTask *task = [downloader createDownloadTask:client[@"url"] size:[client[@"size"] unsignedLongLongValue] sha:client[@"sha1"] altName:nil toPath:clientPath];
    [task resume];
    int javaVersion = MAX(8, [base[@"javaVersion"][@"majorVersion"] intValue]);
    downloader.loaderInstallRequest = [@{@"schema": @1, @"status": @"ready", @"installerPath": path, @"gameRoot": root,
        @"minecraft": minecraft, @"versionID": identifier, @"javaVersion": @(javaVersion), @"loader": plan[@"loader"], @"loaderVersion": plan[@"loaderVersion"]} mutableCopy];
    return @{@"id": identifier};
}
@end

