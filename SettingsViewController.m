#import "SettingsViewController.h"
#import "StoreManager.h"
#import "CatBLEManager.h"
#import "ReceiptRenderer.h"

@interface SettingsViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UITextField *storeField;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UITextField *footerField;
@property (nonatomic, strong) UITextField *currencyField;
@property (nonatomic, strong) UISlider *densitySlider;
@property (nonatomic, strong) UILabel *densityLabel;
@property (nonatomic, strong) UISlider *fontSlider;
@property (nonatomic, strong) UILabel *fontLabel;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"إعدادات الفاتورة والطابعة";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    StoreManager *sm = [StoreManager shared];
    CGFloat centerX = (self.view.bounds.size.width - 460) / 2.0;
    CGFloat y = 84;
    
    self.storeField = [self makeField:@"اسم المتجر" text:sm.storeName y:y x:centerX]; y += 52;
    self.phoneField = [self makeField:@"رقم الهاتف" text:sm.phone y:y x:centerX]; y += 52;
    self.addressField = [self makeField:@"العنوان" text:sm.address y:y x:centerX]; y += 52;
    self.footerField = [self makeField:@"رسالة التذييل" text:sm.footerMessage y:y x:centerX]; y += 52;
    self.currencyField = [self makeField:@"العملة" text:sm.currency y:y x:centerX]; y += 58;
    
    self.densityLabel = [[UILabel alloc] initWithFrame:CGRectMake(centerX, y, 460, 26)];
    self.densityLabel.textColor = [UIColor whiteColor];
    self.densityLabel.textAlignment = NSTextAlignmentRight;
    self.densityLabel.text = [NSString stringWithFormat:@"عمق الطباعة (1-7): %ld", (long)sm.printDensity];
    [self.view addSubview:self.densityLabel]; y += 28;
    
    self.densitySlider = [[UISlider alloc] initWithFrame:CGRectMake(centerX, y, 460, 30)];
    self.densitySlider.minimumValue = 1;
    self.densitySlider.maximumValue = 7;
    self.densitySlider.value = sm.printDensity;
    [self.densitySlider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.densitySlider]; y += 42;
    
    self.fontLabel = [[UILabel alloc] initWithFrame:CGRectMake(centerX, y, 460, 26)];
    self.fontLabel.textColor = [UIColor whiteColor];
    self.fontLabel.textAlignment = NSTextAlignmentRight;
    self.fontLabel.text = [NSString stringWithFormat:@"حجم خط الفاتورة: %.0f", sm.fontSize];
    [self.view addSubview:self.fontLabel]; y += 28;
    
    self.fontSlider = [[UISlider alloc] initWithFrame:CGRectMake(centerX, y, 460, 30)];
    self.fontSlider.minimumValue = 14;
    self.fontSlider.maximumValue = 32;
    self.fontSlider.value = sm.fontSize;
    [self.fontSlider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.fontSlider]; y += 48;
    
    UIButton *logoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    logoBtn.frame = CGRectMake(centerX, y, 220, 44);
    logoBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [logoBtn setTitle:@"اختيار شعار المتجر" forState:UIControlStateNormal];
    [logoBtn setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    logoBtn.layer.cornerRadius = 8;
    [logoBtn addTarget:self action:@selector(pickLogo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:logoBtn];
    
    UIButton *testBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    testBtn.frame = CGRectMake(centerX + 240, y, 220, 44);
    testBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [testBtn setTitle:@"طباعة تجريبية" forState:UIControlStateNormal];
    [testBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    testBtn.layer.cornerRadius = 8;
    [testBtn addTarget:self action:@selector(runTestPrint) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:testBtn]; y += 60;
    
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.frame = CGRectMake(centerX, y, 460, 50);
    saveBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.60 blue:0.0 alpha:1.0];
    [saveBtn setTitle:@"حفظ الإعدادات" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    saveBtn.layer.cornerRadius = 10;
    [saveBtn addTarget:self action:@selector(saveAll) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:saveBtn];
}

- (UITextField *)makeField:(NSString *)placeholder text:(NSString *)text y:(CGFloat)y x:(CGFloat)x {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(x, y, 460, 42)];
    tf.placeholder = placeholder;
    tf.text = text;
    tf.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    tf.textColor = [UIColor whiteColor];
    tf.textAlignment = NSTextAlignmentRight;
    tf.layer.cornerRadius = 8;
    [self.view addSubview:tf];
    return tf;
}

- (void)sliderChanged {
    NSInteger d = (NSInteger)roundf(self.densitySlider.value);
    self.densityLabel.text = [NSString stringWithFormat:@"عمق الطباعة (1-7): %ld", (long)d];
    self.fontLabel.text = [NSString stringWithFormat:@"حجم خط الفاتورة: %.0f", roundf(self.fontSlider.value)];
}

- (void)pickLogo {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if (img) [[StoreManager shared] saveLogoImage:img];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)runTestPrint {
    UIImage *testImg = [ReceiptRenderer createTestPatternBitmap];
    [[CatBLEManager shared] printBitmap:testImg energy:[[StoreManager shared] energyForDensity]];
}

- (void)saveAll {
    StoreManager *sm = [StoreManager shared];
    sm.storeName = self.storeField.text;
    sm.phone = self.phoneField.text;
    sm.address = self.addressField.text;
    sm.footerMessage = self.footerField.text;
    sm.currency = self.currencyField.text;
    sm.printDensity = (NSInteger)roundf(self.densitySlider.value);
    sm.fontSize = roundf(self.fontSlider.value);
    [sm saveSettings];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
