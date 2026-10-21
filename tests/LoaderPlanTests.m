#import "../Natives/installer/modpack/LoaderInstallPlan.h"
#import "../Natives/BTAClasspath.h"
int main(void) {
    @autoreleasepool {
        NSDictionary *forge = AMLoaderInstallPlan(@{@"minecraft": @"1.12.2", @"forge": @"14.23.5.2860"});
        NSCAssert([forge[@"url"] isEqual:@"https://maven.minecraftforge.net/net/minecraftforge/forge/1.12.2-14.23.5.2860/forge-1.12.2-14.23.5.2860-installer.jar"], @"Use the manifest's exact Forge version");
        NSDictionary *neo = AMLoaderInstallPlan(@{@"minecraft": @"1.21.1", @"neoforge": @"21.1.200"});
        NSCAssert([neo[@"url"] isEqual:@"https://maven.neoforged.net/releases/net/neoforged/neoforge/21.1.200/neoforge-21.1.200-installer.jar"], @"NeoForge has its own coordinates");
        NSCAssert(!AMLoaderInstallPlan(@{@"minecraft": @"1.12.2", @"forge": @"../../bad"}), @"Reject unsafe version identifiers");
        NSCAssert(!AMLoaderInstallPlan(@{@"minecraft": @"1.20.1", @"fabric-loader": @"0.16.0"}), @"Fabric does not run the Forge installer");
        NSData *data = [NSData dataWithContentsOfFile:@"Natives/resources/bta/bta-8.0.1.json"];
        NSDictionary *bta = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *classpath = [AMBTASystemClasspath(bta, @"/game", @"/bundle/lwjgl/*:/bundle/libs/*") componentsSeparatedByString:@":"];
        NSCAssert([classpath.firstObject isEqual:@"/game/versions/bta-8.0.1/bta-8.0.1.jar"], @"BTA's jarmod must override vanilla in the parent loader");
        NSCAssert([classpath[1] hasSuffix:@"legacy-lwjgl3-1.0.6.jar"], @"The compatibility bridge must see the BTA client");
        NSCAssert([classpath[2] isEqual:@"/bundle/lwjgl/*"], @"Keep patched iOS LWJGL ahead of desktop dependencies");
        NSCAssert([classpath.lastObject hasSuffix:@"minecraft-b1.7.3-client.jar"], @"Vanilla supplies fallback classes after the jarmod");
        NSCAssert([classpath componentsJoinedByString:@":"].length > 1000, @"All BTA dependencies must be visible to the parent loader");
        NSLog(@"Loader plan and BTA classpath tests passed");
    }
}

