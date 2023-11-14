// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaStreamsHelpers.sol";

contract EchidnaStreamsTests is EchidnaBase, EchidnaStreamsHelpers {
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
            EchidnaStreamsHelpers(address(this)).setStreamsWithClamping(
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
            EchidnaStreamsHelpers(address(this)).addStreamWithClamping(
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
            EchidnaStreamsHelpers(address(this)).removeStream(targetAccId, indexSeed)
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
            EchidnaStreamsHelpers(address(this)).setStreamBalanceWithClamping(
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
            EchidnaStreamsHelpers(address(this)).setStreamBalanceWithdrawAll(
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
}
