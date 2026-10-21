#import <Foundation/Foundation.h>

static inline BOOL AMSafeVersionComponent(NSString *value) {
    if (![value isKindOfClass:NSString.class] || !value.length || [value hasPrefix:@"."]) return NO;
    return [value rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"] invertedSet]].location == NSNotFound;
}

static inline NSDictionary *AMLoaderInstallPlan(NSDictionary *dependencies) {
    NSString *minecraft = dependencies[@"minecraft"];
    NSString *kind = dependencies[@"forge"] ? @"forge" : (dependencies[@"neoforge"] ? @"neoforge" : nil);
    if (!kind || !AMSafeVersionComponent(minecraft) || !AMSafeVersionComponent(dependencies[kind])) return nil;
    NSString *version = dependencies[kind];
    NSString *artifact = [kind isEqual:@"forge"] ? [NSString stringWithFormat:@"%@-%@", minecraft, version] : version;
    NSString *repository = [kind isEqual:@"forge"] ? @"https://maven.minecraftforge.net/net/minecraftforge/forge" : @"https://maven.neoforged.net/releases/net/neoforged/neoforge";
    NSString *url = [NSString stringWithFormat:@"%@/%@/%@-%@-installer.jar", repository, artifact, kind, artifact];
    NSString *identifier = [kind isEqual:@"forge"] ? [NSString stringWithFormat:@"%@-forge-%@", minecraft, version] : [@"neoforge-" stringByAppendingString:version];
    return @{@"minecraft": minecraft, @"loader": kind, @"loaderVersion": version, @"id": identifier, @"url": url};
}

