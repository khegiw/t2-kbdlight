#import <Foundation/Foundation.h>
#import <IOKit/IOMessage.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <dispatch/dispatch.h>
#import <unistd.h>

static io_connect_t powerRootPort;
static dispatch_queue_t restoreQueue;
static bool restorePending;
static bool systemSleeping;

static void logResult(NSString *message) {
    fprintf(stdout, "%s %s\n", NSDate.date.description.UTF8String, message.UTF8String);
    fflush(stdout);
}

static int applyBacklight(bool turnOn) {
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    NSDictionary *matching = @{
        @kIOHIDVendorIDKey: @0x05ac,
        @kIOHIDProductIDKey: @0x8102,
        @kIOHIDPrimaryUsagePageKey: @0xff00,
        @kIOHIDPrimaryUsageKey: @15
    };
    IOHIDManagerSetDeviceMatching(manager, (__bridge CFDictionaryRef)matching);
    IOReturn managerOpened = IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
    if (managerOpened != kIOReturnSuccess) {
        logResult([NSString stringWithFormat:@"HID manager open failed: 0x%x", managerOpened]);
        CFRelease(manager);
        return 4;
    }
    CFSetRef devices = IOHIDManagerCopyDevices(manager);
    IOHIDDeviceRef target = NULL;

    for (id item in (__bridge NSSet *)devices) {
        IOHIDDeviceRef device = (__bridge IOHIDDeviceRef)item;
        NSNumber *vendor = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        NSNumber *product = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
        NSNumber *page = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPrimaryUsagePageKey));
        NSNumber *usage = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPrimaryUsageKey));
        if (vendor.unsignedIntValue == 0x05ac && product.unsignedIntValue == 0x8102 && page.unsignedIntValue == 0xff00 && usage.unsignedIntValue == 15) {
            target = device;
            break;
        }
    }

    if (!target) {
        if (devices) CFRelease(devices);
        IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
        CFRelease(manager);
        return 1;
    }

    IOReturn opened = IOHIDDeviceOpen(target, kIOHIDOptionsTypeNone);
    if (opened != kIOReturnSuccess) {
        logResult([NSString stringWithFormat:@"HID device open failed: 0x%x", opened]);
        CFRelease(devices);
        IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
        CFRelease(manager);
        return 2;
    }

    uint8_t powerOff[] = {0x03, 0, 0x5e, 1, 0, 0};
    IOReturn setPowerOff = IOHIDDeviceSetReport(target, kIOHIDReportTypeFeature, 0x03, powerOff, sizeof(powerOff));
    IOReturn setBrightness = kIOReturnSuccess;
    IOReturn setPower = kIOReturnSuccess;
    if (turnOn) {
        usleep(250000);
        uint8_t brightness[] = {0x01, 30, 30, 1, 1, 0x5e, 1, 0, 0};
        setBrightness = IOHIDDeviceSetReport(target, kIOHIDReportTypeFeature, 0x01, brightness, sizeof(brightness));
        uint8_t power[] = {0x03, 1, 0x5e, 1, 0, 0};
        setPower = IOHIDDeviceSetReport(target, kIOHIDReportTypeFeature, 0x03, power, sizeof(power));
    }

    IOHIDDeviceClose(target, kIOHIDOptionsTypeNone);
    CFRelease(devices);
    IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
    CFRelease(manager);
    return setPowerOff == kIOReturnSuccess && setBrightness == kIOReturnSuccess && setPower == kIOReturnSuccess ? 0 : 3;
}

static int applyWithRetries(int attempts) {
    int result = 1;
    for (int attempt = 1; attempt <= attempts; attempt++) {
        result = applyBacklight(true);
        if (result == 0) {
            logResult([NSString stringWithFormat:@"backlight restored on attempt %d", attempt]);
            return 0;
        }
        if (attempt < attempts) usleep(250000);
    }
    logResult([NSString stringWithFormat:@"backlight restore failed with code %d after %d attempts", result, attempts]);
    return result;
}

static void scheduleRestore(uint64_t delayMilliseconds) {
    dispatch_async(restoreQueue, ^{
        if (systemSleeping) return;
        if (restorePending) return;
        restorePending = true;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayMilliseconds * NSEC_PER_MSEC), restoreQueue, ^{
            if (systemSleeping) {
                restorePending = false;
                return;
            }
            @autoreleasepool {
                applyWithRetries(10);
            }
            restorePending = false;
        });
    });
}

static void powerCallback(void *refcon, io_service_t service, natural_t messageType, void *messageArgument) {
    (void)refcon;
    (void)service;
    if (messageType == kIOMessageCanSystemSleep) {
        IOAllowPowerChange(powerRootPort, (long)messageArgument);
    } else if (messageType == kIOMessageSystemWillSleep) {
        dispatch_sync(restoreQueue, ^{
            systemSleeping = true;
            int result = applyBacklight(false);
            logResult(result == 0 ? @"backlight disabled for sleep" : [NSString stringWithFormat:@"backlight sleep disable failed with code %d", result]);
        });
        IOAllowPowerChange(powerRootPort, (long)messageArgument);
    } else if (messageType == kIOMessageSystemHasPoweredOn) {
        logResult(@"wake detected");
        dispatch_sync(restoreQueue, ^{
            systemSleeping = false;
        });
        scheduleRestore(250);
    }
}

static void fallbackCallback(CFRunLoopTimerRef timer, void *info) {
    (void)timer;
    (void)info;
    scheduleRestore(0);
}

static int watchPower(void) {
    IONotificationPortRef notifyPort;
    io_object_t notifier;
    restoreQueue = dispatch_queue_create("local.t2-kbdlight.restore", DISPATCH_QUEUE_SERIAL);
    powerRootPort = IORegisterForSystemPower(NULL, &notifyPort, powerCallback, &notifier);
    if (!powerRootPort) {
        logResult(@"power notification registration failed");
        return 4;
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notifyPort), kCFRunLoopDefaultMode);
    CFRunLoopTimerContext context = {0, NULL, NULL, NULL, NULL};
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + 300, 300, 0, 0, fallbackCallback, &context);
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
    applyWithRetries(10);
    logResult(@"watching for wake events");
    CFRunLoopRun();
    CFRelease(timer);
    IODeregisterForSystemPower(&notifier);
    IOServiceClose(powerRootPort);
    IONotificationPortDestroy(notifyPort);
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "--watch") == 0) return watchPower();
        return applyWithRetries(1);
    }
}
