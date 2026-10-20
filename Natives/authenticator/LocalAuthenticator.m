#import "BaseAuthenticator.h"
#import "../utils.h"
#import "OfflineIdentity.h"

@implementation LocalAuthenticator

+ (BOOL)isValidUsername:(NSString *)username {
    return AMEOfflineUsernameIsValid(username);
}

- (void)configureOfflineProfile {
    self.authData[@"profileId"] = AMEOfflineUUID(self.authData[@"username"]);
    self.authData[@"accountType"] = @"offline";
    self.authData[@"accessToken"] = @"0";
    self.authData[@"clientToken"] = @"0";
    [self.authData removeObjectsForKeys:@[@"xuid", @"xboxGamertag", @"expiresAt", @"profilePicURL"]];
}

- (id)initWithData:(NSMutableDictionary *)data {
    self = [super initWithData:data];
    // Migrate legacy zero-UUID local accounts on load, including startup loads.
    if (self && [LocalAuthenticator isValidUsername:data[@"username"]]) {
        NSDictionary *previous = self.authData.copy;
        [self configureOfflineProfile];
        if (![previous isEqualToDictionary:self.authData]) [super saveChanges];
    }
    return self;
}

- (void)loginWithCallback:(Callback)callback {
    NSString *name = self.authData[@"input"];
    NSString *message = nil;
    if (![LocalAuthenticator isValidUsername:name]) {
        message = @"Use 3–16 letters, numbers, or underscores for your offline username.";
    } else {
        NSString *path = [NSString stringWithFormat:@"%s/accounts/%@.json", getenv("AME_HOME"), name];
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            NSDictionary *existing = parseJSONFromFile(path);
            if (existing[@"NSErrorObject"] || [existing[@"expiresAt"] longLongValue] != 0 ||
                ([existing[@"accountType"] isKindOfClass:NSString.class] && ![existing[@"accountType"] isEqual:@"offline"]) || existing[@"xuid"]) {
                message = @"Another saved account uses this username. Choose a different offline username.";
            }
        }
    }
    if (message) {
        callback([NSError errorWithDomain:@"OfflineAccount" code:1 userInfo:@{NSLocalizedDescriptionKey: message}], NO);
        return;
    }
    self.authData[@"username"] = name;
    [self configureOfflineProfile];
    BOOL saved = [super saveChanges];
    callback(saved ? nil : [NSError errorWithDomain:@"OfflineAccount" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Unable to save the offline account."}], saved);
}

- (void)refreshTokenWithCallback:(Callback)callback {
    // No network authentication is needed for offline accounts.
    callback(nil, YES);
}

@end
