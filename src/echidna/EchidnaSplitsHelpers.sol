// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

contract EchidnaSplitsHelpers is EchidnaBase {
    function _setSplits(
        uint8 senderAccId,
        SplitsReceiver[] memory unsortedReceivers
    ) internal {
        address sender = getAccount(senderAccId);

        SplitsReceiver[] memory newReceivers = bubbleSortSplitsReceivers(
            unsortedReceivers
        );

        updateSplitsReceivers(sender, newReceivers);

        hevm.prank(sender);
        driver.setSplits(newReceivers);
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

        _setSplits(senderAccId, receivers);
    }

    function setSplitsWithClamping(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        weight = clampSplitWeight(weight, 0); // 0 existing weights
        setSplits(senderAccId, receiverAccId, weight);
    }

    function addSplitsReceiver(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        address sender = getAccount(senderAccId);
        address receiver = getAccount(receiverAccId);
        uint256 senderDripsAccId = getDripsAccountId(sender);
        uint256 receiverDripsAccId = getDripsAccountId(receiver);

        SplitsReceiver[] memory oldReceivers = getSplitsReceivers(sender);

        SplitsReceiver memory addedReceiver = SplitsReceiver({
            accountId: receiverDripsAccId,
            weight: weight
        });

        SplitsReceiver[] memory newReceivers = new SplitsReceiver[](
            oldReceivers.length + 1
        );
        for (uint256 i = 0; i < oldReceivers.length; i++) {
            newReceivers[i] = oldReceivers[i];
        }
        newReceivers[newReceivers.length - 1] = addedReceiver;

        _setSplits(senderAccId, newReceivers);
    }

    function addSplitsReceiverWithClamping(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        address sender = getAccount(senderAccId);

        // sum all the existing weights
        uint32 existingWeights;
        SplitsReceiver[] memory receivers = getSplitsReceivers(sender);
        for (uint256 i = 0; i < receivers.length; i++) {
            existingWeights += receivers[i].weight;
        }

        // we can't add a receiver if it makes the total weight go over the
        // maximum allowed
        if (existingWeights >= drips.TOTAL_SPLITS_WEIGHT()) return;

        weight = clampSplitWeight(weight, existingWeights);

        addSplitsReceiver(senderAccId, receiverAccId, weight);
    }

    function removeAllSplits(uint8 targetAccId) public {
        SplitsReceiver[] memory receivers = new SplitsReceiver[](0);
        _setSplits(targetAccId, receivers);
    }

    function clampSplitWeight(uint32 weight, uint32 existingWeights)
        public
        view
        returns (uint32)
    {
        uint32 min = 1;
        uint32 max = drips.TOTAL_SPLITS_WEIGHT();
        return min + (weight % ((max + 1) - existingWeights - min));
    }
}
