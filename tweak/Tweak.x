// LieferandoFresh Tweak.x — Per-Crane-Container Fingerprint-Spoof (mit Auto-Profil)
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <substrate.h>

static NSDictionary *gProfile = nil;
static CLLocationCoordinate2D gCoord = {0, 0};
static NSUUID *gIDFA = nil;

static CFDictionaryRef (*origCNCopyCurrentNetworkInfo)(CFStringRef interfaceName);

static unsigned long long uuidHash(NSString *s) {
    unsigned long long h = 1469598103934665603ULL;
    for (NSUInteger i = 0; i < s.length; i++) {
        h ^= (unsigned long long)[s characterAtIndex:i];
        h *= 1099511628211ULL;
    }
    return h;
}

static NSDictionary *autoProfile(NSString *uuidStr) {
    unsigned long long h = uuidHash(uuidStr);
    double cities[5][2] = {{52.52,13.405},{48.1351,11.582},{50.9375,6.9603},{53.5511,9.9937},{51.2277,6.7735}};
    int c = (int)(h % 5);
    double lat = cities[c][0] + (double)((h >> 8) & 0xFF) / 1000.0;
    double lon = cities[c][1] + (double)((h >> 16) & 0xFF) / 1000.0;
    NSArray *vendors = @[@"FRITZ!Box", @"Telekom-5G", @"Vodafone-5G", @"o2-WLAN", @"UPC-Connect"];
    NSString *ssid = [NSString stringWithFormat:@"%@-%llu", vendors[c], (h >> 4) % 10000];
    NSString *bssid = [NSString stringWithFormat:@"%02llX:%02llX:%02llX:%02llX:%02llX:%02llX",
        ((h >> 8) & 0xFF) | 2, (h >> 16) & 0xFF, (h >> 24) & 0xFF,
        (h >> 32) & 0xFF, (h >> 40) & 0xFF, (h >> 48) & 0xFF];
    NSString *idfa = [NSString stringWithFormat:@"%08llX-%04llX-%04llX-%04llX-%012llX",
        h & 0xFFFFFFFFULL, (h >> 32) & 0xFFFFULL, (h >> 48) & 0xFFFFULL,
        (h >> 60) & 0xFFFFULL, (h >> 12) & 0xFFFFFFFFFFFFULL];
    return @{ @"lat": @(lat), @"lon": @(lon), @"ssid": ssid, @"bssid": bssid, @"idfa": idfa };
}

static NSDictionary *loadProfile(void) {
    NSDictionary *all = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Documents/LieferandoFresh/profiles.plist"];
    if (!all) all = [NSDictionary dictionary];
    NSDictionary *crane = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.opa334.craneprefs.plist"];
    NSString *active = crane[@"appSettings_com.yourdelivery.lieferando"][@"activeContainer"];
    NSDictionary *p = all[active];
    if (p) return p;
    // Auto-Profil: jede unbekannte Container-UUID bekommt deterministisch eigene Werte
    if ([active isKindOfClass:[NSString class]] && active.length > 0 && ![active isEqualToString:@"DEFAULT"]) {
        return autoProfile(active);
    }
    return all[@"DEFAULT"];
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
