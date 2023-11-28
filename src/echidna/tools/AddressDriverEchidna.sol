// SPDX-License-Identifier: MIT
import {AddressDriver} from "src/AddressDriver.sol";

import {DripsEchidna} from "./DripsEchidna.sol";
import {ManagedEchidna} from "./ManagedEchidna.sol";

/**
 * @title Wrapper around AddressDriver with minor fuzzing helpers
 * @author Rappie <rappie@perimetersec.io>
 */
contract AddressDriverEchidna is AddressDriver, ManagedEchidna {
    constructor(
        DripsEchidna drips_,
        address forwarder,
        uint32 driverId_
    ) AddressDriver(drips_, forwarder, driverId_) {}
}
