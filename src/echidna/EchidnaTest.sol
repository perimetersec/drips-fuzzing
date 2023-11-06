// SPDX-License-Identifier: MIT

import "./EchidnaDebug.sol";
import "./Debugger.sol";

contract EchidnaTest is EchidnaDebug {
    ///@notice Test internal accounting after receiving streams
    function testReceiveStreams(uint8 targetAccId, uint32 maxCycles) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 splittableBefore = drips.splittable(targetDripsAccId, token);
        uint128 receivedAmt = receiveStreams(targetAccId, maxCycles);
        uint128 splittableAfter = drips.splittable(targetDripsAccId, token);

        assert(splittableAfter == splittableBefore + receivedAmt);

        if (receivedAmt > 0) {
            assert(splittableAfter > splittableBefore);
        } else {
            assert(splittableAfter == splittableBefore);
        }
    }

    ///@notice If there is a receivable amount, there should be at least one
    ///receivable cycle
    function testReceiveStreamsViewConsistency(
        uint8 targetAccId,
        uint32 maxCycles
    ) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        require(maxCycles > 0);

        uint128 receivable = drips.receiveStreamsResult(
            targetDripsAccId,
            token,
            maxCycles
        );
        uint32 receivableCycles = drips.receivableStreamsCycles(
            targetDripsAccId,
            token
        );

        if (receivable > 0) assert(receivableCycles > 0);

        // this does not hold because you can have cycles with 0 amount receivable
        // if (receivableCycles > 0) assert(receivable > 0);
    }

    ///@notice `drips.receiveStreamsResult` should match actual received amount
    function testReceiveStreamsViewVsActual(uint8 targetAccId, uint32 maxCycles)
        public
    {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 receivable = drips.receiveStreamsResult(
            targetDripsAccId,
            token,
            maxCycles
        );

        uint128 received = drips.receiveStreams(
            targetDripsAccId,
            token,
            maxCycles
        );

        assert(receivable == received);
    }

    ///@notice Test internal accounting after splitting
    function testSplit(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 colBalBefore = drips.collectable(targetDripsAccId, token);
        uint128 splitBalBefore = drips.splittable(targetDripsAccId, token);

        (uint128 collectableAmt, uint128 splitAmt) = split(targetAccId);

        uint128 colBalAfter = drips.collectable(targetDripsAccId, token);
        uint128 splitBalAfter = drips.splittable(targetDripsAccId, token);

        // for now we don't care about the split amount because setSplits
        // is not being fuzzed
        assert(splitAmt == 0);

        assert(colBalAfter == colBalBefore + collectableAmt);
        assert(splitBalAfter == splitBalBefore - collectableAmt);

        if (collectableAmt > 0) {
            assert(colBalAfter > colBalBefore);
        } else {
            assert(colBalAfter == colBalBefore);
        }
    }

    ///@notice Test internal accounting after collecting
    function testCollect(uint8 fromAccId, uint8 toAccId) public {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        uint256 fromDripsAccId = getDripsAccountId(from);

        uint128 colBalBefore = drips.collectable(fromDripsAccId, token);
        uint256 tokenBalBefore = token.balanceOf(to);

        uint128 collected = collect(fromAccId, toAccId);

        uint128 colBalAfter = drips.collectable(fromDripsAccId, token);
        uint256 tokenBalAfter = token.balanceOf(to);

        assert(colBalAfter == colBalBefore - collected);
        assert(tokenBalAfter == tokenBalBefore + collected);
    }

    ///@notice Test internal accounting after updating stream balance
    function testSetStreamBalance(uint8 targetAccId, int128 balanceDelta)
        public
    {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint256 tokenBalanceBefore = token.balanceOf(target);
        uint128 streamBalanceBefore = drips.balanceAt(
            targetDripsAccId,
            token,
            getStreamReceivers(target),
            uint32(block.timestamp)
        );

        int128 realBalanceDelta = setStreamBalance(targetAccId, balanceDelta);

        uint256 tokenBalanceAfter = token.balanceOf(target);
        uint128 streamBalanceAfter = drips.balanceAt(
            targetDripsAccId,
            token,
            getStreamReceivers(target),
            uint32(block.timestamp)
        );

        if (balanceDelta >= 0) {
            assert(realBalanceDelta == balanceDelta);
        } else {
            assert(realBalanceDelta <= 0);
            assert(realBalanceDelta >= balanceDelta);
        }

        assert(
            int256(tokenBalanceAfter) ==
                int256(tokenBalanceBefore) - realBalanceDelta
        );
        assert(
            int128(streamBalanceAfter) ==
                int128(streamBalanceBefore) + realBalanceDelta
        );
    }

    function testWithdrawAllTokens() external heavy {
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

    function testBalanceAtInFuture(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amtPerSecAdded
    ) public heavy {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);
        uint256 fromDripsAccId = getDripsAccountId(from);
        uint256 toDripsAccId = getDripsAccountId(to);

        amtPerSecAdded = clampAmountPerSec(amtPerSecAdded);

        // the timestamps we are comparing
        uint256 currentTimestamp = block.timestamp;
        uint256 futureTimestamp = getCurrentCycleEnd() + 1;

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

        assert(expectedBalanceChange == expectedReceivedChange);
    }
}
