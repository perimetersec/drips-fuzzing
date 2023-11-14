// SPDX-License-Identifier: MIT

import "./EchidnaInvariantTests.sol";
import "./EchidnaBasicTests.sol";
import "./EchidnaSplitsTests.sol";
import "./EchidnaStreamsTests.sol";
import "./EchidnaSqueezeTests.sol";

contract Echidna is
    EchidnaInvariantTests,
    EchidnaBasicTests,
    EchidnaSplitsTests,
    EchidnaStreamsTests,
    EchidnaSqueezeTests
{}
