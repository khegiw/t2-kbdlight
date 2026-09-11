#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

int main(void) {
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    IOHIDManagerSetDeviceMatching(manager, NULL);
    IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
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
        fprintf(stderr, "T2 keyboard-backlight HID interface not found\n");
        return 1;
    }

    IOReturn opened = IOHIDDeviceOpen(target, kIOHIDOptionsTypeSeizeDevice);
    if (opened != kIOReturnSuccess) {
        fprintf(stderr, "Cannot open HID interface: 0x%x\n", opened);
        return 2;
    }

    uint8_t brightness[] = {0x01, 60, 60, 0, 0, 0x5e, 1, 0, 0};
    IOReturn setBrightness = IOHIDDeviceSetReport(target, kIOHIDReportTypeFeature, 0x01, brightness, sizeof(brightness));
    uint8_t power[] = {0x03, 1, 0x5e, 1, 0, 0};
    IOReturn setPower = IOHIDDeviceSetReport(target, kIOHIDReportTypeFeature, 0x03, power, sizeof(power));

    printf("brightness report: 0x%x\npower report: 0x%x\n", setBrightness, setPower);
    IOHIDDeviceClose(target, kIOHIDOptionsTypeSeizeDevice);
    CFRelease(devices);
    CFRelease(manager);
    return setBrightness == kIOReturnSuccess && setPower == kIOReturnSuccess ? 0 : 3;
}
