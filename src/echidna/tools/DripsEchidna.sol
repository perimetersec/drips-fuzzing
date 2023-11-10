// SPDX-License-Identifier: MIT
import {IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Drips} from "src/Drips.sol";

import {ManagedEchidna} from "./ManagedEchidna.sol";

contract DripsEchidna is Drips, ManagedEchidna {
    constructor(uint32 cycleSecs_) Drips(cycleSecs_) {}

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
