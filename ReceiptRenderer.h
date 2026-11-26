#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ReceiptRenderer : NSObject
+ (NSString *)formatNumber:(double)value;
+ (NSData *)bitmapToBinaryData:(UIImage *)image;
+ (UIImage *)createInvoiceBitmap;
+ (UIImage *)createRechargeBitmapWithCompany:(NSInteger)companyIndex code:(NSString *)code amount:(NSString *)amount;
+ (UIImage *)createTestPatternBitmap;
@end
