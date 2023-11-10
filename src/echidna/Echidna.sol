// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaTestInvariant.sol";
import "./EchidnaTest.sol";
import "./EchidnaSplits.sol";
import "./EchidnaStreams.sol";
import "./EchidnaSqueeze.sol";

contract Echidna is
    EchidnaTestInvariant,
    EchidnaTest,
    EchidnaSplits,
    EchidnaStreams,
    EchidnaSqueeze
{}
