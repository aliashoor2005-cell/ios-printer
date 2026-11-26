#import "ItemsViewController.h"
#import "StoreManager.h"
#import "ReceiptRenderer.h"

@interface ItemsViewController () <UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *priceField;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) UIButton *imgBtn;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation ItemsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"إدارة أصناف الفاتورة";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    CGFloat w = self.view.bounds.size.width;
    UIView *topBox = [[UIView alloc] initWithFrame:CGRectMake(16, 76, w - 32, 64)];
    topBox.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    topBox.layer.cornerRadius = 10;
    [self.view addSubview:topBox];
    
    self.imgBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.imgBtn.frame = CGRectMake(12, 12, 80, 40);
    [self.imgBtn setTitle:@"📷 صورة" forState:UIControlStateNormal];
    [self.imgBtn setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [self.imgBtn addTarget:self action:@selector(pickPhoto) forControlEvents:UIControlEventTouchUpInside];
    [topBox addSubview:self.imgBtn];
    
    self.nameField = [[UITextField alloc] initWithFrame:CGRectMake(100, 12, 240, 40)];
    self.nameField.placeholder = @"اسم الصنف";
    self.nameField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.nameField.textColor = [UIColor whiteColor];
    self.nameField.textAlignment = NSTextAlignmentRight;
    self.nameField.layer.cornerRadius = 6;
    [topBox addSubview:self.nameField];
    
    self.priceField = [[UITextField alloc] initWithFrame:CGRectMake(350, 12, 140, 40)];
    self.priceField.placeholder = @"السعر";
    self.priceField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.priceField.textColor = [UIColor whiteColor];
    self.priceField.textAlignment = NSTextAlignmentCenter;
    self.priceField.keyboardType = UIKeyboardTypeNumberPad;
    self.priceField.layer.cornerRadius = 6;
    [topBox addSubview:self.priceField];
    
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(504, 12, 100, 40);
    addBtn.backgroundColor = [UIColor colorWithRed:0.29 green:0.68 blue:0.31 alpha:1.0];
    [addBtn setTitle:@"إضافة +" forState:UIControlStateNormal];
    [addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addBtn.layer.cornerRadius = 8;
    [addBtn addTarget:self action:@selector(addItem) forControlEvents:UIControlEventTouchUpInside];
    [topBox addSubview:addBtn];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(16, 152, w - 32, self.view.bounds.size.height - 168) style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (void)pickPhoto {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    self.selectedImage = info[UIImagePickerControllerOriginalImage];
    [self.imgBtn setTitle:@"✅ تم" forState:UIControlStateNormal];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)addItem {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    double price = [self.priceField.text doubleValue];
    if (name.length == 0 || price <= 0) return;
    
    InvoiceItemModel *m = [[InvoiceItemModel alloc] init];
    m.name = name;
    m.quantity = 1;
    m.price = price;
    if (self.selectedImage) {
        m.imagePath = [[StoreManager shared] saveItemImage:self.selectedImage];
    }
    [[StoreManager shared].quickItems addObject:m];
    [[StoreManager shared] saveQuickItems];
    
    self.nameField.text = @"";
    self.priceField.text = @"";
    self.selectedImage = nil;
    [self.imgBtn setTitle:@"📷 صورة" forState:UIControlStateNormal];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [StoreManager shared].quickItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Cell"];
        cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor orangeColor];
    }
    InvoiceItemModel *item = [StoreManager shared].quickItems[indexPath.row];
    cell.textLabel.text = item.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [ReceiptRenderer formatNumber:item.price], [StoreManager shared].currency];
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[StoreManager shared].quickItems removeObjectAtIndex:indexPath.row];
        [[StoreManager shared] saveQuickItems];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

@end
