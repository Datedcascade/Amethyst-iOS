#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

static inline BOOL AMEOfflineUsernameIsValid(NSString *username) {
    if (![username isKindOfClass:NSString.class] || username.length < 3 || username.length > 16) return NO;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"] invertedSet];
    return [username rangeOfCharacterFromSet:invalid].location == NSNotFound;
}

static inline NSString *AMEOfflineUUID(NSString *username) {
    // Minecraft's UUID.nameUUIDFromBytes(UTF8("OfflinePlayer:" + username)).
    NSData *input = [[@"OfflinePlayer:" stringByAppendingString:username] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input.bytes, (CC_LONG)input.length, digest);
    digest[6] = (digest[6] & 0x0f) | 0x30;
    digest[8] = (digest[8] & 0x3f) | 0x80;
    return [[[NSUUID alloc] initWithUUIDBytes:digest].UUIDString lowercaseString];
}
