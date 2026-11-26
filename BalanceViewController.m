#import "BalanceViewController.h"
#import "StoreManager.h"
#import "CatBLEManager.h"
#import "ReceiptRenderer.h"

@interface BalanceViewController ()
@property (nonatomic, strong) UISegmentedControl *companySeg;
@property (nonatomic, strong) UITextField *pinField;
@property (nonatomic, strong) UITextField *amountField;
@end

@implementation BalanceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"طباعة كارت رصيد";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    CGFloat centerX = (self.view.bounds.size.width - 420) / 2.0;
    
    self.companySeg = [[UISegmentedControl alloc] initWithItems:@[@"زين (Zain)", @"آسياسيل (Asia)", @"كورك (Korek)"]];
    self.companySeg.frame = CGRectMake(centerX, 110, 420, 44);
    self.companySeg.selectedSegmentIndex = 0;
    self.companySeg.tintColor = [UIColor colorWithRed:1.0 green:0.60 blue:0.0 alpha:1.0];
    [self.view addSubview:self.companySeg];
    
    self.pinField = [[UITextField alloc] initWithFrame:CGRectMake(centerX, 180, 420, 48)];
    self.pinField.placeholder = @"رمز التعبئة (PIN)";
    self.pinField.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    self.pinField.textColor = [UIColor whiteColor];
    self.pinField.textAlignment = NSTextAlignmentCenter;
    self.pinField.font = [UIFont boldSystemFontOfSize:20];
    self.pinField.layer.cornerRadius = 8;
    self.pinField.keyboardType = UIKeyboardTypeNumberPad;
    [self.view addSubview:self.pinField];
    
    self.amountField = [[UITextField alloc] initWithFrame:CGRectMake(centerX, 248, 420, 48)];
    self.amountField.placeholder = @"فئة الرصيد (مثلاً 5000)";
    self.amountField.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    self.amountField.textColor = [UIColor whiteColor];
    self.amountField.textAlignment = NSTextAlignmentCenter;
    self.amountField.font = [UIFont boldSystemFontOfSize:20];
    self.amountField.layer.cornerRadius = 8;
    self.amountField.keyboardType = UIKeyboardTypeNumberPad;
    [self.view addSubview:self.amountField];
    
    UIButton *printBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    printBtn.frame = CGRectMake(centerX, 324, 420, 56);
    printBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.60 blue:0.0 alpha:1.0];
    printBtn.layer.cornerRadius = 28;
    [printBtn setTitle:@"🖨️ طباعة الرصيد مع الباركود" forState:UIControlStateNormal];
    [printBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    printBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [printBtn addTarget:self action:@selector(printBalance) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:printBtn];
}

- (void)printBalance {
    NSString *code = [self.pinField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *amt = [self.amountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([code hasPrefix:@"*101#"]) {
        self.companySeg.selectedSegmentIndex = 0;
        code = [[code stringByReplacingOccurrencesOfString:@"*101#" withString:@""] stringByReplacingOccurrencesOfString:@"#" withString:@""];
    } else if ([code hasPrefix:@"*133*"]) {
        self.companySeg.selectedSegmentIndex = 1;
        code = [[code stringByReplacingOccurrencesOfString:@"*133*" withString:@""] stringByReplacingOccurrencesOfString:@"#" withString:@""];
    } else if ([code hasPrefix:@"*221*"]) {
        self.companySeg.selectedSegmentIndex = 2;
        code = [[code stringByReplacingOccurrencesOfString:@"*221*" withString:@""] stringByReplacingOccurrencesOfString:@"#" withString:@""];
    }
    
    if (code.length < 8 || amt.length == 0) {
        [[[UIAlertView alloc] initWithTitle:@"خطأ" message:@"يرجى إدخال رمز التعبئة والفئة بشكل صحيح" delegate:nil cancelButtonTitle:@"موافق" otherButtonTitles:nil] show];
        return;
    }
    
    UIImage *voucher = [ReceiptRenderer createRechargeBitmapWithCompany:self.companySeg.selectedSegmentIndex code:code amount:amt];
    if ([[CatBLEManager shared] printBitmap:voucher energy:[[StoreManager shared] energyForDensity]]) {
        self.pinField.text = @"";
        self.amountField.text = @"";
    }
}

@end
