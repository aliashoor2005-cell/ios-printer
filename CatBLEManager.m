#import "CatBLEManager.h"
#import "ReceiptRenderer.h"
#import "StoreManager.h"

@implementation DiscoveredPrinter
@end

static const uint8_t CHECKSUM_TABLE[256] = {
    0, 7, 14, 9, 28, 27, 18, 21, 56, 63, 54, 49, 36, 35, 42, 45, 112, 119, 126, 121,
    108, 107, 98, 101, 72, 79, 70, 65, 84, 83, 90, 93, 224, 231, 238, 233, 252, 251,
    242, 245, 216, 223, 214, 209, 196, 195, 202, 205, 144, 151, 158, 153, 140,
    139, 130, 133, 168, 175, 166, 161, 180, 181, 186, 189, 199, 192, 201, 206,
    219, 220, 213, 210, 255, 248, 241, 246, 227, 228, 237, 234, 183, 176, 185, 190,
    171, 172, 165, 162, 143, 136, 129, 134, 147, 148, 157, 154, 39, 32, 41,
    46, 59, 60, 53, 50, 31, 24, 17, 22, 3, 4, 13, 10, 87, 80, 89, 94, 75, 76, 69, 66,
    111, 104, 97, 102, 115, 116, 125, 122, 137, 142, 135, 128, 149, 146, 155,
    156, 177, 182, 191, 184, 173, 170, 163, 164, 249, 254, 247, 240, 229, 226, 235, 236,
    193, 198, 207, 200, 221, 218, 211, 212, 105, 110, 103, 96, 117, 114, 123, 124, 81,
    86, 95, 88, 77, 74, 67, 68, 25, 30, 23, 16, 5, 2, 11, 12, 33, 38, 47, 40, 61, 58,
    51, 52, 78, 73, 64, 71, 82, 85, 92, 91, 118, 113, 120, 127, 106, 109, 100, 99, 62,
    57, 48, 55, 34, 37, 44, 43, 6, 1, 8, 15, 26, 29, 20, 19, 174, 169, 160, 167, 178,
    181, 188, 187, 150, 145, 152, 159, 138, 141, 132, 131, 222, 217, 208, 215,
    194, 197, 204, 203, 230, 225, 232, 239, 250, 253, 244, 243
};

@interface CatBLEManager ()
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *connectedPeripheral;
@property (nonatomic, strong) CBCharacteristic *txCharacteristic;
@property (nonatomic, strong) CBCharacteristic *rxCharacteristic;
@property (nonatomic, strong) NSMutableDictionary<NSUUID *, DiscoveredPrinter *> *discoveredMap;
@property (nonatomic, strong) NSMutableArray<NSData *> *writeQueue;
@property (nonatomic, assign) BOOL isSending;
@property (nonatomic, assign, readwrite) BOOL isConnected;
@property (nonatomic, assign, readwrite) BOOL isScanning;
@property (nonatomic, strong) dispatch_queue_t bleQueue;
@end

@implementation CatBLEManager

+ (instancetype)shared {
    static CatBLEManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[CatBLEManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _bleQueue = dispatch_queue_create("com.fatoorati.ble", DISPATCH_QUEUE_SERIAL);
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:_bleQueue];
        _discoveredMap = [NSMutableDictionary dictionary];
        _writeQueue = [NSMutableArray array];
    }
    return self;
}

- (uint8_t)crc8:(const uint8_t *)data start:(NSInteger)start length:(NSInteger)length {
    uint8_t checksum = 0;
    for (NSInteger i = start; i < start + length; i++) {
        checksum = CHECKSUM_TABLE[(checksum ^ data[i]) & 0xFF];
    }
    return checksum;
}

- (NSData *)buildCmdPrintFast:(NSData *)binaryData energy:(uint16_t)energy {
    NSMutableData *fullPayload = [NSMutableData data];
    
    uint8_t getDev[] = {0x51, 0x78, 0xA3, 0x00, 0x01, 0x00, 0x00, 0x00, 0xFF};
    [fullPayload appendBytes:getDev length:sizeof(getDev)];
    
    uint8_t setQual[] = {0x51, 0x78, 0xA4, 0x00, 0x01, 0x00, 0x32, 0x9E, 0xFF};
    [fullPayload appendBytes:setQual length:sizeof(setQual)];
    
    uint8_t setEnergy[] = {0x51, 0x78, 0xAF, 0x00, 0x02, 0x00, (uint8_t)((energy >> 8) & 0xFF), (uint8_t)(energy & 0xFF), 0x00, 0xFF};
    setEnergy[8] = [self crc8:setEnergy start:6 length:2];
    [fullPayload appendBytes:setEnergy length:sizeof(setEnergy)];
    
    uint8_t applyEnergy[] = {0x51, 0x78, 0xBE, 0x00, 0x01, 0x00, 0x01, 0x00, 0xFF};
    applyEnergy[7] = [self crc8:applyEnergy start:6 length:1];
    [fullPayload appendBytes:applyEnergy length:sizeof(applyEnergy)];
    
    uint8_t latticeStart[] = {0x51, 0x78, 0xA6, 0x00, 0x0B, 0x00, 0xAA, 0x55, 0x17, 0x38, 0x44, 0x5F, 0x5F, 0x5F, 0x44, 0x38, 0x2C, 0xA1, 0xFF};
    [fullPayload appendBytes:latticeStart length:sizeof(latticeStart)];
    
    const NSInteger rowSize = 48;
    const uint8_t *bytes = (const uint8_t *)binaryData.bytes;
    NSInteger totalLen = binaryData.length;
    NSInteger offset = 0;
    
    while (offset < totalLen) {
        NSInteger len = MIN(rowSize, totalLen - offset);
        uint8_t header[6] = {0x51, 0x78, 0xA2, 0x00, (uint8_t)len, 0x00};
        uint8_t crc = [self crc8:(bytes + offset) start:0 length:len];
        uint8_t tail[2] = {crc, 0xFF};
        
        [fullPayload appendBytes:header length:6];
        [fullPayload appendBytes:(bytes + offset) length:len];
        [fullPayload appendBytes:tail length:2];
        offset += len;
    }
    
    uint8_t feed[] = {0x51, 0x78, 0xBD, 0x00, 0x01, 0x00, 0x19, 0x00, 0xFF};
    feed[7] = [self crc8:feed start:6 length:1];
    [fullPayload appendBytes:feed length:sizeof(feed)];
    
    uint8_t setPaper[] = {0x51, 0x78, 0xA1, 0x00, 0x02, 0x00, 0x30, 0x00, 0xF9, 0xFF};
    [fullPayload appendBytes:setPaper length:sizeof(setPaper)];
    [fullPayload appendBytes:setPaper length:sizeof(setPaper)];
    [fullPayload appendBytes:setPaper length:sizeof(setPaper)];
    
    uint8_t latticeEnd[] = {0x51, 0x78, 0xA6, 0x00, 0x0B, 0x00, 0xAA, 0x55, 0x17, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17, 0x11, 0xFF};
    [fullPayload appendBytes:latticeEnd length:sizeof(latticeEnd)];
    
    [fullPayload appendBytes:getDev length:sizeof(getDev)];
    
    return fullPayload;
}

- (void)startScan {
    if (self.centralManager.state != CBCentralManagerStatePoweredOn) {
        [[StoreManager shared] addLog:@"🛑 البلوتوث مغلق. يرجى تفعيله من الإعدادات."];
        return;
    }
    [self.discoveredMap removeAllObjects];
    self.isScanning = YES;
    [[StoreManager shared] addLog:@"🔍 بدء البحث عن الطابعات..."];
    [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), _bleQueue, ^{
        if (self.isScanning) {
            [self stopScan];
        }
    });
}

- (void)stopScan {
    if (!self.isScanning) return;
    [self.centralManager stopScan];
    self.isScanning = NO;
    NSArray *list = [self.discoveredMap allValues];
    [[StoreManager shared] addLog:[NSString stringWithFormat:@"📡 انتهى البحث. الأجهزة المكتشفة: %lu", (unsigned long)list.count]];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(bleDidDiscoverPrinters:)]) {
            [self.delegate bleDidDiscoverPrinters:list];
        }
    });
}

- (void)connectToPeripheral:(CBPeripheral *)peripheral {
    [self stopScan];
    if (self.connectedPeripheral) {
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    self.connectedPeripheral = peripheral;
    self.connectedPeripheral.delegate = self;
    [[StoreManager shared] addLog:[NSString stringWithFormat:@"⏳ جاري الاتصال بـ %@...", peripheral.name ?: @"طابعة"]];
    [self.centralManager connectPeripheral:peripheral options:nil];
}

- (void)disconnect {
    if (self.connectedPeripheral) {
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    self.connectedPeripheral = nil;
    self.txCharacteristic = nil;
    self.rxCharacteristic = nil;
    self.isConnected = NO;
}

- (BOOL)printBitmap:(UIImage *)bitmap energy:(uint16_t)energy {
    if (!self.isConnected || !self.txCharacteristic) {
        [[StoreManager shared] addLog:@"🛑 الطابعة غير متصلة"];
        return NO;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[StoreManager shared] addLog:@"⚡ جاري معالجة الصورة وتجهيز البيانات السريعة..."];
        NSData *binaryData = [ReceiptRenderer bitmapToBinaryData:bitmap];
        NSData *payload = [self buildCmdPrintFast:binaryData energy:energy];
        
        [[StoreManager shared] addLog:[NSString stringWithFormat:@"🖨️ بدء الطباعة السريعة (%lu بايت)...", (unsigned long)payload.length]];
        
        dispatch_async(self.bleQueue, ^{
            [self.writeQueue removeAllObjects];
            NSInteger mtu = 20;
            if ([self.connectedPeripheral respondsToSelector:@selector(maximumWriteValueLengthForType:)]) {
                mtu = MAX(20, [self.connectedPeripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse]);
            }
            
            NSInteger offset = 0;
            while (offset < payload.length) {
                NSInteger len = MIN(mtu, payload.length - offset);
                [self.writeQueue addObject:[payload subdataWithRange:NSMakeRange(offset, len)]];
                offset += len;
            }
            [self pumpWriteQueue];
        });
    });
    
    return YES;
}

- (void)pumpWriteQueue {
    if (self.writeQueue.count == 0) {
        self.isSending = NO;
        [[StoreManager shared] addLog:@"✅ اكتمل إرسال بيانات الطباعة"];
        return;
    }
    self.isSending = YES;
    
    NSInteger burst = MIN(3, self.writeQueue.count);
    for (NSInteger i = 0; i < burst; i++) {
        NSData *chunk = self.writeQueue.firstObject;
        [self.writeQueue removeObjectAtIndex:0];
        [self.connectedPeripheral writeValue:chunk forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(18 * NSEC_PER_MSEC)), self.bleQueue, ^{
        [self pumpWriteQueue];
    });
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBCentralManagerStatePoweredOn) {
        [[StoreManager shared] addLog:@"✅ البلوتوث جاهز"];
        NSString *savedUUID = [StoreManager shared].lastPrinterUUID;
        if (savedUUID.length > 0) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:savedUUID];
            if (uuid) {
                NSArray *known = [central retrievePeripheralsWithIdentifiers:@[uuid]];
                if (known.count > 0) {
                    [self connectToPeripheral:known.firstObject];
                }
            }
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSString *name = peripheral.name ?: advertisementData[CBAdvertisementDataLocalNameKey];
    if (name.length == 0) return;
    
    DiscoveredPrinter *dp = [[DiscoveredPrinter alloc] init];
    dp.peripheral = peripheral;
    dp.name = name;
    dp.rssi = RSSI;
    self.discoveredMap[peripheral.identifier] = dp;
    [[StoreManager shared] addLog:[NSString stringWithFormat:@"📍 وجدنا: %@ [%@ dBm]", name, RSSI]];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [[StoreManager shared] addLog:@"✅ تم الاتصال. جاري اكتشاف الخدمات..."];
    [peripheral discoverServices:@[[CBUUID UUIDWithString:@"AE30"], [CBUUID UUIDWithString:@"AF30"]]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.isConnected = NO;
    self.txCharacteristic = nil;
    self.rxCharacteristic = nil;
    [[StoreManager shared] addLog:@"🔌 تم قطع الاتصال بالطابعة"];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(bleDidUpdateConnectionState:statusText:)]) {
            [self.delegate bleDidUpdateConnectionState:NO statusText:@"غير متصلة"];
        }
    });
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"AE01"], [CBUUID UUIDWithString:@"AE02"]] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *c in service.characteristics) {
        if ([c.UUID isEqual:[CBUUID UUIDWithString:@"AE01"]]) {
            self.txCharacteristic = c;
        } else if ([c.UUID isEqual:[CBUUID UUIDWithString:@"AE02"]]) {
            self.rxCharacteristic = c;
            [peripheral setNotifyValue:YES forCharacteristic:c];
        }
    }
    
    if (self.txCharacteristic) {
        self.isConnected = YES;
        [StoreManager shared].lastPrinterUUID = peripheral.identifier.UUIDString;
        [[StoreManager shared] saveSettings];
        [[StoreManager shared] addLog:[NSString stringWithFormat:@"✅ الطابعة جاهزة للعمل: %@", peripheral.name]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bleDidUpdateConnectionState:statusText:)]) {
                [self.delegate bleDidUpdateConnectionState:YES statusText:@"متصلة وجاهزة"];
            }
        });
    }
}

@end
