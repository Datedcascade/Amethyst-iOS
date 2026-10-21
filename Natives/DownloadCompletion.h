#import <Foundation/Foundation.h>

// A transferred byte is not necessarily a verified file on disk.
static inline NSProgress *AMHoldFileCompletion(NSProgress *parent) {
    NSProgress *ready = [NSProgress progressWithTotalUnitCount:1];
    @synchronized (parent) {
        parent.totalUnitCount++;
        [parent addChild:ready withPendingUnitCount:1];
    }
    return ready;
}

