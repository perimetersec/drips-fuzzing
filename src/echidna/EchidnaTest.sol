// SPDX-License-Identifier: MIT

import "./EchidnaDebug.sol";
import "./Debugger.sol";

contract EchidnaTest is EchidnaDebug {
    ///@notice Giving an amount `<=` token balance should never revert
    function testGiveShouldNotRevert(
        uint8 fromAccId,
        uint8 toAccId,
        uint128 amount
    ) public {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        uint256 toDripsAccId = getDripsAccountId(to);

        require(amount <= token.balanceOf(from));

        hevm.prank(from);
        try driver.give(toDripsAccId, token, amount) {} catch {
            assert(false);
        }
    }

    ///@notice Test internal accounting after squeezing
    function testSqueeze(uint8 receiverAccId, uint8 senderAccId) public {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint256 receiverDripsAccId = getDripsAccountId(receiver);

        uint128 squeezableBefore = getSqueezableAmount(sender, receiver);
        uint128 splittableBefore = drips.splittable(receiverDripsAccId, token);

        uint128 squeezedAmt = _squeeze(receiverAccId, senderAccId);

        uint128 squeezableAfter = getSqueezableAmount(sender, receiver);
        uint128 splittableAfter = drips.splittable(receiverDripsAccId, token);

        assert(squeezableAfter == squeezableBefore - squeezedAmt);
        assert(splittableAfter == splittableBefore + squeezedAmt);

        if (squeezedAmt > 0) {
            assert(squeezableAfter < squeezableBefore);
            assert(splittableAfter > splittableBefore);
        } else {
            assert(squeezableAfter == squeezableBefore);
            assert(splittableAfter == splittableBefore);
        }
    }

    ///@notice `drips.squeezeStreamsResult` should match actual squeezed amount
    function testSqueezeViewVsActual(uint8 receiverAccId, uint8 senderAccId)
        public
    {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        uint256 receiverDripsAccId = getDripsAccountId(receiver);

        uint128 squeezable = getSqueezableAmount(sender, receiver);
        uint128 squeezed = _squeeze(receiverAccId, senderAccId);

        assert(squeezable == squeezed);
    }

    ///@notice Squeezing should never revert
    function testSqueezeShouldNotRevert(uint8 receiverAccId, uint8 senderAccId)
        public
    {
        try
            EchidnaHelper(address(this)).squeeze(receiverAccId, senderAccId)
        {} catch {
            assert(false);
        }
    }

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

    ///@notice Receiving streams should never revert
    function testReceiveStreamsShouldNotRevert(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        try
            drips.receiveStreams(targetDripsAccId, token, type(uint32).max)
        {} catch {
            assert(false);
        }
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

    ///@notice Splitting should never revert
    function testSplitShouldNotRevert(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        try
            drips.split(targetDripsAccId, token, new SplitsReceiver[](0))
        {} catch {
            assert(false);
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

    ///@notice Collecting should never revert
    function testCollectShouldNotRevert(uint8 fromAccId, uint8 toAccId) public {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        hevm.prank(from);
        try driver.collect(token, to) {} catch {
            assert(false);
        }
    }

    ///@notice Setting streams with sane defaults should not revert
    function testSetStreamsShouldNotRevert(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) public {
        try
            EchidnaHelperStreams(address(this)).setStreamsWithClamping(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            )
        returns (int128 realBalanceDelta) {} catch {
            assert(false);
        }
    }

    ///@notice Adding streams with sane defaults should not revert
    function testAddStreamShouldNotRevert(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) public {
        try
            EchidnaHelperStreams(address(this)).addStreamWithClamping(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            )
        returns (int128 realBalanceDelta) {} catch (bytes memory reason) {
            bytes4 errorSelector = bytes4(keccak256(bytes("DuplicateError()")));
            if (errorSelector == EchidnaStorage.DuplicateError.selector) {
                // ignore this case, it means we tried to add a duplicate stream
            } else {
                assert(false);
            }
        }
    }

    ///@notice Removing streams should not revert
    function testRemoveStreamShouldNotRevert(
        uint8 targetAccId,
        uint256 indexSeed
    ) public {
        address target = getAccount(targetAccId);
        require(getStreamReceivers(target).length > 0);

        try
            EchidnaHelperStreams(address(this)).removeStream(
                targetAccId,
                indexSeed
            )
        {} catch {
            assert(false);
        }
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

    ///@notice Updating stream balance with sane defaults should not revert
    function testSetStreamBalanceShouldNotRevert(
        uint8 targetAccId,
        int128 balanceDelta
    ) public {
        try
            EchidnaHelperStreams(address(this)).setStreamBalanceWithClamping(
                targetAccId,
                balanceDelta
            )
        {} catch {
            assert(false);
        }
    }

    ///@notice Withdrawing all stream balance should not revert
    function testSetStreamBalanceWithdrawAllShouldNotRevert(uint8 targetAccId)
        public
    {
        try
            EchidnaHelperStreams(address(this)).setStreamBalanceWithdrawAll(
                targetAccId
            )
        {} catch {
            assert(false);
        }
    }

    function testSqueezableVsReceived(uint8 targetAccId) public heavy {
        address target = getAccount(targetAccId);

        uint128 squeezable = getTotalSqueezableAmountForUser(target);
        uint128 receivableBefore = getReceivableAmountForUser(target);

        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER0]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER1]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER2]);
        _setStreamBalanceWithdrawAll(ADDRESS_TO_ACCOUNT_ID[ADDRESS_USER3]);

        uint256 currentTimestamp = block.timestamp;
        uint256 futureTimestamp = getCurrentCycleEnd() + 1;

        hevm.warp(futureTimestamp);

        uint128 receivableAfter = getReceivableAmountForUser(target);

        receiveStreamsAllCycles(targetAccId);

        assert(receivableAfter >= receivableBefore);
        uint128 receiveableDelta = receivableAfter - receivableBefore;

        assert(squeezable == receiveableDelta);
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

    function testWithdrawAllTokensShouldNotRevert() public heavy {
        try
            EchidnaTest(address(this)).testWithdrawAllTokens()
        {} catch {
            assert(false);
        }
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
