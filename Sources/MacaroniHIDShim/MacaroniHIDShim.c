// Trackpad-acceleration behavior is adapted from UnnaturalScrollWheels and
// NoMouseAccel. Copyright © 2020–2021 Theron Tjapkes. GPLv3.

#include "MacaroniHIDShim.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hidsystem/IOHIDLib.h>
#include <IOKit/IOKitLib.h>

static io_connect_t open_hid_system(void) {
    io_service_t service = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching(kIOHIDSystemClass)
    );
    if (service == IO_OBJECT_NULL) {
        return IO_OBJECT_NULL;
    }

    io_connect_t connection = IO_OBJECT_NULL;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), kIOHIDParamConnectType, &connection);
    IOObjectRelease(service);
    return result == KERN_SUCCESS ? connection : IO_OBJECT_NULL;
}

bool macaroni_get_trackpad_acceleration(double *value) {
    if (value == NULL) {
        return false;
    }

    io_connect_t connection = open_hid_system();
    if (connection == IO_OBJECT_NULL) {
        return false;
    }

    kern_return_t result = IOHIDGetAccelerationWithKey(
        connection,
        CFSTR("HIDTrackpadAcceleration"),
        value
    );
    IOServiceClose(connection);
    return result == KERN_SUCCESS;
}

bool macaroni_set_trackpad_acceleration(double value) {
    io_connect_t connection = open_hid_system();
    if (connection == IO_OBJECT_NULL) {
        return false;
    }

    kern_return_t result = IOHIDSetAccelerationWithKey(
        connection,
        CFSTR("HIDTrackpadAcceleration"),
        value
    );
    IOServiceClose(connection);
    return result == KERN_SUCCESS;
}
