#import <UIKit/UIKit.h>

@interface SurfaceView : UIView
- (void)displayLayer;
@end

@interface JavaGUIViewController : UIViewController
@property(nonatomic) NSString* filepath;
@property(nonatomic) NSArray<NSString *> *launchArguments;
@property(nonatomic) int minimumJavaVersion;
@property(nonatomic, readonly) int requiredJavaVersion;

- (void)setHitEnterAfterWindowShown:(BOOL)hitEnter;
@end

