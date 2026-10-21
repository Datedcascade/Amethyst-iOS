#import "BTAInstallViewController.h"
#import "LauncherProfileEditorViewController.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "UnzipKit.h"
#import "utils.h"
#include <CommonCrypto/CommonDigest.h>

static NSString *const BTAVersionID = @"bta-8.0.1";
static NSString *const BTAPackageURL = @"https://downloads.betterthanadventure.net/bta-client/release/v8.0.1/bta.v8.0.1.mmc.zip";
static NSString *const BTAPackageSHA256 = @"22fca951e22f9572e2e23437ce828bb67424f773eb913082e2e36aa917764236";

@interface BTAInstallViewController ()
@property(nonatomic) NSURLSessionDownloadTask *download;
@property(nonatomic) UILabel *statusLabel;
@end

@implementation BTAInstallViewController
- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.title = @"Better than Adventure!";
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close)];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 300, 120)];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.text = @"Installs the official 8.0.1 release with Java 17, its LWJGL compatibility library, and a separate game folder. Libraries download when you first press Play. iOS support is experimental; Discord integration is disabled.";
    self.tableView.tableFooterView = self.statusLabel;
}
- (void)close {
    [self.download cancel];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = self.download ? @"Downloading Better than Adventure!…" : @"Install Better than Adventure! 8.0.1";
    cell.textLabel.textColor = self.download ? UIColor.secondaryLabelColor : self.view.tintColor;
    cell.selectionStyle = self.download ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.download) return;
    // Capture the selected instance now; changes in the underlying launcher must
    // not redirect a completed install into another instance.
    NSString *gameRoot = @(getenv("GAME_DIR"));
    NSString *instanceRoot = [NSString stringWithFormat:@"%s/instances/%@", getenv("AME_HOME"), getPrefObject(@"general.game_directory")];
    NSURL *url = [NSURL URLWithString:BTAPackageURL];
    __weak typeof(self) weakSelf = self;
    self.download = [NSURLSession.sharedSession downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *networkError) {
        typeof(self) self = weakSelf;
        if (!self || networkError.code == NSURLErrorCancelled) return;
        NSError *error = networkError;
        NSDictionary *profile = nil;
        if (!error && [(NSHTTPURLResponse *)response statusCode] != 200) {
            error = [NSError errorWithDomain:@"BTAInstall" code:1 userInfo:@{NSLocalizedDescriptionKey: @"The official download server did not return a package."}];
        }
        if (!error) profile = [self installPackage:location gameRoot:gameRoot instanceRoot:instanceRoot error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.download = nil;
            [self.tableView reloadData];
            if (error || !profile) {
                self.statusLabel.text = error.localizedDescription ?: @"Installation failed.";
                return;
            }
            self.statusLabel.text = @"Installed. Save the profile, then select it and press Play.";
            BOOL knownVersion = NO;
            for (NSDictionary *version in localVersionList) {
                if ([version[@"id"] isEqualToString:BTAVersionID]) knownVersion = YES;
            }
            if (!knownVersion) [localVersionList addObject:@{@"id": BTAVersionID, @"type": @"custom"}];
            LauncherProfileEditorViewController *editor = [LauncherProfileEditorViewController new];
            editor.profile = profile.mutableCopy;
            [self.navigationController pushViewController:editor animated:YES];
        });
    }];
    [self.download resume];
    [self.tableView reloadData];
}
- (NSDictionary *)installPackage:(NSURL *)location gameRoot:(NSString *)gameRoot instanceRoot:(NSString *)instanceRoot error:(NSError **)error {
    NSData *package = [NSData dataWithContentsOfURL:location options:NSDataReadingMappedIfSafe error:error];
    if (!package) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(package.bytes, (CC_LONG)package.length, digest);
    NSMutableString *hash = [NSMutableString new];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hash appendFormat:@"%02x", digest[i]];
    if (![hash isEqualToString:BTAPackageSHA256]) {
        *error = [NSError errorWithDomain:@"BTAInstall" code:2 userInfo:@{NSLocalizedDescriptionKey: @"BTA package verification failed. No game files were installed."}];
        return nil;
    }
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:location.path error:error];
    if (!archive) return nil;
    // Extract only this known member; do not unpack arbitrary archive paths.
    NSData *client = [archive extractDataFromFile:@"jarmods/bta.jar" error:error];
    if (!client) return nil;
    NSString *manifestPath = [NSBundle.mainBundle pathForResource:@"bta-8.0.1" ofType:@"json" inDirectory:@"bta"];
    NSData *manifestData = manifestPath ? [NSData dataWithContentsOfFile:manifestPath options:0 error:error] : nil;
    NSDictionary *manifest = manifestData ? [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:error] : nil;
    if (!manifest) return nil;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *clientPath = [gameRoot stringByAppendingPathComponent:[NSString stringWithFormat:@"versions/%@/%@.jar", BTAVersionID, BTAVersionID]];
    NSString *versionPath = [gameRoot stringByAppendingPathComponent:[NSString stringWithFormat:@"versions/%@/%@.json", BTAVersionID, BTAVersionID]];
    NSString *optionsPath = [[instanceRoot stringByAppendingPathComponent:BTAVersionID] stringByAppendingPathComponent:@"options.txt"];
    for (NSString *path in @[clientPath, versionPath, optionsPath]) {
        if (![fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error]) return nil;
    }
    if (![client writeToFile:clientPath options:NSDataWritingAtomic error:error]) return nil;
    if (![fm fileExistsAtPath:optionsPath] && ![@"discordRichPresence:false\n" writeToFile:optionsPath atomically:YES encoding:NSUTF8StringEncoding error:error]) return nil;
    // Publish the version metadata last so an interrupted install is not listed.
    if (![manifestData writeToFile:versionPath options:NSDataWritingAtomic error:error]) return nil;
    return @{@"name": @"Better than Adventure! 8.0.1", @"lastVersionId": BTAVersionID, @"gameDir": BTAVersionID, @"javaVersion": @"17"};
}
@end

