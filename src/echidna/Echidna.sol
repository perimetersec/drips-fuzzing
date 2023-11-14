// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaTestInvariant.sol";
import "./EchidnaTest.sol";
import "./EchidnaSplitsHelpers.sol";
import "./EchidnaSplitsTests.sol";
import "./EchidnaStreamsHelpers.sol";
import "./EchidnaStreamsTests.sol";
import "./EchidnaSqueezeHelpers.sol";
import "./EchidnaSqueezeTests.sol";

contract Echidna is
    EchidnaTestInvariant,
    EchidnaTest,
    // EchidnaSplitsHelpers,
    EchidnaSplitsTests,
    // EchidnaStreamsHelpers,
    EchidnaStreamsTests,
    // EchidnaSqueezeHelpers,
    EchidnaSqueezeTests
{}
