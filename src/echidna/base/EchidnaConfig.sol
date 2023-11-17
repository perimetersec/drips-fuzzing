// SPDX-License-Identifier: MIT

import {IERC20, ERC20PresetFixedSupply} from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import {ManagedProxy} from "src/Managed.sol";
import {Drips, SplitsReceiver, StreamReceiver, StreamConfig, StreamConfigImpl, StreamsHistory} from "src/Drips.sol";
import {AddressDriver} from "src/AddressDriver.sol";

import {DripsEchidna} from "../tools/DripsEchidna.sol";
import {AddressDriverEchidna} from "../tools/AddressDriverEchidna.sol";

import "../tools/Debugger.sol";

/**
 * @title Mixin containing the configuration for the fuzzing campaign
 * @author Rappie
 */
contract EchidnaConfig {
    // Addresses used for the simulated users
    address internal constant ADDRESS_USER0 = address(0x10000);
    address internal constant ADDRESS_USER1 = address(0x20000);
    address internal constant ADDRESS_USER2 = address(0x30000);
    address internal constant ADDRESS_USER3 = address(0x40000);

    // Mappings from address to account id
    mapping(address => uint8) internal ADDRESS_TO_ACCOUNT_ID;
    mapping(address => uint256) internal ADDRESS_TO_DRIPS_ACCOUNT_ID;

    // Variable to store the timestamp when fuzzing starts
    uint256 internal STARTING_TIMESTAMP;

    // Starting token balance of the simulated users
    uint256 internal constant STARTING_BALANCE = 1_000_000_000e18;

    // Amount of seconds in a Drips cycle
    uint32 internal constant SECONDS_PER_CYCLE = 10;

    // Buffers to be used as fuzzing boundaries
    uint32 internal constant CYCLE_FUZZING_BUFFER_CYCLES = 10;
    uint32 internal constant CYCLE_FUZZING_BUFFER_SECONDS =
        CYCLE_FUZZING_BUFFER_CYCLES * SECONDS_PER_CYCLE;

    // Maximum amount of streamable funds per second that make sense based
    // on the starting balance of the simulated users
    uint160 internal constant MAX_AMOUNT_PER_SEC =
        (uint160(STARTING_BALANCE) / uint160(SECONDS_PER_CYCLE)) * 1e9;

    // Sensible maximum amount of seconds for a stream
    uint32 internal constant MAX_STREAM_DURATION = CYCLE_FUZZING_BUFFER_SECONDS;

    // Due to the inner workings of the splitting algorithm Drips uses,
    // it is unpredictable wether a split will be rounded up or down. To
    // remedy this, allow a tolerance for the expected split amount.
    uint256 internal constant SPLIT_ROUNDING_TOLERANCE = 1;

    // Toggles for certain tests
    bool internal constant TOGGLE_EXPERIMENTAL_TESTS_ENABLED = true;
    bool internal constant TOGGLE_HEAVY_TESTS_ENABLED = true;
    bool internal constant TOGGLE_MAXENDHINTS_ENABLED = true;

    // Modifier to toggle experimental tests
    modifier experimental() {
        if (!TOGGLE_EXPERIMENTAL_TESTS_ENABLED) return;
        _;
    }

    // Modifier to toggle performance heavy tests
    modifier heavy() {
        if (!TOGGLE_HEAVY_TESTS_ENABLED) return;
        _;
    }

    constructor() {
        ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0] = 0;
        ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1] = 64;
        ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2] = 128;
        ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3] = 192;
    }

    /*
     * @notice Get the address for a certain account id
     * @param rawId The raw account id
     * @return The address for the account id
     * @dev In this case we have 4 users, spread over the range of 256 (8 bits).
     */
    function getAccount(uint8 rawId) internal pure returns (address) {
        uint256 id = uint256(rawId) / 64;

        if (id == 0) return ADDRESS_USER0;
        if (id == 1) return ADDRESS_USER1;
        if (id == 2) return ADDRESS_USER2;
        if (id == 3) return ADDRESS_USER3;

        require(false, "Unknown account ID");
    }
}
