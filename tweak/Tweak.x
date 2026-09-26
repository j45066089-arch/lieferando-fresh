# LieferandoFresh Tweak.x — Per-Crane-Container Fingerprint-Spoof
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <substrate.h>

static NSDictionary *gProfile = nil;
static CLLocationCoordinate2D gCoord = {0, 0};
static NSUUID *gIDFA = nil;

static CFDictionaryRef (*origCNCopyCurrentNetworkInfo)(CFStringRef interfaceName);

static NSDictionary *loadProfile(void) {
    NSDictionary *all = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Documents/LieferandoFresh/profiles.plist"];
    if (!all) all = [NSDictionary dictionary];
    NSDictionary *crane = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.opa334.craneprefs.plist"];
    NSString *active = crane[@"appSettings_com.yourdelivery.lieferando"][@"activeContainer"];
    NSDictionary *p = all[active];
    if (!p) p = all[@"DEFAULT"];
    return p;
}

static CFDictionaryRef fakeCN(CFStringRef interfaceName) {
    if (gProfile) {
        NSString *ssid = gProfile[@"ssid"];
        NSString *bssid = gProfile[@"bssid"];
        if (ssid.length > 0) {
            NSDictionary *d = @{ @"SSID" : ssid, @"BSSID" : (bssid.length ? bssid : @"AA:BB:CC:DD:EE:FF") };
            return (CFDictionaryRef)CFBridgingRetain(d);
        }
    }
    return origCNCopyCurrentNetworkInfo(interfaceName);
}

%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    if (gProfile) return gCoord;
    return %orig;
}
- (CLLocationDistance)horizontalAccuracy { if (gProfile) return 5.0; return %orig; }
- (CLLocationDistance)verticalAccuracy { if (gProfile) return 5.0; return %orig; }
- (CLLocationDistance)altitude { if (gProfile) return 35.0; return %orig; }
- (CLLocationSpeed)speed { if (gProfile) return 0.0; return %orig; }
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (gIDFA) return gIDFA;
    return %orig;
}
- (BOOL)isAdvertisingTrackingEnabled { return YES; }
%end

%ctor {
    gProfile = loadProfile();
    if (gProfile) {
        double lat = [gProfile[@"lat"] doubleValue];
        double lon = [gProfile[@"lon"] doubleValue];
        if (lat == 0 && lon == 0) { lat = 52.52; lon = 13.405; }
        gCoord = CLLocationCoordinate2DMake(lat, lon);
        NSString *idfa = gProfile[@"idfa"];
        if (idfa.length) gIDFA = [[NSUUID alloc] initWithUUIDString:idfa];
    }
    void *sym = MSFindSymbol(NULL, "_CNCopyCurrentNetworkInfo");
    if (sym) {
        MSHookFunction(sym, (void *)fakeCN, (void **)&origCNCopyCurrentNetworkInfo);
    }
}
