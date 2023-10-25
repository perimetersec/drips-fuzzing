// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaBasicHelpers.sol";

/**
 * @title Mixin containing basic tests
 * @author Rappie <rappie@perimetersec.io>
 */
contract EchidnaBasicTests is EchidnaBase, EchidnaBasicHelpers {
    /**
     * @notice Giving an amount `<=` token balance should never revert
     * @param fromAccId Account id of the giver
     * @param toAccId Account id of the receiver
     * @param amount Amount to give
     */
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

    /**
     * @notice Test internal accounting after receiving streams
     * @param targetAccId Account id of the receiver
     * @param maxCycles Maximum number of cycles to receive
     */
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

    /**
     * @notice Receiving streams should never revert
     * @param targetAccId Account id of the receiver
     */
    function testReceiveStreamsShouldNotRevert(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        try
            drips.receiveStreams(targetDripsAccId, token, type(uint32).max)
        {} catch {
            assert(false);
        }
    }

    /**
     * @notice If there is a receivable amount, there should be at least one
     * receivable cycle
     * @param targetAccId Account id of the receiver
     * @param maxCycles Maximum number of cycles to receive
     */
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

    /**
     * @notice `drips.receiveStreamsResult` should match actual received amount
     * @param targetAccId Account id of the receiver
     * @param maxCycles Maximum number of cycles to receive
     */
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

    /**
     * @notice Test internal accounting after collecting
     * @param fromAccId Account id of the collector
     * @param toAccId Account id of the receiving account
     */
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

    /**
     * @notice Collecting should never revert
     * @param fromAccId Account id of the collector
     * @param toAccId Account id of the receiving account
     */
    function testCollectShouldNotRevert(uint8 fromAccId, uint8 toAccId) public {
        address from = getAccount(fromAccId);
        address to = getAccount(toAccId);

        hevm.prank(from);
        try driver.collect(token, to) {} catch {
            assert(false);
        }
    }
}
