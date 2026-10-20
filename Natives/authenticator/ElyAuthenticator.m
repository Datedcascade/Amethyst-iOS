#import "BaseAuthenticator.h"
#import "AFNetworking.h"
#import "../utils.h"
#import <Security/Security.h>

// Reuse the launcher's Keychain format and JNI bridge, with a separate key prefix.
@interface MicrosoftAuthenticator (ElyTokenStorage)
+ (NSDictionary *)keychainQueryForKey:(NSString *)profile extraInfo:(NSDictionary *)extra;
@end

@implementation ElyAuthenticator

- (BOOL)setAccessToken:(NSString *)token refreshToken:(NSString *)unused {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@{@"accessToken": token}
        requiringSecureCoding:YES error:nil];
    if (!data) return NO;
    NSDictionary *query = [MicrosoftAuthenticator keychainQueryForKey:self.authData[@"xuid"] extraInfo:nil];
    NSDictionary *attributes = @{(id)kSecValueData: data,
        (id)kSecAttrAccessible: (id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = query.mutableCopy;
        [item addEntriesFromDictionary:attributes];
        status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
    }
    return status == errSecSuccess;
}

- (NSError *)error:(NSString *)message {
    return [NSError errorWithDomain:@"Ely.by" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)request:(NSString *)endpoint parameters:(NSDictionary *)parameters callback:(Callback)callback {
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    manager.requestSerializer.timeoutInterval = 30;
    [manager POST:[@"https://authserver.ely.by/auth/" stringByAppendingString:endpoint]
       parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask *task, id response) {
        if (![response isKindOfClass:NSDictionary.class]) {
            callback([self error:@"Ely.by returned an invalid response."], NO);
            return;
        }
        NSDictionary *profile = response[@"selectedProfile"];
        NSString *token = response[@"accessToken"];
        NSString *client = response[@"clientToken"];
        NSString *name = [profile isKindOfClass:NSDictionary.class] ? profile[@"name"] : nil;
        NSString *uuid = [profile isKindOfClass:NSDictionary.class] ? profile[@"id"] : nil;
        NSCharacterSet *invalidName = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"] invertedSet];
        NSUUID *profileUUID = nil;
        if ([uuid isKindOfClass:NSString.class] && uuid.length == 32) {
            NSString *dashed = [NSString stringWithFormat:@"%@-%@-%@-%@-%@", [uuid substringToIndex:8], [uuid substringWithRange:NSMakeRange(8, 4)], [uuid substringWithRange:NSMakeRange(12, 4)], [uuid substringWithRange:NSMakeRange(16, 4)], [uuid substringFromIndex:20]];
            profileUUID = [[NSUUID alloc] initWithUUIDString:dashed];
        }
        if (![token isKindOfClass:NSString.class] || !token.length ||
            ![client isKindOfClass:NSString.class] || ![client isEqual:parameters[@"clientToken"]] ||
            ![name isKindOfClass:NSString.class] || name.length < 3 || name.length > 16 ||
            [name rangeOfCharacterFromSet:invalidName].location != NSNotFound || !profileUUID) {
            callback([self error:@"Ely.by returned incomplete or invalid account data."], NO);
            return;
        }
        NSString *path = [NSString stringWithFormat:@"%s/accounts/%@.json", getenv("AME_HOME"), name];
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            NSDictionary *existing = parseJSONFromFile(path);
            if (![existing[@"accountType"] isEqual:@"ely"] || ![existing[@"profileId"] isEqual:uuid]) {
                callback([self error:@"Another saved account uses this username. Remove it before adding this Ely.by account."], NO);
                return;
            }
        }
        if (self.authData[@"username"]) self.authData[@"oldusername"] = self.authData[@"username"];
        self.authData[@"accountType"] = @"ely";
        self.authData[@"username"] = name;
        self.authData[@"profileId"] = uuid;
        self.authData[@"clientToken"] = client;
        self.authData[@"xuid"] = [@"ely:" stringByAppendingString:uuid];
        // Ely refreshes using the access token itself; passwords are never saved.
        if (![self setAccessToken:token refreshToken:token]) {
            callback([self error:@"Unable to save the Ely.by token in Keychain."], NO);
            return;
        }
        BOOL saved = [self saveChanges];
        callback(saved ? nil : [self error:@"Unable to save the Ely.by account."], saved);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSData *data = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        id body = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *message = [body isKindOfClass:NSDictionary.class] ? body[@"errorMessage"] : nil;
        callback([message isKindOfClass:NSString.class] ? [self error:message] : error, NO);
    }];
}

- (void)loginWithUsername:(NSString *)username password:(NSString *)password callback:(Callback)callback {
    [self request:@"authenticate" parameters:@{@"username": username, @"password": password,
        @"clientToken": NSUUID.UUID.UUIDString, @"requestUser": @YES} callback:callback];
}

- (void)refreshTokenWithCallback:(Callback)callback {
    NSString *token = [MicrosoftAuthenticator tokenDataOfProfile:self.authData[@"xuid"]][@"accessToken"];
    NSString *client = self.authData[@"clientToken"];
    if (!token.length || !client.length) {
        callback([self error:@"Ely.by credentials are missing. Remove this account and sign in again."], NO);
        return;
    }
    [self request:@"refresh" parameters:@{@"accessToken": token, @"clientToken": client} callback:callback];
}

@end
