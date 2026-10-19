#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MinecraftOptionUtils : NSObject

@property(nonatomic) NSString *optionsPath;

+ (void)setupOptionsAtGameDir:(NSString *)gameDir;
+ (void)setupOptionsAtGameDir:(NSString *)gameDir graphicsBackend:(nullable NSString *)graphicsBackend;
+ (void)setupOptionsAtGameDir:(NSString *)gameDir graphicsBackend:(nullable NSString *)graphicsBackend force:(BOOL)force;
+ (nullable NSString *)savedGraphicsBackendAtGameDir:(NSString *)gameDir;
+ (BOOL)isCustomGraphicsBackend:(nullable NSString *)value;
+ (instancetype)sharedInstance;

- (void)loadFromPath:(NSString *)optionsPath;
- (void)setKey:(NSString *)key value:(NSString *)value;
- (void)setDefaultForKey:(NSString *)key value:(NSString *)value;
- (nullable NSString *)getValueForKey:(NSString *)key;
- (void)updateMCGuiScale;
- (void)save;

@end

NS_ASSUME_NONNULL_END
