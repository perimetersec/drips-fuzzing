// SPDX-License-Identifier: MIT
import {Managed} from "src/Managed.sol";

/**
 * @title Wrapper around Managed with minor fuzzing helpers
 * @author Rappie <rappie@perimetersec.io>
 */
contract ManagedEchidna is Managed {
    constructor() Managed() {}

    /**
     * @notice Helper function to unpause the contract as any user
     */
    function unpause_noModifiers() public {
        _managedStorage().isPaused = false;
        emit Unpaused(msg.sender);
    }
}
