TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e
THEOS_PACKAGE_SCHEME := roothide

INSTALL_TARGET_PROCESSES = MainApp

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LieferandoFresh
LieferandoFresh_FILES = Tweak.x
LieferandoFresh_CFLAGS = -fobjc-arc
LieferandoFresh_FRAMEWORKS = UIKit Foundation CoreLocation AdSupport SystemConfiguration
LieferandoFresh_FILTER_FILES = LieferandoFresh.plist

include $(THEOS_MAKE_PATH)/tweak.mk
