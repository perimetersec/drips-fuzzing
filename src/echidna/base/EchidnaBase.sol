// SPDX-License-Identifier: MIT

import "./EchidnaSetup.sol";
import "./EchidnaStorage.sol";
import "./EchidnaAccounting.sol";

/**
 * @title Mixin grouping together all base contracts
 * @author Rappie
 */
contract EchidnaBase is
    EchidnaSetup,
    EchidnaStorage,
    EchidnaAccounting
{}
