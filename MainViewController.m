#import "MainViewController.h"
#import "StoreManager.h"
#import "CatBLEManager.h"
#import "ReceiptRenderer.h"
#import "BalanceViewController.h"
#import "ItemsViewController.h"
#import "SettingsViewController.h"
#import "LogsViewController.h"

@interface MainViewController () <CatBLEManagerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *connectBtn;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UICollectionView *itemsCollection;
@property (nonatomic, strong) UITableView *cartTable;
@property (nonatomic, strong) UILabel *totalLabel;
@property (nonatomic, strong) UITextField *invNumberField;
@property (nonatomic, strong) UIButton *printBtn;
@property (nonatomic, strong) NSArray<InvoiceItemModel *> *displayedItems;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"فاتورتي";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    [CatBLEManager shared].delegate = self;
    
    UIBarButtonItem *settingsBtn = [[UIBarButtonItem alloc] initWithTitle:@"الإعدادات" style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
    UIBarButtonItem *itemsBtn = [[UIBarButtonItem alloc] initWithTitle:@"الأصناف" style:UIBarButtonItemStylePlain target:self action:@selector(openItems)];
    UIBarButtonItem *balanceBtn = [[UIBarButtonItem alloc] initWithTitle:@"طباعة رصيد" style:UIBarButtonItemStylePlain target:self action:@selector(openBalance)];
    UIBarButtonItem *logsBtn = [[UIBarButtonItem alloc] initWithTitle:@"السجل" style:UIBarButtonItemStylePlain target:self action:@selector(openLogs)];
    
    self.navigationItem.rightBarButtonItems = @[settingsBtn, itemsBtn, balanceBtn, logsBtn];
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.displayedItems = [StoreManager shared].quickItems;
    self.invNumberField.text = [NSString stringWithFormat:@"%ld", (long)[StoreManager shared].invoiceNumber];
    [self.itemsCollection reloadData];
    [self refreshCartUI];
}

- (void)setupUI {
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    UIColor *cardBg = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    UIColor *orange = [UIColor colorWithRed:1.0 green:0.60 blue:0.0 alpha:1.0];
    
    UIView *topCard = [[UIView alloc] initWithFrame:CGRectMake(16, 74, w - 32, 60)];
    topCard.backgroundColor = cardBg;
    topCard.layer.cornerRadius = 12;
    topCard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:topCard];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, 260, 40)];
    self.statusLabel.text = [CatBLEManager shared].isConnected ? @"🟢 متصلة وجاهزة" : @"🔴 الطابعة غير متصلة";
    self.statusLabel.textColor = [CatBLEManager shared].isConnected ? [UIColor greenColor] : [UIColor redColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:17];
    [topCard addSubview:self.statusLabel];
    
    self.connectBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.connectBtn.frame = CGRectMake(topCard.bounds.size.width - 136, 10, 120, 40);
    self.connectBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.connectBtn.backgroundColor = orange;
    [self.connectBtn setTitle:@"ربط الطابعة" forState:UIControlStateNormal];
    [self.connectBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.connectBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.connectBtn.layer.cornerRadius = 8;
    [self.connectBtn addTarget:self action:@selector(scanPrinters) forControlEvents:UIControlEventTouchUpInside];
    [topCard addSubview:self.connectBtn];
    
    CGFloat splitX = w * 0.42;
    CGFloat contentY = 146;
    CGFloat contentH = h - contentY - 16;
    
    UIView *leftCard = [[UIView alloc] initWithFrame:CGRectMake(16, contentY, splitX - 24, contentH)];
    leftCard.backgroundColor = cardBg;
    leftCard.layer.cornerRadius = 12;
    leftCard.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:leftCard];
    
    UILabel *cartTitle = [[UILabel alloc] initWithFrame:CGRectMake(leftCard.bounds.size.width - 140, 10, 124, 30)];
    cartTitle.text = @"السلة الحالية";
    cartTitle.textColor = [UIColor whiteColor];
    cartTitle.textAlignment = NSTextAlignmentRight;
    cartTitle.font = [UIFont boldSystemFontOfSize:18];
    cartTitle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [leftCard addSubview:cartTitle];
    
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(16, 10, 80, 30);
    [clearBtn setTitle:@"مسح الكل" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearCartAction) forControlEvents:UIControlEventTouchUpInside];
    [leftCard addSubview:clearBtn];
    
    self.cartTable = [[UITableView alloc] initWithFrame:CGRectMake(8, 48, leftCard.bounds.size.width - 16, leftCard.bounds.size.height - 210) style:UITableViewStylePlain];
    self.cartTable.backgroundColor = [UIColor clearColor];
    self.cartTable.dataSource = self;
    self.cartTable.delegate = self;
    self.cartTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [leftCard addSubview:self.cartTable];
    
    UIView *bottomBox = [[UIView alloc] initWithFrame:CGRectMake(12, leftCard.bounds.size.height - 154, leftCard.bounds.size.width - 24, 144)];
    bottomBox.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [leftCard addSubview:bottomBox];
    
    UILabel *invLbl = [[UILabel alloc] initWithFrame:CGRectMake(bottomBox.bounds.size.width - 110, 4, 110, 34)];
    invLbl.text = @"رقم الفاتورة:";
    invLbl.textColor = [UIColor lightGrayColor];
    invLbl.textAlignment = NSTextAlignmentRight;
    invLbl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [bottomBox addSubview:invLbl];
    
    self.invNumberField = [[UITextField alloc] initWithFrame:CGRectMake(bottomBox.bounds.size.width - 200, 4, 80, 34)];
    self.invNumberField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.invNumberField.textColor = [UIColor whiteColor];
    self.invNumberField.textAlignment = NSTextAlignmentCenter;
    self.invNumberField.layer.cornerRadius = 6;
    self.invNumberField.keyboardType = UIKeyboardTypeNumberPad;
    self.invNumberField.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [bottomBox addSubview:self.invNumberField];
    
    self.totalLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 44, bottomBox.bounds.size.width, 36)];
    self.totalLabel.textColor = orange;
    self.totalLabel.font = [UIFont boldSystemFontOfSize:22];
    self.totalLabel.textAlignment = NSTextAlignmentCenter;
    self.totalLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [bottomBox addSubview:self.totalLabel];
    
    self.printBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.printBtn.frame = CGRectMake(0, 88, bottomBox.bounds.size.width, 52);
    self.printBtn.backgroundColor = orange;
    self.printBtn.layer.cornerRadius = 26;
    [self.printBtn setTitle:@"🖨️ طباعة الفاتورة" forState:UIControlStateNormal];
    [self.printBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.printBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.printBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.printBtn addTarget:self action:@selector(printInvoiceAction) forControlEvents:UIControlEventTouchUpInside];
    [bottomBox addSubview:self.printBtn];
    
    UIView *rightCard = [[UIView alloc] initWithFrame:CGRectMake(splitX, contentY, w - splitX - 16, contentH)];
    rightCard.backgroundColor = cardBg;
    rightCard.layer.cornerRadius = 12;
    rightCard.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:rightCard];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(8, 8, rightCard.bounds.size.width - 16, 44)];
    self.searchBar.placeholder = @"بحث عن صنف...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.delegate = self;
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [rightCard addSubview:self.searchBar];
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(170, 145);
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
    
    self.itemsCollection = [[UICollectionView alloc] initWithFrame:CGRectMake(8, 58, rightCard.bounds.size.width - 16, rightCard.bounds.size.height - 66) collectionViewLayout:layout];
    self.itemsCollection.backgroundColor = [UIColor clearColor];
    self.itemsCollection.dataSource = self;
    self.itemsCollection.delegate = self;
    self.itemsCollection.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.itemsCollection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"ItemCell"];
    [rightCard addSubview:self.itemsCollection];
}

- (void)refreshCartUI {
    [self.cartTable reloadData];
    StoreManager *sm = [StoreManager shared];
    self.totalLabel.text = [NSString stringWithFormat:@"المجموع: %@ %@", [ReceiptRenderer formatNumber:[sm cartTotal]], sm.currency];
}

#pragma mark - Actions

- (void)scanPrinters {
    [self.connectBtn setTitle:@"جاري البحث..." forState:UIControlStateNormal];
    [[CatBLEManager shared] startScan];
}

- (void)clearCartAction {
    [[StoreManager shared] clearCart];
    [self refreshCartUI];
}

- (void)printInvoiceAction {
    StoreManager *sm = [StoreManager shared];
    if (sm.cartItems.count == 0) {
        [[StoreManager shared] addLog:@"🛑 السلة فارغة"];
        return;
    }
    if (![CatBLEManager shared].isConnected) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"تنبيه" message:@"يرجى ربط الطابعة أولاً" delegate:nil cancelButtonTitle:@"موافق" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    sm.invoiceNumber = [self.invNumberField.text integerValue] ?: sm.invoiceNumber;
    UIImage *receipt = [ReceiptRenderer createInvoiceBitmap];
    BOOL ok = [[CatBLEManager shared] printBitmap:receipt energy:[sm energyForDensity]];
    if (ok) {
        [[NSUserDefaults standardUserDefaults] setInteger:sm.invoiceNumber forKey:@"last_invoice_num"];
        sm.invoiceNumber += 1;
        self.invNumberField.text = [NSString stringWithFormat:@"%ld", (long)sm.invoiceNumber];
    }
}

- (void)openSettings { [self.navigationController pushViewController:[[SettingsViewController alloc] init] animated:YES]; }
- (void)openItems { [self.navigationController pushViewController:[[ItemsViewController alloc] init] animated:YES]; }
- (void)openBalance { [self.navigationController pushViewController:[[BalanceViewController alloc] init] animated:YES]; }
- (void)openLogs { [self.navigationController pushViewController:[[LogsViewController alloc] init] animated:YES]; }

#pragma mark - CatBLEManagerDelegate

- (void)bleDidUpdateConnectionState:(BOOL)connected statusText:(NSString *)status {
    self.statusLabel.text = connected ? @"🟢 متصلة وجاهزة" : @"🔴 الطابعة غير متصلة";
    self.statusLabel.textColor = connected ? [UIColor greenColor] : [UIColor redColor];
    [self.connectBtn setTitle:connected ? @"تغيير" : @"ربط الطابعة" forState:UIControlStateNormal];
}

- (void)bleDidDiscoverPrinters:(NSArray<DiscoveredPrinter *> *)printers {
    [self.connectBtn setTitle:@"ربط الطابعة" forState:UIControlStateNormal];
    if (printers.count == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"البحث" message:@"لم يتم العثور على طابعات قريبة. تأكد من تشغيل الطابعة." delegate:nil cancelButtonTitle:@"إغلاق" otherButtonTitles:nil];
        [alert show];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"اختر الطابعة المتوفرة" message:nil preferredStyle:UIAlertControllerStyleAlert];
    for (DiscoveredPrinter *dp in printers) {
        NSString *title = [NSString stringWithFormat:@"%@ (%@ dBm)", dp.name, dp.rssi];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[CatBLEManager shared] connectToPeripheral:dp.peripheral];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.displayedItems = [StoreManager shared].quickItems;
    } else {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", searchText];
        self.displayedItems = [[StoreManager shared].quickItems filteredArrayUsingPredicate:pred];
    }
    [self.itemsCollection reloadData];
}

#pragma mark - UICollectionViewDataSource & Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.displayedItems.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ItemCell" forIndexPath:indexPath];
    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];
    
    cell.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.18 alpha:1.0];
    cell.layer.cornerRadius = 10;
    cell.clipsToBounds = YES;
    
    InvoiceItemModel *item = self.displayedItems[indexPath.item];
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    UIImage *img = item.imagePath.length > 0 ? [UIImage imageWithContentsOfFile:[docs stringByAppendingPathComponent:item.imagePath]] : nil;
    
    if (img) {
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 170, 85)];
        iv.image = img;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        [cell.contentView addSubview:iv];
    }
    
    CGFloat textY = img ? 88 : 30;
    UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(6, textY, 158, 26)];
    nameLbl.text = item.name;
    nameLbl.textColor = [UIColor whiteColor];
    nameLbl.font = [UIFont boldSystemFontOfSize:15];
    nameLbl.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:nameLbl];
    
    UILabel *priceLbl = [[UILabel alloc] initWithFrame:CGRectMake(6, textY + 26, 158, 22)];
    priceLbl.text = [NSString stringWithFormat:@"%@ %@", [ReceiptRenderer formatNumber:item.price], [StoreManager shared].currency];
    priceLbl.textColor = [UIColor colorWithRed:1.0 green:0.60 blue:0.0 alpha:1.0];
    priceLbl.font = [UIFont boldSystemFontOfSize:14];
    priceLbl.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:priceLbl];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    InvoiceItemModel *item = self.displayedItems[indexPath.item];
    [[StoreManager shared] addToCart:item];
    [self refreshCartUI];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [StoreManager shared].cartItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CartCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CartCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    }
    InvoiceItemModel *item = [StoreManager shared].cartItems[indexPath.row];
    cell.textLabel.text = item.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld × %@", (long)item.quantity, [ReceiptRenderer formatNumber:item.price]];
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[StoreManager shared] removeFromCartAtIndex:indexPath.row];
        [self refreshCartUI];
    }
}

@end
