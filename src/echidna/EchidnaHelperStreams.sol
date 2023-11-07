// SPDX-License-Identifier: MIT

import "./EchidnaHelper.sol";
import "./Debugger.sol";

contract EchidnaHelperStreams is EchidnaHelper {
    uint32 internal maxEndHint1;
    uint32 internal maxEndHint2;

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
        if (CYCLE_FUZZING_BUFFER_SECONDS > startTime) {
            minStartTime = 1;
        } else {
            minStartTime = uint32(block.timestamp) -
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
