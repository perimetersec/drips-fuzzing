// SPDX-License-Identifier: MIT
import {AddressDriver} from "../AddressDriver.sol";

import {DripsEchidna} from "./DripsEchidna.sol";
import {ManagedEchidna} from "./ManagedEchidna.sol";

contract AddressDriverEchidna is AddressDriver, ManagedEchidna {
    constructor(
        DripsEchidna drips_,
        address forwarder,
        uint32 driverId_
    ) AddressDriver(drips_, forwarder, driverId_) {}
}
