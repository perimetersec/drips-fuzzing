// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaTestInvariant.sol";
import "./EchidnaTest.sol";
import "./EchidnaSplitsTests.sol";
import "./EchidnaStreamsTests.sol";
import "./EchidnaSqueezeTests.sol";

contract Echidna is
    EchidnaTestInvariant,
    EchidnaTest,
    EchidnaSplitsTests,
    EchidnaStreamsTests,
    EchidnaSqueezeTests
{}
