#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>

@interface DiscoveredPrinter : NSObject
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSNumber *rssi;
@end

@protocol CatBLEManagerDelegate <NSObject>
@optional
- (void)bleDidUpdateConnectionState:(BOOL)connected statusText:(NSString *)status;
- (void)bleDidDiscoverPrinters:(NSArray<DiscoveredPrinter *> *)printers;
@end

@interface CatBLEManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
+ (instancetype)shared;
@property (nonatomic, weak) id<CatBLEManagerDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isConnected;
@property (nonatomic, assign, readonly) BOOL isScanning;

- (void)startScan;
- (void)stopScan;
- (void)connectToPeripheral:(CBPeripheral *)peripheral;
- (void)disconnect;
- (BOOL)printBitmap:(UIImage *)bitmap energy:(uint16_t)energy;
@end
