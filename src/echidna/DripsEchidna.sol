// SPDX-License-Identifier: MIT
import {Drips} from "../Drips.sol";

import {ManagedEchidna} from "./ManagedEchidna.sol";

contract DripsEchidna is Drips, ManagedEchidna {
    constructor(uint32 cycleSecs_) Drips(cycleSecs_) {}
}
