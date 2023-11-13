// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

contract EchidnaSplits is EchidnaBase {
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

        (uint128 collectableAmt, uint128 splitAmt) = _split(targetAccId);

        uint128 splittableAfter = drips.splittable(targetDripsAccId, token);

        Debugger.log("splitToSelfWeight", splitToSelfWeight);
        Debugger.log("splitToSelfAmount", splitToSelfAmount);
        Debugger.log("collectableAmt", collectableAmt);
        Debugger.log("splitAmt", splitAmt);
        Debugger.log("splittableBefore", splittableBefore);
        Debugger.log("splittableAfter", splittableAfter);

        // sanity check
        assert((splitAmt + collectableAmt) <= splittableBefore);

        if (splitToSelfAmount > 0) {
            // this is expected to fail due to rounding errors once we're able to
            // fuzz lists of multiple splitreceivers
            assert(
                splittableAfter ==
                    splittableBefore -
                        splitAmt -
                        collectableAmt +
                        splitToSelfAmount
            );
        } else {
            assert(
                splittableAfter == splittableBefore - splitAmt - collectableAmt
            );
        }
    }

    function testCollectableAfterSplit(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 colBalBefore = drips.collectable(targetDripsAccId, token);
        (uint128 collectableAmt, ) = _split(targetAccId);
        uint128 colBalAfter = drips.collectable(targetDripsAccId, token);

        assert(colBalAfter == colBalBefore + collectableAmt);
    }

    ///@notice Splitting should never revert
    function testSplitShouldNotRevert(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        try EchidnaBase(address(this)).split(targetAccId) {} catch {
            assert(false);
        }
    }

    function testSetSplitsShouldNotRevert(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        try
            EchidnaSplits(address(this)).setSplitsWithClamping(
                senderAccId,
                receiverAccId,
                weight
            )
        {} catch {
            assert(false);
        }
    }

    function setSplits(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        address sender = getAccount(senderAccId);
        address receiver = getAccount(receiverAccId);
        uint256 receiverDripsAccId = getDripsAccountId(receiver);

        SplitsReceiver[] memory receivers = new SplitsReceiver[](1);
        receivers[0] = SplitsReceiver({
            accountId: receiverDripsAccId,
            weight: weight
        });
        updateSplitsReceivers(sender, receivers);

        hevm.prank(sender);
        driver.setSplits(receivers);
    }

    function setSplitsWithClamping(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        weight = 1 + (weight % (drips.TOTAL_SPLITS_WEIGHT() - 1));
        setSplits(senderAccId, receiverAccId, weight);
    }
}
