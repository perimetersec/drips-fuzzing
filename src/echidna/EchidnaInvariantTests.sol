// SPDX-License-Identifier: MIT

import "./EchidnaBasicHelpers.sol";
import "./EchidnaSplitsHelpers.sol";
import "./EchidnaStreamsHelpers.sol";
import "./EchidnaSqueezeHelpers.sol";

/**
 * @title Mixin containing invariant tests
 * @author Rappie <rappie@perimetersec.io>
 */
contract EchidnaInvariantTests is
    EchidnaBasicHelpers,
    EchidnaSplitsHelpers,
    EchidnaStreamsHelpers,
    EchidnaSqueezeHelpers
{
    /**
     * @notice Withdrawing any amount directly from Drips should fail
     * @param amount Amount to withdraw
     */
    function invariantWithdrawShouldAlwaysFail(uint256 amount) public {
        require(amount > 0, "withdraw amount must be > 0");

        try drips.withdraw(token, address(this), amount) {
            assert(false);
        } catch {}
    }

    /**
     * @notice `amtPerSec` should never be lower than `drips.minAmtPerSec()`
     * @param targetAccId Account id of the receiver
     * @param index Index of the receiver
     */
    function invariantAmtPerSecVsMinAmtPerSec(uint8 targetAccId, uint256 index)
        public
    {
        address target = getAccount(targetAccId);

        StreamReceiver[] memory receivers = getStreamReceivers(target);
        require(receivers.length > 0, "no receivers");

        index = index % receivers.length;
        uint160 amtPerSec = receivers[index].config.amtPerSec();

        assert(amtPerSec >= drips.minAmtPerSec());
    }

    /**
     * @notice The total of all internal balances should match token balance
     * of the Drips contract
     */
    function invariantAccountingVsTokenBalance() public {
        uint256 tokenBalance = token.balanceOf(address(drips));
        uint256 dripsBalancesTotal = getDripsBalancesTotalForAllUsers();

        assert(tokenBalance == dripsBalancesTotal);
    }

    /**
     * @notice Check internal and external balances after withdrawing all funds
     * from the system
     */
    function invariantWithdrawAllTokens() external heavy {
        // remove all splits to prevent tokens from getting stuck in case
        // there are splits to self
        removeAllSplits(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        removeAllSplits(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        removeAllSplits(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        removeAllSplits(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        squeezeAllSenders(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        squeezeAllSenders(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        squeezeAllSenders(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        squeezeAllSenders(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        receiveStreamsSplitAndCollectToSelf(
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]
        );
        receiveStreamsSplitAndCollectToSelf(
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]
        );
        receiveStreamsSplitAndCollectToSelf(
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]
        );
        receiveStreamsSplitAndCollectToSelf(
            ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]
        );

        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        uint256 dripsBalance = token.balanceOf(address(drips));
        uint256 user0Balance = token.balanceOf(ADDRESS_USER0);
        uint256 user1Balance = token.balanceOf(ADDRESS_USER1);
        uint256 user2Balance = token.balanceOf(ADDRESS_USER2);
        uint256 user3Balance = token.balanceOf(ADDRESS_USER3);

        uint256 totalUserBalance = user0Balance +
            user1Balance +
            user2Balance +
            user3Balance;

        assert(dripsBalance == 0);
        assert(totalUserBalance == STARTING_BALANCE * 4);
    }

    /**
     * @notice Withdrawing all funds from the system should never revert
     */
    function invariantWithdrawAllTokensShouldNotRevert() public heavy {
        try
            EchidnaInvariantTests(address(this)).invariantWithdrawAllTokens()
        {} catch {
            assert(false);
        }
    }

    /**
     * @notice The sum of all `amtDelta`s for an account should be zero
     * @param targetAccId Target account to perform the test on
     */
    function invariantSumAmtDeltaIsZero(uint8 targetAccId) public heavy {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint32 maxEnd = getMaxEndForAllUsers();

        uint32 firstCycle = getCycleFromTimestamp(STARTING_TIMESTAMP);
        uint32 lastCycle = getCycleFromTimestamp(maxEnd);

        require(maxEnd > 0, "no cycles");
        require(firstCycle != lastCycle, "only one cycle");

        // limit amount of cycles for gas & memory savings
        require(lastCycle - firstCycle < 1000, "too many cycles");

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
