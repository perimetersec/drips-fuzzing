// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

/**
 * @title Mixin containing helpers for splitting
 * @author Rappie <rappie@perimetersec.io>
 */
contract EchidnaSplitsHelpers is EchidnaBase {
    /**
     * @notice Internal helper function to set splits receivers
     * @param senderAccId Account id of the sender
     * @param unsortedReceivers Receivers list to set
     * @dev This function also sorts the receivers list
     */
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

    /**
     * @notice Set splits, overwriting the current receivers list
     * @param senderAccId Account id of the sender
     * @param receiverAccId Account id of the receiver in the receivers list
     * @param weight Weight of the receiver
     */
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

    /**
     * @notice Set splits, overwriting the current receivers list
     * @param senderAccId Account id of the sender
     * @param receiverAccId Account id of the receiver in the receivers list
     * @param weight Weight of the receiver
     * @dev This function clamps the weight between the minimum and maximum
     * allowed values
     */
    function setSplitsWithClamping(
        uint8 senderAccId,
        uint8 receiverAccId,
        uint32 weight
    ) public {
        weight = clampSplitWeight(weight, 0); // there are no existing weights
        setSplits(senderAccId, receiverAccId, weight);
    }

    /**
     * @notice Add a splits receiver to the existing list of receivers
     * @param senderAccId Account id of the sender
     * @param receiverAccId Account id of the receiver to add
     * @param weight Weight of the receiver
     */
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

    /**
     * @notice Add a splits receiver to the existing list of receivers
     * @param senderAccId Account id of the sender
     * @param receiverAccId Account id of the receiver to add
     * @param weight Weight of the receiver
     * @dev This function clamps the weight between the minimum and maximum
     * allowed values
     */
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

    /**
     * @notice Remove any existing splits
     * @param targetAccId Target account id
     */
    function removeAllSplits(uint8 targetAccId) public {
        SplitsReceiver[] memory receivers = new SplitsReceiver[](0);
        _setSplits(targetAccId, receivers);
    }

    /**
     * @notice Clamp the weight between the minimum and maximum allowed values
     * @param weight Weight to clamp
     * @param existingWeights Sum of all the existing weights
     * @return Clamped weight
     */
    function clampSplitWeight(uint32 weight, uint32 existingWeights)
        public
        view
        returns (uint32)
    {
        return (weight % (drips.TOTAL_SPLITS_WEIGHT() - existingWeights)) + 1;
    }
}
