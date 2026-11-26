ARCHS = armv7
TARGET = iphone:clang:8.1:8.0
INSTALL_TARGET_PROCESSES = Fatoorati

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Fatoorati
Fatoorati_FILES = main.m AppDelegate.m MainViewController.m SettingsViewController.m ItemsViewController.m BalanceViewController.m LogsViewController.m CatBLEManager.m ReceiptRenderer.m StoreManager.m
Fatoorati_FRAMEWORKS = UIKit Foundation CoreGraphics CoreBluetooth CoreImage QuartzCore
Fatoorati_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/application.mk
