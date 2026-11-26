#import "LogsViewController.h"
#import "StoreManager.h"

@interface LogsViewController ()
@property (nonatomic, strong) UITextView *textView;
@end

@implementation LogsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"سجل الأحداث";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    self.textView = [[UITextView alloc] initWithFrame:CGRectInset(self.view.bounds, 16, 80)];
    self.textView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    self.textView.textColor = [UIColor greenColor];
    self.textView.font = [UIFont fontWithName:@"Courier" size:14];
    self.textView.editable = NO;
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.textView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshLogs) name:@"FatooratiLogUpdated" object:nil];
    [self refreshLogs];
}

- (void)refreshLogs {
    self.textView.text = [[StoreManager shared].logs componentsJoinedByString:@"
"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
