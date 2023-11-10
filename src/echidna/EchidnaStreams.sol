// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

contract EchidnaStreams is EchidnaBase {
    uint32 internal maxEndHint1;
    uint32 internal maxEndHint2;

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
            EchidnaStreams(address(this)).setStreamsWithClamping(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            )
        {} catch {
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
            EchidnaStreams(address(this)).addStreamWithClamping(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            )
        {} catch (bytes memory reason) {
            bytes4 errorSelector = bytes4(reason);
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
            EchidnaStreams(address(this)).removeStream(targetAccId, indexSeed)
        {} catch {
            assert(false);
        }
    }

    ///@notice Updating stream balance with sane defaults should not revert
    function testSetStreamBalanceShouldNotRevert(
        uint8 targetAccId,
        int128 balanceDelta
    ) public {
        try
            EchidnaStreams(address(this)).setStreamBalanceWithClamping(
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
            EchidnaStreams(address(this)).setStreamBalanceWithdrawAll(
                targetAccId
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

    function setMaxEndHints(uint32 _maxEndHint1, uint32 _maxEndHint2) public {
        require(TOGGLE_MAXENDHINTS_ENABLED);
        maxEndHint1 = _maxEndHint1;
        maxEndHint2 = _maxEndHint2;
    }

    function _setStreams(
        address from,
        StreamReceiver[] memory currReceivers,
        int128 balanceDelta,
        StreamReceiver[] memory unsortedNewReceivers
    ) internal returns (int128) {
        StreamReceiver[] memory newReceivers = bubbleSortStreamReceivers(
            unsortedNewReceivers
        );

        hevm.prank(from);
        int128 realBalanceDelta = driver.setStreams(
            token,
            currReceivers,
            balanceDelta,
            newReceivers,
            maxEndHint1,
            maxEndHint2,
            from
        );

        updateStreamReceivers(from, newReceivers);

        return realBalanceDelta;
    }

    function setStreams(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) public returns (int128) {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        StreamReceiver[] memory receivers = new StreamReceiver[](1);
        receivers[0] = StreamReceiver(
            getDripsAccountId(to),
            StreamConfigImpl.create(
                0, // streamId is arbitrary and can be ignored
                amountPerSec,
                startTime,
                duration
            )
        );

        int128 realBalanceDelta = _setStreams(
            from,
            getStreamReceivers(from),
            balanceDelta,
            receivers
        );

        return realBalanceDelta;
    }

    function _setStreamsWithClamping(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) internal returns (int128) {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        amountPerSec = clampAmountPerSec(amountPerSec);
        startTime = clampStartTime(startTime);
        duration = clampDuration(duration);
        balanceDelta = clampBalanceDelta(balanceDelta, from);

        setStreams(
            fromAccId,
            toAccId,
            amountPerSec,
            startTime,
            duration,
            balanceDelta
        );
    }

    function setStreamsWithClamping(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) external returns (int128) {
        return
            _setStreamsWithClamping(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            );
    }

    function addStream(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) public returns (int128) {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        StreamReceiver[] memory oldReceivers = getStreamReceivers(from);

        StreamReceiver memory addedReceiver = StreamReceiver(
            getDripsAccountId(to),
            StreamConfigImpl.create(
                0, // streamId is arbitrary and can be ignored
                amountPerSec,
                startTime,
                duration
            )
        );

        StreamReceiver[] memory newReceivers = new StreamReceiver[](
            oldReceivers.length + 1
        );
        for (uint256 i = 0; i < oldReceivers.length; i++) {
            newReceivers[i] = oldReceivers[i];
        }
        newReceivers[newReceivers.length - 1] = addedReceiver;

        int128 realBalanceDelta = _setStreams(
            from,
            oldReceivers,
            balanceDelta,
            newReceivers
        );

        return realBalanceDelta;
    }

    function _addStreamWithClamping(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) internal returns (int128) {
        address from = getAccount(fromAccId);

        amountPerSec = clampAmountPerSec(amountPerSec);
        startTime = clampStartTime(startTime);
        duration = clampDuration(duration);
        balanceDelta = clampBalanceDelta(balanceDelta, from);

        return
            addStream(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            );
    }

    function addStreamWithClamping(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) external returns (int128) {
        return
            _addStreamWithClamping(
                fromAccId,
                toAccId,
                amountPerSec,
                startTime,
                duration,
                balanceDelta
            );
    }

    function addStreamImmediatelySqueezable(
        uint8 receiverAccId,
        uint8 senderAccId,
        uint160 amountPerSec
    ) public {
        address receiver = getAccount(receiverAccId);
        address sender = getAccount(senderAccId);

        // calculate amount per second so there will be something to squeeze
        // this cycle
        uint160 minAmtPerSec = drips.minAmtPerSec() * SECONDS_PER_CYCLE;
        amountPerSec =
            minAmtPerSec +
            (amountPerSec % (MAX_AMOUNT_PER_SEC - minAmtPerSec + 1));

        // deposit 100 times the amount of 'amountPerSec' so chances are high
        // that there is enough balance to stream this cycle
        int128 balanceDelta = (int128(uint128(amountPerSec)) * 100) / 1e9;
        if (uint128(balanceDelta) > token.balanceOf(sender)) {
            balanceDelta = int128(uint128(token.balanceOf(sender)));
        }

        // add the stream
        addStream(senderAccId, receiverAccId, amountPerSec, 0, 0, balanceDelta);

        // warp 1 second forward so there is something to squeeze
        hevm.warp(block.timestamp + 1);
    }

    function _removeStream(uint8 targetAccId, uint256 indexSeed) internal {
        address target = getAccount(targetAccId);

        StreamReceiver[] memory oldReceivers = getStreamReceivers(target);

        uint256 index = indexSeed % oldReceivers.length;

        StreamReceiver[] memory newReceivers = new StreamReceiver[](
            oldReceivers.length - 1
        );
        uint256 j = 0;
        for (uint256 i = 0; i < oldReceivers.length; i++) {
            if (i != index) {
                newReceivers[j] = oldReceivers[i];
                j++;
            }
        }

        _setStreams(target, oldReceivers, 0, newReceivers);
    }

    function removeStream(uint8 targetAccId, uint256 indexSeed) external {
        _removeStream(targetAccId, indexSeed);
    }

    function setStreamBalance(uint8 targetAccId, int128 balanceDelta)
        public
        returns (int128)
    {
        address target = getAccount(targetAccId);

        int128 realBalanceDelta = _setStreams(
            target,
            getStreamReceivers(target),
            balanceDelta,
            getStreamReceivers(target)
        );

        return realBalanceDelta;
    }

    function _setStreamBalanceWithClamping(
        uint8 targetAccId,
        int128 balanceDelta
    ) internal {
        address target = getAccount(targetAccId);
        balanceDelta = clampBalanceDelta(balanceDelta, target);
        setStreamBalance(targetAccId, balanceDelta);
    }

    function setStreamBalanceWithClamping(
        uint8 targetAccId,
        int128 balanceDelta
    ) external {
        _setStreamBalanceWithClamping(targetAccId, balanceDelta);
    }

    function _setStreamBalanceWithdrawAll(uint8 targetAccId)
        internal
        returns (int128)
    {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        int128 realBalanceDelta = _setStreams(
            target,
            getStreamReceivers(target),
            type(int128).min,
            getStreamReceivers(target)
        );
    }

    function setStreamBalanceWithdrawAll(uint8 targetAccId)
        external
        returns (int128)
    {
        return _setStreamBalanceWithdrawAll(targetAccId);
    }

    function clampAmountPerSec(uint160 amountPerSec)
        internal
        returns (uint160)
    {
        return
            drips.minAmtPerSec() +
            (amountPerSec % (MAX_AMOUNT_PER_SEC - drips.minAmtPerSec() + 1));
    }

    function clampStartTime(uint32 startTime) internal returns (uint32) {
        if (startTime == 0) return 0;

        uint32 minStartTime;
        if (CYCLE_FUZZING_BUFFER_SECONDS >= block.timestamp) {
            minStartTime = 1;
        } else {
            minStartTime =
                uint32(block.timestamp) -
                CYCLE_FUZZING_BUFFER_SECONDS;
        }
        uint32 maxStartTime = uint32(block.timestamp) +
            CYCLE_FUZZING_BUFFER_SECONDS;
        return minStartTime + (startTime % (maxStartTime - minStartTime + 1));
    }

    function clampDuration(uint32 duration) internal returns (uint32) {
        if (duration == 0) return 0;

        return duration % (MAX_STREAM_DURATION + 1);
    }

    function clampBalanceDelta(int128 balanceDelta, address from)
        internal
        returns (int128)
    {
        if (balanceDelta > 0) {
            balanceDelta =
                balanceDelta %
                (int128(uint128(token.balanceOf(from))) + 1);
        } else {
            // TODO: this should be modulo the balance inside Drips
            balanceDelta = balanceDelta % int128(uint128(STARTING_BALANCE));
        }
        return balanceDelta;
    }
}
