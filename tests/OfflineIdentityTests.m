#import "../Natives/authenticator/OfflineIdentity.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        // Known Minecraft offline identities, including case-sensitive names.
        assert([AMEOfflineUUID(@"Notch") isEqual:@"b50ad385-829d-3141-a216-7e7d7539ba7f"]);
        assert([AMEOfflineUUID(@"Steve") isEqual:@"5627dd98-e6be-3c21-b8a8-e92344183641"]);
        assert([AMEOfflineUUID(@"Alex") isEqual:@"36532b5e-c442-3dbb-a24c-c7e55d0f979a"]);
        assert([AMEOfflineUUID(@"steve") isEqual:@"53909932-f794-33c0-9329-948045a4c1ce"]);
        for (NSString *name in @[@"abc", @"Player_123", @"1234567890123456"]) {
            assert(AMEOfflineUsernameIsValid(name));
        }
        for (NSString *name in @[@"", @"ab", @"12345678901234567", @"../Steve", @"A B", @"A/B", @"A\\B", @"A.B", @"Åbc", @"abc\n"]) {
            assert(!AMEOfflineUsernameIsValid(name));
        }
        assert(!AMEOfflineUsernameIsValid(nil));
        NSLog(@"Offline identity tests passed");
    }
    return 0;
}
