#import "StoreManager.h"

@implementation InvoiceItemModel
- (NSDictionary *)toDict {
    return @{
        @"name": self.name ?: @"",
        @"quantity": @(self.quantity),
        @"price": @(self.price),
        @"imagePath": self.imagePath ?: @""
    };
}
+ (instancetype)fromDict:(NSDictionary *)dict {
    InvoiceItemModel *m = [[InvoiceItemModel alloc] init];
    m.name = dict[@"name"] ?: @"";
    m.quantity = [dict[@"quantity"] integerValue] ?: 1;
    m.price = [dict[@"price"] doubleValue];
    m.imagePath = dict[@"imagePath"];
    return m;
}
@end

@implementation StoreManager

+ (instancetype)shared {
    static StoreManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[StoreManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.cartItems = [NSMutableArray array];
        self.logs = [NSMutableArray array];
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    self.storeName = [ud stringForKey:@"store_name"] ?: @"مطعم السعادة";
    self.phone = [ud stringForKey:@"store_phone"] ?: @"07700000000";
    self.address = [ud stringForKey:@"store_address"] ?: @"الكوت - شارع النسيج";
    self.footerMessage = [ud stringForKey:@"store_footer"] ?: @"شكراً لزيارتكم! نرجو رؤيتكم قريباً.";
    self.currency = [ud stringForKey:@"currency"] ?: @"د.ع";
    self.invoiceNumber = [ud integerForKey:@"last_invoice_num"] + 1;
    self.logoScale = [ud objectForKey:@"logo_scale"] ? [ud floatForKey:@"logo_scale"] : 1.0f;
    self.fontSize = [ud objectForKey:@"font_size"] ? [ud floatForKey:@"font_size"] : 24.0f;
    self.isBold = [ud objectForKey:@"is_bold"] ? [ud boolForKey:@"is_bold"] : YES;
    self.printDensity = [ud objectForKey:@"print_density"] ? [ud integerForKey:@"print_density"] : 7;
    self.mainScreenMode = [ud objectForKey:@"main_screen_mode"] ? [ud integerForKey:@"main_screen_mode"] : 2;
    self.lastPrinterUUID = [ud stringForKey:@"last_printer_uuid"];
    
    NSArray *savedItems = [ud arrayForKey:@"quick_items"];
    self.quickItems = [NSMutableArray array];
    if (savedItems.count > 0) {
        for (NSDictionary *d in savedItems) {
            [self.quickItems addObject:[InvoiceItemModel fromDict:d]];
        }
    } else {
        NSArray *defaults = @[
            @{@"name": @"شاورما دجاج كبير", @"quantity": @1, @"price": @15000},
            @{@"name": @"شاورما لحم عربي", @"quantity": @1, @"price": @20000},
            @{@"name": @"برجر لحم دبل جبن", @"quantity": @1, @"price": @25000},
            @{@"name": @"بطاطس مقلية", @"quantity": @1, @"price": @5000},
            @{@"name": @"كولا", @"quantity": @1, @"price": @2000}
        ];
        for (NSDictionary *d in defaults) {
            [self.quickItems addObject:[InvoiceItemModel fromDict:d]];
        }
    }
}

- (void)saveSettings {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:self.storeName forKey:@"store_name"];
    [ud setObject:self.phone forKey:@"store_phone"];
    [ud setObject:self.address forKey:@"store_address"];
    [ud setObject:self.footerMessage forKey:@"store_footer"];
    [ud setObject:self.currency forKey:@"currency"];
    [ud setFloat:self.logoScale forKey:@"logo_scale"];
    [ud setFloat:self.fontSize forKey:@"font_size"];
    [ud setBool:self.isBold forKey:@"is_bold"];
    [ud setInteger:self.printDensity forKey:@"print_density"];
    [ud setInteger:self.mainScreenMode forKey:@"main_screen_mode"];
    if (self.lastPrinterUUID) {
        [ud setObject:self.lastPrinterUUID forKey:@"last_printer_uuid"];
    }
    [ud synchronize];
}

- (void)saveQuickItems {
    NSMutableArray *arr = [NSMutableArray array];
    for (InvoiceItemModel *item in self.quickItems) {
        [arr addObject:[item toDict]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"quick_items"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)addToCart:(InvoiceItemModel *)item {
    for (InvoiceItemModel *existing in self.cartItems) {
        if ([existing.name isEqualToString:item.name]) {
            existing.quantity += item.quantity;
            return;
        }
    }
    InvoiceItemModel *copy = [[InvoiceItemModel alloc] init];
    copy.name = item.name;
    copy.quantity = item.quantity > 0 ? item.quantity : 1;
    copy.price = item.price;
    copy.imagePath = item.imagePath;
    [self.cartItems addObject:copy];
}

- (void)removeFromCartAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.cartItems.count) {
        [self.cartItems removeObjectAtIndex:index];
    }
}

- (void)clearCart {
    [self.cartItems removeAllObjects];
}

- (double)cartTotal {
    double total = 0;
    for (InvoiceItemModel *item in self.cartItems) {
        total += (item.quantity * item.price);
    }
    return total;
}

- (NSString *)docsDir {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

- (UIImage *)loadLogoImage {
    NSString *path = [[self docsDir] stringByAppendingPathComponent:@"store_logo.png"];
    return [UIImage imageWithContentsOfFile:path];
}

- (void)saveLogoImage:(UIImage *)image {
    NSString *path = [[self docsDir] stringByAppendingPathComponent:@"store_logo.png"];
    if (image) {
        [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
    } else {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

- (NSString *)saveItemImage:(UIImage *)image {
    if (!image) return @"";
    NSString *fileName = [NSString stringWithFormat:@"item_%.0f.jpg", [[NSDate date] timeIntervalSince1970] * 1000];
    NSString *fullPath = [[self docsDir] stringByAppendingPathComponent:fileName];
    [UIImageJPEGRepresentation(image, 0.8) writeToFile:fullPath atomically:YES];
    return fileName;
}

- (void)addLog:(NSString *)msg {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm:ss";
    NSString *line = [NSString stringWithFormat:@"[%@] %@", [df stringFromDate:[NSDate date]], msg];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logs addObject:line];
        if (self.logs.count > 200) {
            [self.logs removeObjectAtIndex:0];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FatooratiLogUpdated" object:nil];
    });
}

- (uint16_t)energyForDensity {
    switch (self.printDensity) {
        case 1: return 0x2000;
        case 2: return 0x4000;
        case 3: return 0x6000;
        case 4: return 0x8000;
        case 5: return 0xA000;
        case 6: return 0xD000;
        default: return 0xFFFF;
    }
}

@end
