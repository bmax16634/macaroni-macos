#ifndef MACARONI_HID_SHIM_H
#define MACARONI_HID_SHIM_H

#include <stdbool.h>

bool macaroni_get_trackpad_acceleration(double *value);
bool macaroni_set_trackpad_acceleration(double value);

#endif
