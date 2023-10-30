// SPDX-License-Identifier: MIT

import {IERC20, ERC20PresetFixedSupply} from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import {ManagedProxy} from "src/Managed.sol";
import {Drips, SplitsReceiver, StreamReceiver, StreamConfig, StreamConfigImpl, StreamsHistory} from "src/Drips.sol";
import {AddressDriver} from "src/AddressDriver.sol";

contract EchidnaConfig {
    address internal constant ADDRESS_USER0 = address(0x10000);
    address internal constant ADDRESS_USER1 = address(0x20000);
    address internal constant ADDRESS_USER2 = address(0x30000);
    address internal constant ADDRESS_USER3 = address(0x40000);

    mapping(address => uint8) internal ADDRESS_TO_ACCOUNT_ID;

    uint256 internal STARTING_TIMESTAMP;

    uint256 internal constant STARTING_BALANCE = 1_000_000_000e18;
    uint32 internal constant SECONDS_PER_CYCLE = 10;

    uint32 internal constant CYCLE_FUZZING_BUFFER_CYCLES = 10;
    uint32 internal constant CYCLE_FUZZING_BUFFER_SECONDS =
        CYCLE_FUZZING_BUFFER_CYCLES * SECONDS_PER_CYCLE;

    uint160 internal constant MAX_AMOUNT_PER_SEC =
        (uint160(STARTING_BALANCE) / uint160(SECONDS_PER_CYCLE)) * 1e9;

    uint32 internal constant MAX_STREAM_DURATION = CYCLE_FUZZING_BUFFER_SECONDS;

    bool internal constant TOGGLE_EXPERIMENTAL_TESTS_ENABLED = true;
    bool internal constant TOGGLE_GIVE_ENABLED = true;
    bool internal constant TOGGLE_MAXENDHINTS_ENABLED = true;

    constructor() {
        ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0] = 0;
        ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1] = 64;
        ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2] = 128;
        ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3] = 192;
    }

    function getAccount(uint8 rawId) internal pure returns (address) {
        uint256 id = uint256(rawId) / 64;

        if (id == 0) return ADDRESS_USER0;
        if (id == 1) return ADDRESS_USER1;
        if (id == 2) return ADDRESS_USER2;
        if (id == 3) return ADDRESS_USER3;

        require(false, "Unknown account ID");
    }
}