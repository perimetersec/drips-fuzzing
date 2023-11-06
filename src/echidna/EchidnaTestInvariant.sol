// SPDX-License-Identifier: MIT

import "./EchidnaTest.sol";
import "./Debugger.sol";

contract EchidnaTestInvariant is EchidnaTest {
    ///@notice Withdrawing directly from Drips should always fail
    function invariantWithdrawShouldAlwaysFail(uint256 amount) public {
        require(amount > 0);

        try drips.withdraw(token, address(this), amount) {
            assert(false);
        } catch {}
    }

    ///@notice `amtPerSec` should never be lower than `drips.minAmtPerSec()`
    function invariantAmtPerSecVsMinAmtPerSec(uint8 targetAccId, uint256 index)
        public
    {
        address target = getAccount(targetAccId);

        StreamReceiver[] memory receivers = getStreamReceivers(target);
        require(receivers.length > 0);

        // shouldnt this be without the +1 ?
        index = index % (receivers.length + 1);
        uint160 amtPerSec = receivers[index].config.amtPerSec();
        uint160 minAmtPerSec = drips.minAmtPerSec();

        assert(amtPerSec >= minAmtPerSec);
    }

    ///@notice Total of internal balances should match token balance of Drips
    function invariantAccountingVsTokenBalance() public {
        uint256 tokenBalance = token.balanceOf(address(drips));
        uint256 dripsBalancesTotal = getDripsBalancesTotalForAllUsers();

        assert(tokenBalance == dripsBalancesTotal);
    }

    ///@notice The sum of all `amtDelta`s for an account should be zero
    function invariantSumAmtDeltaIsZero(uint8 targetAccId) public heavy {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint32 maxEnd = getMaxEndForAllUsers();

        uint32 firstCycle = getCycleFromTimestamp(STARTING_TIMESTAMP);
        uint32 lastCycle = getCycleFromTimestamp(maxEnd);

        require(maxEnd > 0);
        require(firstCycle != lastCycle);

        // limit amount of cycles for gas & memory savings
        require(lastCycle - firstCycle < 1000);

        int256 sumAmtDelta = 0;

        for (uint32 cycle = firstCycle; cycle <= lastCycle; cycle++) {
            (int128 thisCycle, int128 nextCycle) = drips.getAmtDeltaForCycle(
                targetDripsAccId,
                token,
                cycle
            );

            sumAmtDelta += int256(thisCycle);
            sumAmtDelta += int256(nextCycle);
        }

        assert(sumAmtDelta == 0);
    }
}
