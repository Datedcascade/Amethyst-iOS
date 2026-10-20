#import "Foundation/Foundation.h"

typedef void(^Callback)(id status, BOOL success);

@interface BaseAuthenticator : NSObject

@property(class) BaseAuthenticator *current;

@property NSMutableDictionary *authData;

+ (id)loadSavedName:(NSString *)name;
+ (NSDictionary *)tokenDataOfProfile:(NSString *)profile;

- (id)initWithInput:(NSString *)string;
- (id)initWithData:(NSMutableDictionary *)data;
- (void)loginWithCallback:(Callback)callback;
- (void)refreshTokenWithCallback:(Callback)callback;
- (BOOL)saveChanges;

@end

@interface LocalAuthenticator : BaseAuthenticator
+ (BOOL)isValidUsername:(NSString *)username;
@end

@interface MicrosoftAuthenticator : BaseAuthenticator

+ (void)clearTokenDataOfProfile:(NSString *)profile;

@end

@interface ElyAuthenticator : BaseAuthenticator
- (void)loginWithUsername:(NSString *)username password:(NSString *)password callback:(Callback)callback;
@end
