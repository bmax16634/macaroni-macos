// Trackpad-acceleration behavior is adapted from UnnaturalScrollWheels and
// NoMouseAccel. Copyright © 2020–2021 Theron Tjapkes. GPLv3.

import Foundation
import MacaroniHIDShim

enum TrackpadAccelerationError: LocalizedError {
    case couldNotRead
    case couldNotWrite

    var errorDescription: String? {
        switch self {
        case .couldNotRead: "Could not read the current trackpad acceleration value."
        case .couldNotWrite: "Could not update trackpad acceleration."
        }
    }
}

final class TrackpadAccelerationController: @unchecked Sendable {
    private let originalKey = "originalTrackpadAccelerationV1"
    private let defaults = UserDefaults.standard

    func setDisabled(_ disabled: Bool) throws {
        if disabled {
            var value: Double = 0
            guard macaroni_get_trackpad_acceleration(&value) else {
                throw TrackpadAccelerationError.couldNotRead
            }
            if value != -1, defaults.object(forKey: originalKey) == nil {
                defaults.set(value, forKey: originalKey)
            }
            guard macaroni_set_trackpad_acceleration(-1) else {
                throw TrackpadAccelerationError.couldNotWrite
            }
        } else {
            try restoreOriginalValue()
        }
    }

    func restoreOriginalValue() throws {
        guard defaults.object(forKey: originalKey) != nil else { return }
        let original = defaults.double(forKey: originalKey)
        guard macaroni_set_trackpad_acceleration(original) else {
            throw TrackpadAccelerationError.couldNotWrite
        }
        defaults.removeObject(forKey: originalKey)
    }
}
