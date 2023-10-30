// SPDX-License-Identifier: MIT

import "./EchidnaTestInvariant.sol";
import "./Debugger.sol";

contract EchidnaTestExperimental is EchidnaTestInvariant {
    function testSqueezableVsReceived(uint8 targetAccId) public {
        require(TOGGLE_EXPERIMENTAL_TESTS_ENABLED);
        address target = getAccount(targetAccId);

        uint128 squeezable = getTotalSqueezableAmountForUser(target);
        uint128 receivableBefore = getReceivableAmountForUser(target);

        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        uint256 currentTimestamp = block.timestamp;
        uint256 futureTimestamp = getCurrentCycleEnd() + 1;

        Debugger.log("currentTimestamp", currentTimestamp);
        Debugger.log("futureTimestamp", futureTimestamp);
        Debugger.log("getCurrentCycleStart()", getCurrentCycleStart());
        Debugger.log("getCurrentCycleEnd()", getCurrentCycleEnd());

        hevm.warp(futureTimestamp);

        uint128 receivableAfter = getReceivableAmountForUser(target);

        receiveStreamsAllCycles(targetAccId);

        assert(receivableAfter >= receivableBefore);
        uint128 receiveableDelta = receivableAfter - receivableBefore;

        Debugger.log("squeezable", squeezable);
        Debugger.log("receivableBefore", receivableBefore);
        Debugger.log("receivableAfter", receivableAfter);
        Debugger.log("receiveableDelta", receiveableDelta);

        assert(squeezable == receiveableDelta);
    }

    function testWithdrawAllTokens() external {
        require(TOGGLE_EXPERIMENTAL_TESTS_ENABLED);

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

        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

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

    function testWithdrawAllTokensShouldNotRevert() public {
        require(TOGGLE_EXPERIMENTAL_TESTS_ENABLED);
        try
            EchidnaTestExperimental(address(this)).testWithdrawAllTokens()
        {} catch {
            assert(false);
        }
    }

    function testExperimentalBalanceAt(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amtPerSecAdded // ) public {
    ) external {
        require(TOGGLE_EXPERIMENTAL_TESTS_ENABLED);

        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);
        uint256 fromDripsAccId = driver.calcAccountId(from);
        uint256 toDripsAccId = driver.calcAccountId(to);

        amtPerSecAdded = clampAmountPerSec(amtPerSecAdded);

        // the timestamps we are comparing
        uint256 currentTimestamp = block.timestamp;
        uint256 futureTimestamp = getCurrentCycleEnd() + 1;

        Debugger.log("currentTimestamp", currentTimestamp);
        Debugger.log("futureTimestamp", futureTimestamp);
        Debugger.log("getCurrentCycleStart()", getCurrentCycleStart());
        Debugger.log("getCurrentCycleEnd()", getCurrentCycleEnd());

        // retrieve initial balances
        uint128 balanceInitial = getStreamBalanceForUser(
            from,
            uint32(block.timestamp)
        );
        uint128 receivableInitial = getReceivableAmountForAllUsers();

        // look at balances in the future if we wouldnt do anything
        hevm.warp(futureTimestamp);
        uint128 balanceBaseline = getStreamBalanceForUser(
            from,
            uint32(block.timestamp)
        );
        uint128 receivableBaseline = getReceivableAmountForAllUsers();
        hevm.warp(currentTimestamp);

        // add a stream
        // make sure we add enough balance to complete the cycle
        uint128 balanceAdded = uint128(amtPerSecAdded) * SECONDS_PER_CYCLE;
        balanceAdded = uint128(clampBalanceDelta(int128(balanceAdded), from));
        require(balanceAdded / amtPerSecAdded >= SECONDS_PER_CYCLE);
        addStream(
            fromAccId,
            toAccId,
            amtPerSecAdded,
            0,
            0,
            int128(balanceAdded)
        );

        Debugger.log("amtPerSecAdded", amtPerSecAdded);
        Debugger.log("balanceAdded", balanceAdded);

        // retrieve balances after adding stream
        uint128 balanceBefore = getStreamBalanceForUser(
            from,
            uint32(block.timestamp)
        );
        uint128 receivableBefore = getReceivableAmountForAllUsers();

        // jump to future
        hevm.warp(futureTimestamp);

        // retrieve balances in the future after adding the stream
        uint128 balanceAfter = getStreamBalanceForUser(
            from,
            uint32(block.timestamp)
        );
        uint128 receivableAfter = getReceivableAmountForAllUsers();

        Debugger.log("balanceInitial", balanceInitial);
        Debugger.log("receivableInitial", receivableInitial);
        Debugger.log("balanceBaseline", balanceBaseline);
        Debugger.log("receivableBaseline", receivableBaseline);
        Debugger.log("balanceBefore", balanceBefore);
        Debugger.log("receivableBefore", receivableBefore);
        Debugger.log("balanceAfter", balanceAfter);
        Debugger.log("receivableAfter", receivableAfter);

        // sanity checks
        assert(balanceInitial >= balanceBaseline);
        assert(balanceBefore >= balanceAfter);
        assert(receivableAfter >= receivableBaseline);

        // the amount that would have been streamed if we do nothing
        uint128 baselineBalanceStreamed = balanceInitial - balanceBaseline;

        // calculate expected balance change including the effect of the
        // added stream
        uint128 expectedBalanceChange = balanceBefore -
            balanceAfter -
            baselineBalanceStreamed;
        uint128 expectedReceivedChange = receivableAfter - receivableBaseline;

        Debugger.log("baselineBalanceStreamed", baselineBalanceStreamed);
        Debugger.log("expectedBalanceChange", expectedBalanceChange);
        Debugger.log("expectedReceivedChange", expectedReceivedChange);

        assert(expectedBalanceChange == expectedReceivedChange);
    }

    // function testExperimentalBalanceAtDoesNotRevert(
    //     uint8 fromAccId,
    //     uint8 toAccId,
    //     uint160 amtPerSecAdded
    // ) public {
    //     try
    //         EchidnaTest(address(this)).testExperimentalBalanceAt(
    //             fromAccId,
    //             toAccId,
    //             amtPerSecAdded
    //         )
    //     {} catch {
    //         assert(false);
    //     }
    // }
}
