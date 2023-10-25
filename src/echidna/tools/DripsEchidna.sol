// SPDX-License-Identifier: MIT
import {IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Drips} from "src/Drips.sol";

import {ManagedEchidna} from "./ManagedEchidna.sol";

/**
 * @title Wrapper around Drips with minor fuzzing helpers
 * @author Rappie <rappie@perimetersec.io>
 */
contract DripsEchidna is Drips, ManagedEchidna {
    constructor(uint32 cycleSecs_) Drips(cycleSecs_) {}

    /**
     * @notice Get the amtDelta for a given user and cycle
     * @param accountId The account to get the amtDelta for
     * @param erc20 The ERC20 token
     * @param cycle The cycle to get the amtDelta for
     * @return The amtDelta for this cycle and the next cycle
     */
    function getAmtDeltaForCycle(
        uint256 accountId,
        IERC20 erc20,
        uint32 cycle
    ) public view returns (int128, int128) {
        // Manually calculate the storage slot because it is a private variable
        // in Streams
        StreamsStorage storage streamsStorage;
        bytes32 slot = _erc1967Slot("eip1967.streams.storage");
        assembly {
            streamsStorage.slot := slot
        }

        // Return the amtDelta for the given cycle
        StreamsState storage state = streamsStorage.states[erc20][accountId];
        mapping(uint32 cycle => AmtDelta) storage amtDeltas = state.amtDeltas;
        return (amtDeltas[cycle].thisCycle, amtDeltas[cycle].nextCycle);
    }
}
