// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaTestInvariant.sol";
import "./EchidnaTest.sol";
import "./EchidnaSplitsHelpers.sol";
import "./EchidnaSplitsTests.sol";
import "./EchidnaStreams.sol";
import "./EchidnaSqueeze.sol";

contract Echidna is
    EchidnaTestInvariant,
    EchidnaTest,
    // EchidnaSplitsHelpers,
    EchidnaSplitsTests,
    EchidnaStreams,
    EchidnaSqueeze
{}
