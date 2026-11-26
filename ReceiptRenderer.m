#import "ReceiptRenderer.h"
#import "StoreManager.h"
#import <CoreImage/CoreImage.h>

static const CGFloat kPrintWidth = 384.0f;

@implementation ReceiptRenderer

+ (NSString *)formatNumber:(double)value {
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.numberStyle = NSNumberFormatterDecimalStyle;
    fmt.maximumFractionDigits = 0;
    return [fmt stringFromNumber:@(value)] ?: @"0";
}

+ (NSData *)bitmapToBinaryData:(UIImage *)image {
    CGImageRef cgImage = image.CGImage;
    NSInteger width = 384;
    NSInteger height = (NSInteger)(CGImageGetHeight(cgImage) * (384.0 / CGImageGetWidth(cgImage)));
    if (height < 1) height = 1;
    
    uint8_t *gray = (uint8_t *)calloc(width * height, sizeof(uint8_t));
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(gray, width, height, 8, width, colorSpace, (CGBitmapInfo)kCGImageAlphaNone);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    
    double *working = (double *)malloc(width * height * sizeof(double));
    for (NSInteger i = 0; i < width * height; i++) {
        working[i] = (double)gray[i];
    }
    free(gray);
    
    for (NSInteger y = 0; y < height; y++) {
        for (NSInteger x = 0; x < width; x++) {
            NSInteger idx = y * width + x;
            double oldPixel = working[idx];
            double newPixel = oldPixel > 127.5 ? 255.0 : 0.0;
            double error = oldPixel - newPixel;
            working[idx] = newPixel;
            
            if (x + 1 < width) working[idx + 1] = MIN(255.0, MAX(0.0, working[idx + 1] + error * 7.0 / 16.0));
            if (y + 1 < height && x - 1 >= 0) working[(y + 1) * width + (x - 1)] = MIN(255.0, MAX(0.0, working[(y + 1) * width + (x - 1)] + error * 3.0 / 16.0));
            if (y + 1 < height) working[(y + 1) * width + x] = MIN(255.0, MAX(0.0, working[(y + 1) * width + x] + error * 5.0 / 16.0));
            if (y + 1 < height && x + 1 < width) working[(y + 1) * width + (x + 1)] = MIN(255.0, MAX(0.0, working[(y + 1) * width + (x + 1)] + error * 1.0 / 16.0));
        }
    }
    
    NSInteger rowBytes = width / 8;
    NSMutableData *output = [NSMutableData dataWithLength:height * rowBytes];
    uint8_t *outBytes = (uint8_t *)output.mutableBytes;
    
    for (NSInteger y = 0; y < height; y++) {
        for (NSInteger x = 0; x < width; x += 8) {
            uint8_t byte = 0;
            for (NSInteger bit = 0; bit < 8; bit++) {
                if (working[y * width + x + bit] < 128.0) {
                    byte |= (1 << bit);
                }
            }
            outBytes[y * rowBytes + (x / 8)] = byte;
        }
    }
    free(working);
    return output;
}

+ (CGFloat)drawText:(NSString *)text inRect:(CGRect)rect font:(UIFont *)font align:(NSTextAlignment)align dryRun:(BOOL)dryRun {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = align;
    style.lineBreakMode = NSLineBreakByWordWrapping;
    
    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [UIColor blackColor],
        NSParagraphStyleAttributeName: style
    };
    
    CGRect bounding = [text boundingRectWithSize:CGSizeMake(rect.size.width, 2000)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:attrs
                                         context:nil];
    CGFloat h = ceil(bounding.size.height);
    if (!dryRun) {
        [text drawInRect:CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, h) withAttributes:attrs];
    }
    return h;
}

+ (CGFloat)renderInvoiceDryRun:(BOOL)dryRun {
    StoreManager *sm = [StoreManager shared];
    CGFloat y = 16.0f;
    CGFloat margin = 12.0f;
    CGFloat contentW = kPrintWidth - (2 * margin);
    CGFloat baseSize = sm.fontSize;
    
    UIFont *headerFont = [UIFont boldSystemFontOfSize:baseSize + 10];
    UIFont *titleFont = [UIFont boldSystemFontOfSize:baseSize + 2];
    UIFont *bodyFont = sm.isBold ? [UIFont boldSystemFontOfSize:baseSize] : [UIFont systemFontOfSize:baseSize];
    UIFont *divFont = [UIFont fontWithName:@"Courier-Bold" size:15.0f] ?: [UIFont boldSystemFontOfSize:15.0f];
    
    UIImage *logo = [sm loadLogoImage];
    if (logo) {
        CGFloat logoW = (kPrintWidth / 3.0f) * sm.logoScale;
        CGFloat logoH = (logo.size.height / logo.size.width) * logoW;
        if (!dryRun) {
            [logo drawInRect:CGRectMake((kPrintWidth - logoW) / 2.0f, y, logoW, logoH)];
        }
        y += logoH + 12.0f;
    }
    
    y += [self drawText:sm.storeName inRect:CGRectMake(margin, y, contentW, 0) font:headerFont align:NSTextAlignmentCenter dryRun:dryRun] + 6;
    if (sm.phone.length > 0) {
        y += [self drawText:[NSString stringWithFormat:@"هاتف: %@", sm.phone] inRect:CGRectMake(margin, y, contentW, 0) font:bodyFont align:NSTextAlignmentCenter dryRun:dryRun] + 4;
    }
    if (sm.address.length > 0) {
        y += [self drawText:sm.address inRect:CGRectMake(margin, y, contentW, 0) font:bodyFont align:NSTextAlignmentCenter dryRun:dryRun] + 8;
    }
    
    NSString *dashes = @"--------------------------------------";
    NSString *stars = @"**************************************";
    y += [self drawText:dashes inRect:CGRectMake(margin, y, contentW, 0) font:divFont align:NSTextAlignmentCenter dryRun:dryRun] + 6;
    
    y += [self drawText:[NSString stringWithFormat:@"رقم الفاتورة: %ld", (long)sm.invoiceNumber] inRect:CGRectMake(margin, y, contentW, 0) font:titleFont align:NSTextAlignmentRight dryRun:dryRun] + 4;
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm";
    NSString *dateStr = [NSString stringWithFormat:@"التاريخ: %@", [df stringFromDate:[NSDate date]]];
    y += [self drawText:dateStr inRect:CGRectMake(margin, y, contentW, 0) font:bodyFont align:NSTextAlignmentRight dryRun:dryRun] + 6;
    
    y += [self drawText:stars inRect:CGRectMake(margin, y, contentW, 0) font:divFont align:NSTextAlignmentCenter dryRun:dryRun] + 6;
    y += [self drawText:@"الطلبات" inRect:CGRectMake(margin, y, contentW, 0) font:titleFont align:NSTextAlignmentRight dryRun:dryRun] + 8;
    
    for (InvoiceItemModel *item in sm.cartItems) {
        y += [self drawText:item.name inRect:CGRectMake(margin, y, contentW, 0) font:titleFont align:NSTextAlignmentRight dryRun:dryRun] + 2;
        NSString *line = [NSString stringWithFormat:@"%ld × %@ %@", (long)item.quantity, [self formatNumber:item.price], sm.currency];
        y += [self drawText:line inRect:CGRectMake(margin, y, contentW, 0) font:bodyFont align:NSTextAlignmentRight dryRun:dryRun] + 10;
    }
    
    y += [self drawText:dashes inRect:CGRectMake(margin, y, contentW, 0) font:divFont align:NSTextAlignmentCenter dryRun:dryRun] + 8;
    
    UIFont *totalFont = [UIFont boldSystemFontOfSize:baseSize + 6];
    NSString *totalVal = [NSString stringWithFormat:@"%@ %@", [self formatNumber:[sm cartTotal]], sm.currency];
    if (!dryRun) {
        [self drawText:@"المجموع الكلي:" inRect:CGRectMake(margin, y, contentW, 0) font:totalFont align:NSTextAlignmentRight dryRun:NO];
    }
    y += [self drawText:totalVal inRect:CGRectMake(margin, y, contentW, 0) font:totalFont align:NSTextAlignmentLeft dryRun:dryRun] + 10;
    
    y += [self drawText:dashes inRect:CGRectMake(margin, y, contentW, 0) font:divFont align:NSTextAlignmentCenter dryRun:dryRun] + 8;
    
    if (sm.footerMessage.length > 0) {
        y += [self drawText:sm.footerMessage inRect:CGRectMake(margin, y, contentW, 0) font:bodyFont align:NSTextAlignmentCenter dryRun:dryRun] + 10;
    }
    
    return y + 70.0f;
}

+ (UIImage *)createInvoiceBitmap {
    CGFloat height = [self renderInvoiceDryRun:YES];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kPrintWidth, height), YES, 1.0);
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0, 0, kPrintWidth, height));
    [self renderInvoiceDryRun:NO];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)generateQR:(NSString *)text size:(CGFloat)size {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *ciImage = filter.outputImage;
    if (!ciImage) return nil;
    
    CGAffineTransform transform = CGAffineTransformMakeScale(size / ciImage.extent.size.width, size / ciImage.extent.size.height);
    CIImage *scaled = [ciImage imageByApplyingTransform:transform];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImg = [context createCGImage:scaled fromRect:scaled.extent];
    UIImage *result = [UIImage imageWithCGImage:cgImg];
    CGImageRelease(cgImg);
    return result;
}

+ (UIImage *)createRechargeBitmapWithCompany:(NSInteger)companyIndex code:(NSString *)code amount:(NSString *)amount {
    NSArray *names = @[@"زين العراق - ZAIN", @"آسياسيل - ASIACELL", @"كورك - KOREK"];
    NSArray *prefixes = @[@"*101#", @"*133*", @"*221*"];
    NSString *compName = names[companyIndex];
    NSString *prefix = prefixes[companyIndex];
    
    CGFloat height = 680.0f;
    CGFloat margin = 12.0f;
    CGFloat contentW = kPrintWidth - (2 * margin);
    CGFloat y = 20.0f;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kPrintWidth, height), YES, 1.0);
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0, 0, kPrintWidth, height));
    
    y += [self drawText:compName inRect:CGRectMake(margin, y, contentW, 0) font:[UIFont boldSystemFontOfSize:34] align:NSTextAlignmentCenter dryRun:NO] + 10;
    y += [self drawText:[self formatNumber:[amount doubleValue]] inRect:CGRectMake(margin, y, contentW, 0) font:[UIFont boldSystemFontOfSize:36] align:NSTextAlignmentCenter dryRun:NO] + 6;
    y += [self drawText:[StoreManager shared].storeName inRect:CGRectMake(margin, y, contentW, 0) font:[UIFont boldSystemFontOfSize:26] align:NSTextAlignmentCenter dryRun:NO] + 14;
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    y += [self drawText:[df stringFromDate:[NSDate date]] inRect:CGRectMake(margin, y, contentW, 0) font:[UIFont boldSystemFontOfSize:20] align:NSTextAlignmentCenter dryRun:NO] + 18;
    
    y += [self drawText:@"الرقم السري" inRect:CGRectMake(margin, y, contentW, 0) font:[UIFont boldSystemFontOfSize:20] align:NSTextAlignmentCenter dryRun:NO] + 6;
    y += [self drawText:code inRect:CGRectMake(margin, y, contentW, 0) font:[UIFont boldSystemFontOfSize:28] align:NSTextAlignmentCenter dryRun:NO] + 14;
    
    NSString *instr = [NSString stringWithFormat:@"للتعبئة اضغط %@رقم الرصيد#", prefix];
    y += [self drawText:instr inRect:CGRectMake(margin, y, contentW, 0) font:[UIFont boldSystemFontOfSize:20] align:NSTextAlignmentCenter dryRun:NO] + 20;
    
    NSString *qrStr = [NSString stringWithFormat:@"%@%@%@", prefix, code, @"#"];
    UIImage *qr = [self generateQR:qrStr size:230.0f];
    if (qr) {
        [qr drawInRect:CGRectMake((kPrintWidth - 230.0f) / 2.0f, y, 230.0f, 230.0f)];
    }
    
    UIImage *finalImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return finalImg;
}

+ (UIImage *)createTestPatternBitmap {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kPrintWidth, 140), YES, 1.0);
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0, 0, kPrintWidth, 140));
    [self drawText:@"السلام عليكم" inRect:CGRectMake(10, 15, kPrintWidth - 20, 60) font:[UIFont boldSystemFontOfSize:46] align:NSTextAlignmentCenter dryRun:NO];
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(24, 90, kPrintWidth - 48, 30));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
