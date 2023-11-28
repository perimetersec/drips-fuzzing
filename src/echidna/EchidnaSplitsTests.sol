// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";
import "./EchidnaBasicHelpers.sol";
import "./EchidnaSplitsHelpers.sol";

/**
 * @title Mixin containing tests for splitting
 * @author Rappie <rappie@perimetersec.io>
 */
contract EchidnaSplitsTests is
    EchidnaBase,
    EchidnaBasicHelpers,
    EchidnaSplitsHelpers
{
    /**
     * @notice Test internal accounting for splittable amount after splitting
     * @param targetAccId Account id execute split on
     */
    function testSplittableAfterSplit(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 splittableBefore = drips.splittable(targetDripsAccId, token);

        // check if we are splitting to ourselves
        uint32 splitToSelfWeight;
        SplitsReceiver[] memory receivers = getSplitsReceivers(target);
        for (uint256 i = 0; i < receivers.length; i++) {
            if (receivers[i].accountId == targetDripsAccId) {
                splitToSelfWeight += receivers[i].weight;
            }
        }

        // calculate amount to split to self
        uint128 splitToSelfAmount = uint128(
            (splittableBefore * splitToSelfWeight) / drips.TOTAL_SPLITS_WEIGHT()
        );

        (uint128 collectableAmt, uint128 splitAmt) = split(targetAccId);

        uint128 splittableAfter = drips.splittable(targetDripsAccId, token);

        // sanity check
        assert((splitAmt + collectableAmt) <= splittableBefore);

        if (splitToSelfWeight == 0) {
            // if we're not splitting to ourselves, things are simple
            assert(
                splittableAfter == splittableBefore - splitAmt - collectableAmt
            );
        } else {
            // if we ARE splitting to ourselves, there are rounding errors
            // to take into account.

            // calculate expected amount after the split
            uint128 expectedSplittableAfter = splittableBefore -
                splitAmt -
                collectableAmt +
                splitToSelfAmount;

            // calculate difference between expected and actual
            int256 difference = int256(uint256(splittableAfter)) -
                int256(uint256(expectedSplittableAfter));

            // check if difference is within tolerance
            assert(
                difference >= -int256(SPLIT_ROUNDING_TOLERANCE) &&
                    difference <= int256(SPLIT_ROUNDING_TOLERANCE)
            );
        }
    }

    /**
     * @notice Test internal accounting for collectable amount after splitting
     * @param targetAccId Account id execute split on
     */
    function testCollectableAfterSplit(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 colBalBefore = drips.collectable(targetDripsAccId, token);
        (uint128 collectableAmt, ) = split(targetAccId);
        uint128 colBalAfter = drips.collectable(targetDripsAccId, token);

        assert(colBalAfter == colBalBefore + collectableAmt);
    }

    /**
     * @notice After splitting, all receivers should have their splittable
     * amount increased by the amount they were supposed to receive
     * @param targetAccId Account id execute split on
     */
    function testReceiversReceivedSplit(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 amountToBeSplit = drips.splittable(targetDripsAccId, token);
        SplitsReceiver[] memory receivers = getSplitsReceivers(target);

        // storage for all receivers
        uint128[] memory splittableBefore = new uint128[](receivers.length);
        uint128[] memory splittableAfter = new uint128[](receivers.length);
        uint32[] memory weights = new uint32[](receivers.length);
        uint128[] memory amounts = new uint128[](receivers.length);

        for (uint256 i = 0; i < receivers.length; i++) {
            // store splittable before
            splittableBefore[i] = drips.splittable(
                receivers[i].accountId,
                token
            );

            // calculate amount the receiver should get
            weights[i] = receivers[i].weight;
            amounts[i] = uint128(
                (amountToBeSplit * weights[i]) / drips.TOTAL_SPLITS_WEIGHT()
            );
        }

        // split
        (uint128 collectableAmt, uint128 splitAmt) = split(targetAccId);

        // store splittable after
        for (uint256 i = 0; i < receivers.length; i++) {
            splittableAfter[i] = drips.splittable(
                receivers[i].accountId,
                token
            );
        }

        for (uint256 i = 0; i < receivers.length; i++) {
            // calculate expected amount after the split
            uint128 expectedAfter;
            if (receivers[i].accountId != targetDripsAccId) {
                // splitting so someone else is trivial
                expectedAfter = splittableBefore[i] + amounts[i];
            } else {
                // splitting to self needs to take into account that the splittable
                // amount before contains the actual amount that was split to all
                // the receivers. we should end up with only the amount that was
                // split to ourselves
                expectedAfter =
                    splittableBefore[i] -
                    amountToBeSplit +
                    amounts[i];
            }

            // calculate difference between expected and actual
            int256 difference = int256(uint256(splittableAfter[i])) -
                int256(uint256(expectedAfter));

            // check if difference is within tolerance
            assert(
                difference >= -int256(SPLIT_ROUNDING_TOLERANCE) &&
                    difference <= int256(SPLIT_ROUNDING_TOLERANCE)
            );
        }
    }

    /**
     * @notice `drips.splitResult` should match actual split amount
     * @param targetAccId Account id execute split on
     */
    function testSplitViewVsActual(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 splittable = drips.splittable(targetDripsAccId, token);

        (uint128 collectableAmtView, uint128 splitAmtView) = drips.splitResult(
            targetDripsAccId,
            getSplitsReceivers(target),
            splittable
        );

        (uint128 collectableAmtActual, uint128 splitAmtActual) = split(
            targetAccId
        );

        assert(collectableAmtView == collectableAmtActual);
        assert(splitAmtView == splitAmtActual);
    }

    /**
     * @notice Splitting should never revert
     * @param targetAccId Account id execute split on
     */
    function testSplitShouldNotRevert(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        try EchidnaBasicHelpers(address(this)).split(targetAccId) {} catch {
            assert(false);
        }
    }

    /**
     * @notice Setting splits with sane defaults should not revert
     * @param senderAccId Account id of the sender
     * @param receiverAccId Account id of the receiver in the receivers list
     * @param weight Weight of the receiver
     */
    function testSetSplitsShouldNotRevert(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        try
            EchidnaSplitsHelpers(address(this)).setSplitsWithClamping(
                senderAccId,
                receiverAccId,
                weight
            )
        {} catch {
            assert(false);
        }
    }

    /**
     * @notice Adding splits with sane defaults should not revert
     * @param senderAccId Account id of the sender
     * @param receiverAccId Account id of the receiver in the receivers list
     * @param weight Weight of the receiver
     */
    function testAddSplitsShouldNotRevert(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        try
            EchidnaSplitsHelpers(address(this)).addSplitsReceiverWithClamping(
                senderAccId,
                receiverAccId,
                weight
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
}
