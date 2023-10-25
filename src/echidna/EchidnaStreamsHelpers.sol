// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

/**
 * @title Mixin containing helpers for streams
 * @author Rappie <rappie@perimetersec.io>
 */
contract EchidnaStreamsHelpers is EchidnaBase {
    // Internal variables to store maxEndHint1 and maxEndHint2. These are used
    // as hints to the Drips contract to speed up the setStreams call.
    //
    // Instead of fuzzing these directly, we use the `setMaxEndHints` helper
    // function to set these values. This makes fuzzing these toggleable and
    // also makes debugging easier because the values don't have to be passed
    // as arguments to all functions calling `setStreams`.
    //
    uint32 internal maxEndHint1;
    uint32 internal maxEndHint2;

    /**
     * @notice Internal helper function to set streams receivers
     * @param from Account to set streams for
     * @param currReceivers Current stream receivers (Drips needs this)
     * @param balanceDelta Balance delta to set
     * @param unsortedNewReceivers New receivers list to set
     * @return Real balance delta
     * @dev This function also sorts the receivers list
     */
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

    /**
     * @notice Set streams, overwriting the current receivers list
     * @param fromAccId Account id of the sender
     * @param toAccId Account id of the receiver in the receivers list
     * @param amountPerSec Amount per second to stream
     * @param startTime Start time of the stream
     * @param duration Duration of the stream
     * @param balanceDelta Balance delta to set
     * @return Real balance delta
     */
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

    /**
     * @notice Set streams, overwriting the current receivers list
     * @param fromAccId Account id of the sender
     * @param toAccId Account id of the receiver in the receivers list
     * @param amountPerSec Amount per second to stream
     * @param startTime Start time of the stream
     * @param duration Duration of the stream
     * @param balanceDelta Balance delta to set
     * @return Real balance delta
     * @dev This function clamps the amountPerSec, startTime, duration and
     * balanceDelta between the minimum and maximum allowed values
     */
    function setStreamsWithClamping(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) public returns (int128) {
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

    /**
     * @notice Add a stream receiver to the existing list of receivers
     * @param fromAccId Account id of the sender
     * @param toAccId Account id of the receiver to add
     * @param amountPerSec Amount per second to stream
     * @param startTime Start time of the stream
     * @param duration Duration of the stream
     * @param balanceDelta Balance delta to set
     * @return Real balance delta
     */
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

    /**
     * @notice Add a stream receiver to the existing list of receivers
     * @param fromAccId Account id of the sender
     * @param toAccId Account id of the receiver to add
     * @param amountPerSec Amount per second to stream
     * @param startTime Start time of the stream
     * @param duration Duration of the stream
     * @param balanceDelta Balance delta to set
     * @dev This function clamps the amountPerSec, startTime, duration and
     * balanceDelta between the minimum and maximum allowed values
     */
    function addStreamWithClamping(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec,
        uint32 startTime,
        uint32 duration,
        int128 balanceDelta
    ) public returns (int128) {
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

    /**
     * @notice Add a stream receiver to the existing list of receivers, making sure
     * it is immediately squeezable in a transaction after this call
     * @param fromAccId Account id of the sender
     * @param toAccId Account id of the receiver to add
     * @param amountPerSec Amount per second to stream
     * @dev This is meant as a helper to quickly seed the corpus with situations
     * where there is something to squeeze in the next transaction
     */
    function addStreamImmediatelySqueezable(
        uint8 fromAccId,
        uint8 toAccId,
        uint160 amountPerSec
    ) public {
        address receiver = getAccount(toAccId);
        address sender = getAccount(fromAccId);

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
        addStream(fromAccId, toAccId, amountPerSec, 0, 0, balanceDelta);

        // warp 1 second forward so there is something to squeeze
        hevm.warp(block.timestamp + 1);
    }

    /**
     * @notice Remove a stream receiver from the existing list of receivers
     * @param targetAccId Account id of the receiver to remove
     * @param indexSeed Random seed used to determine which receiver to remove
     */
    function removeStream(uint8 targetAccId, uint256 indexSeed) public {
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

    /**
     * @notice Update stream balance by calling `setStreams` with the same
     * receivers list
     * @param targetAccId Account id of the sender
     * @param balanceDelta Balance delta to set
     * @return Real balance delta
     */
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

    /**
     * @notice Update stream balance by calling `setStreams` with the same
     * receivers list
     * @param targetAccId Account id of the sender
     * @param balanceDelta Balance delta to set
     * @dev This function clamps the balanceDelta between the minimum and
     * maximum allowed values
     */
    function setStreamBalanceWithClamping(
        uint8 targetAccId,
        int128 balanceDelta
    ) public {
        address target = getAccount(targetAccId);
        balanceDelta = clampBalanceDelta(balanceDelta, target);
        setStreamBalance(targetAccId, balanceDelta);
    }

    /**
     * @notice Withdraw all stream balance by calling `setStreams` with the same
     * receivers list and using min int128 as balance delta
     * @param targetAccId Account id of the sender
     * @return Real balance delta
     */
    function setStreamBalanceWithdrawAll(uint8 targetAccId)
        public
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

    /**
     * @notice Helper function to update the values used as maxEnd hints
     * @param _maxEndHint1 New value for maxEndHint1
     * @param _maxEndHint2 New value for maxEndHint2
     * @dev Can be toggled on/off with TOGGLE_MAXENDHINTS_ENABLED
     */
    function setMaxEndHints(uint32 _maxEndHint1, uint32 _maxEndHint2) public {
        require(TOGGLE_MAXENDHINTS_ENABLED);
        maxEndHint1 = _maxEndHint1;
        maxEndHint2 = _maxEndHint2;
    }

    /**
     * @notice Clamp the amountPerSec between the minimum and maximum allowed values
     * @param amountPerSec Amount per second to clamp
     * @return Clamped amountPerSec
     */
    function clampAmountPerSec(uint160 amountPerSec)
        internal
        returns (uint160)
    {
        return
            drips.minAmtPerSec() +
            (amountPerSec % (MAX_AMOUNT_PER_SEC - drips.minAmtPerSec() + 1));
    }

    /**
     * @notice Clamp the startTime between the minimum and maximum allowed values
     * @param startTime Start time to clamp
     * @return Clamped startTime
     */
    function clampStartTime(uint32 startTime) internal returns (uint32) {
        if (startTime == 0) return 0;

        // We want to make sure that the start time does not go below 1
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

    /**
     * @notice Clamp the duration between the minimum and maximum allowed values
     * @param duration Duration to clamp
     * @return Clamped duration
     */
    function clampDuration(uint32 duration) internal returns (uint32) {
        if (duration == 0) return 0;

        return duration % (MAX_STREAM_DURATION + 1);
    }

    /**
     * @notice Clamp the balanceDelta between the minimum and maximum allowed values
     * @param balanceDelta Balance delta to clamp
     * @param from Account performing the setStreams action
     * @return Clamped balanceDelta
     */
    function clampBalanceDelta(int128 balanceDelta, address from)
        internal
        returns (int128)
    {
        if (balanceDelta > 0) {
            balanceDelta =
                balanceDelta %
                (int128(uint128(token.balanceOf(from))) + 1);
        } else {
            balanceDelta = balanceDelta % int128(uint128(STARTING_BALANCE));
        }
        return balanceDelta;
    }
}
