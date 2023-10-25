// SPDX-License-Identifier: MIT

import "./EchidnaInvariantTests.sol";
import "./EchidnaBasicTests.sol";
import "./EchidnaSplitsTests.sol";
import "./EchidnaStreamsTests.sol";
import "./EchidnaSqueezeTests.sol";

/**
 * @title Echidna contract for testing the Drips contract
 * @author Rappie <rappie@perimetersec.io>
 * @dev Running the tests:
 * For Echidna use `echidna . --contract Echidna --config echidna-config.yaml`.
 * For Medusa use `medusa fuzz`.
 * The tests are split into multiple files to be able to toggle the fuzzing
 * of specific features on and off. This is done by commenting out the
 * corresponding inherited contract in the Echidna contract below.
 * Basic tests contain basic features like giving, receiving, splitting and
 * collecting.
 * Splits tests contain tests for splitting.
 * Streams tests contain tests for receiving streams.
 * Squeeze tests contain tests for squeezing.
 * Invariant tests contain tests for invariant properties of the system. These
 * make most sense with all other tests enabled.
 * For further performance improvements, resource heavy tests can be toggled.
 * To do so, change the value of TOGGLE_HEAVY_TESTS_ENABLED in EchidnaConfig.
 */
contract Echidna is
    EchidnaBasicTests,
    EchidnaSplitsTests,
    EchidnaStreamsTests,
    EchidnaSqueezeTests,
    EchidnaInvariantTests
{

}
