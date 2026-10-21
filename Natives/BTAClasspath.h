#import <Foundation/Foundation.h>

// The bridge's Display class refers to BTA's GameWindowGLFW. Both must be
// visible to the same parent loader, before the child game loader is created.
static inline NSString *AMBTASystemClasspath(NSDictionary *metadata, NSString *gameRoot, NSString *bundled) {
    NSString *version = metadata[@"id"];
    NSMutableArray *entries = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@/versions/%@/%@.jar", gameRoot, version, version]];
    NSMutableArray *dependencies = [NSMutableArray new];
    NSMutableArray *fallback = [NSMutableArray new];
    for (NSDictionary *library in metadata[@"libraries"]) {
        NSString *path = library[@"downloads"][@"artifact"][@"path"];
        if (!path.length || [library[@"name"] hasPrefix:@"org.lwjgl:"] || [library[@"skip"] boolValue]) continue;
        NSString *full = [[gameRoot stringByAppendingPathComponent:@"libraries"] stringByAppendingPathComponent:path];
        if ([library[@"name"] containsString:@":legacy-lwjgl3:"]) [entries addObject:full];
        else if ([library[@"name"] hasPrefix:@"com.mojang:minecraft:"]) [fallback addObject:full];
        else [dependencies addObject:full];
    }
    NSArray *bundlePaths = [bundled componentsSeparatedByString:@":"];
    [entries addObject:bundlePaths.firstObject]; // Patched iOS LWJGL 3 stays first.
    [entries addObjectsFromArray:dependencies];
    if (bundlePaths.count > 1) [entries addObjectsFromArray:[bundlePaths subarrayWithRange:NSMakeRange(1, bundlePaths.count-1)]];
    [entries addObjectsFromArray:fallback];
    return [entries componentsJoinedByString:@":"];
}

