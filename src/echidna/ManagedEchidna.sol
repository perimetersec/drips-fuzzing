// SPDX-License-Identifier: MIT
import {Managed} from "../Managed.sol";

contract ManagedEchidna is Managed {
    constructor() Managed() {}

    function unpause_noModifiers() public {
        _managedStorage().isPaused = false;
        emit Unpaused(msg.sender);
    }
}
