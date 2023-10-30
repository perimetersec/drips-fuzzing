// SPDX-License-Identifier: MIT

import "./EchidnaHelperStreams.sol";
import "./Debugger.sol";

contract EchidnaDebug is EchidnaHelperStreams {
    // function debugStartingBalanceIncreased(uint8 targetAccId) public {
    //     address target = getAccount(targetAccId);
    //     assert(token.balanceOf(target) <= STARTING_BALANCE);
    // }

    // function replayIncreaseBalance() public {
    //     give(0, 1, 1000);
    //     splitAndCollectToSelf(1);
    // }

    // function debugBalanceAt() public {
    //     uint8 targetAccId = 0;

    //     // _addStreamWithClamping(targetAccId, targetAccId, 0, 0, 0, 2);
    //     // setStreams(targetAccId, targetAccId, 1e9, 0, 0, 2);
    //     setStreams(targetAccId, targetAccId, 1e8, 0, 0, 2);

    //     address target = getAccount(targetAccId);
    //     uint256 targetDripsAccId = driver.calcAccountId(target);

    //     StreamReceiver[] memory receivers = getStreamReceivers(target);
    //     Debugger.log("receivers length", receivers.length);
    //     Debugger.log("receiver 0 amtPerSec", receivers[0].config.amtPerSec());

    //     // uint256 currentTimestamp = block.timestamp;
    //     // Debugger.log("currentTimestamp", currentTimestamp);
    //     Debugger.log("getCurrentCycleStart()", getCurrentCycleStart());
    //     Debugger.log("getCurrentCycleEnd()", getCurrentCycleEnd());

    //     uint128 balanceBefore = getStreamBalanceForUser(
    //         target,
    //         uint32(block.timestamp)
    //     );
    //     uint128 receivableBefore = getReceivableAmountForAllUsers();

    //     Debugger.log("timestamp before warp", uint32(block.timestamp));
    //     Debugger.log("balance before warp", balanceBefore);
    //     Debugger.log("receivable before warp", receivableBefore);

    //     Debugger.log("* WARP *");

    //     hevm.warp(getCurrentCycleEnd() + 1);
    //     // hevm.warp(getCurrentCycleEnd());
    //     uint128 balanceAfter = getStreamBalanceForUser(
    //         target,
    //         uint32(block.timestamp)
    //     );
    //     uint128 receivableAfter = getReceivableAmountForAllUsers();

    //     Debugger.log("timestamp after warp", uint32(block.timestamp));
    //     Debugger.log("balance after warp", balanceAfter);
    //     Debugger.log("receivable after warp", receivableAfter);

    //     assert(false);
    // }
}
