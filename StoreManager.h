#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface InvoiceItemModel : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) double price;
@property (nonatomic, copy) NSString *imagePath;
- (NSDictionary *)toDict;
+ (instancetype)fromDict:(NSDictionary *)dict;
@end

@interface StoreManager : NSObject
+ (instancetype)shared;

@property (nonatomic, copy) NSString *storeName;
@property (nonatomic, copy) NSString *phone;
@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy) NSString *footerMessage;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, assign) NSInteger invoiceNumber;
@property (nonatomic, assign) float logoScale;
@property (nonatomic, assign) float fontSize;
@property (nonatomic, assign) BOOL isBold;
@property (nonatomic, assign) NSInteger printDensity;
@property (nonatomic, assign) NSInteger mainScreenMode;
@property (nonatomic, copy) NSString *lastPrinterUUID;

@property (nonatomic, strong) NSMutableArray<InvoiceItemModel *> *quickItems;
@property (nonatomic, strong) NSMutableArray<InvoiceItemModel *> *cartItems;
@property (nonatomic, strong) NSMutableArray<NSString *> *logs;

- (void)saveSettings;
- (void)saveQuickItems;
- (void)addToCart:(InvoiceItemModel *)item;
- (void)removeFromCartAtIndex:(NSInteger)index;
- (void)clearCart;
- (double)cartTotal;
- (UIImage *)loadLogoImage;
- (void)saveLogoImage:(UIImage *)image;
- (NSString *)saveItemImage:(UIImage *)image;
- (void)addLog:(NSString *)msg;
- (uint16_t)energyForDensity;
@end
