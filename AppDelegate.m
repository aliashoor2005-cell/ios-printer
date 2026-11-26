#import "AppDelegate.h"
#import "MainViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    MainViewController *mainVC = [[MainViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mainVC];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    nav.navigationBar.barTintColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    nav.navigationBar.tintColor = [UIColor colorWithRed:1.0 green:0.60 blue:0.0 alpha:1.0];
    [nav.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}];
    
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
