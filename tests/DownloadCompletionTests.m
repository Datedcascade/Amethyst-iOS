#import "../Natives/DownloadCompletion.h"

int main(void) {
    @autoreleasepool {
        NSProgress *parent = [NSProgress progressWithTotalUnitCount:1];
        NSProgress *first = AMHoldFileCompletion(parent);
        NSProgress *last = AMHoldFileCompletion(parent);
        NSProgress *network = [NSProgress progressWithTotalUnitCount:23730770];
        parent.totalUnitCount += network.totalUnitCount;
        [parent addChild:network withPendingUnitCount:network.totalUnitCount];
        parent.completedUnitCount++; // Dependency discovery is complete.
        first.completedUnitCount = 1;
        network.completedUnitCount = network.totalUnitCount;
        NSCAssert(!parent.finished, @"Network completion must not launch before the file is verified");
        NSCAssert(parent.fractionCompleted < 1, @"The last unknown-size task still holds completion");
        last.completedUnitCount = 1;
        NSCAssert(parent.finished, @"All verified files release completion");

        NSProgress *pack = [NSProgress progressWithTotalUnitCount:1];
        NSProgress *zip = AMHoldFileCompletion(pack);
        NSProgress *mod = AMHoldFileCompletion(pack); // Created while parsing ZIP.
        zip.completedUnitCount = 1;
        pack.completedUnitCount++;
        NSCAssert(!pack.finished, @"Finishing an archive must still wait for its mod files");
        mod.completedUnitCount = 1;
        NSCAssert(pack.finished, @"Manifest files complete the pack");
        NSLog(@"Download completion tests passed");
    }
    return 0;
}

