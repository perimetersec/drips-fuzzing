// SPDX-License-Identifier: MIT

import "./EchidnaStorage.sol";
import "./Debugger.sol";

/**
 * @title Mixin for handling accounting related functions
 * @author Rappie
 */
contract EchidnaAccounting is EchidnaStorage {
    /**
     * @notice Get the total amount of drips balances for all users
     * @return Total drips balances for all users
     * @dev This is the total amount of drips balances for all users, including
     * the current stream balance, the receivable amount, the collectable
     * amount, the splittable amount, and the squeezable amount.
     */
    function getDripsBalancesTotalForAllUsers() internal returns (uint256) {
        uint256 user0Total = getDripsBalancesTotalForUser(ADDRESS_USER0);
        uint256 user1Total = getDripsBalancesTotalForUser(ADDRESS_USER1);
        uint256 user2Total = getDripsBalancesTotalForUser(ADDRESS_USER2);
        uint256 user3Total = getDripsBalancesTotalForUser(ADDRESS_USER3);

        return user0Total + user1Total + user2Total + user3Total;
    }

    /**
     * @notice Get the total amount of drips balances for a user
     * @param target The user to query
     * @return Total drips balances for the target user
     * @dev This is the total amount of drips balances for a user, including
     * the current stream balance, the receivable amount, the collectable
     * amount, the splittable amount, and the squeezable amount.
     */
    function getDripsBalancesTotalForUser(address target)
        internal
        returns (uint256)
    {
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 balance = getCurrentStreamBalanceForUser(target);
        uint128 squeezable = getTotalSqueezableAmountForUser(target);
        uint128 receivable = getReceivableAmountForUser(target);
        uint128 collectable = drips.collectable(targetDripsAccId, token);
        uint128 splittable = drips.splittable(targetDripsAccId, token);

        return balance + squeezable + receivable + collectable + splittable;
    }

    /**
     * @notice Get the streamable balance for a user
     * @param target The user to query
     * @param timestamp The point in time to get 'balanceAt' from
     * @return Streamable balance for the target user
     * @dev This is the streamable balance for a user, which is the current
     * stream balance minus the receivable amount.
     */
    function getStreamBalanceForUser(address target, uint32 timestamp)
        internal
        returns (uint128)
    {
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 balance;
        try
            drips.balanceAt(
                targetDripsAccId,
                token,
                getStreamReceivers(target),
                timestamp
            )
        returns (uint128 _balance) {
            balance = _balance;
        } catch {
            // this should not happen, so put an assert here to be sure
            Debugger.log("drips.balanceAt() failed");
            assert(false);
        }

        return balance;
    }

    /**
     * @notice Get the current stream balance for a user
     * @param target The user to query
     * @return Current stream balance for the target user
     */
    function getCurrentStreamBalanceForUser(address target)
        internal
        returns (uint128)
    {
        return getStreamBalanceForUser(target, uint32(block.timestamp));
    }

    /**
     * @notice Get the receivable amount for all users
     * @return Receivable amount for all users
     * @dev This is the receivable amount for all users, which means the amount
     * that has already been streamed to the users but not yet collected.
     */
    function getReceivableAmountForAllUsers() internal returns (uint128) {
        uint128 receivable;
        receivable += getReceivableAmountForUser(ADDRESS_USER0);
        receivable += getReceivableAmountForUser(ADDRESS_USER1);
        receivable += getReceivableAmountForUser(ADDRESS_USER2);
        receivable += getReceivableAmountForUser(ADDRESS_USER3);
        return receivable;
    }

    /**
     * @notice Get the receivable amount for a user
     * @param target The user to query
     * @return Receivable amount for the target user
     * @dev This is the receivable amount for a user, which means the amount
     * that has already been streamed to the user but not yet collected.
     */
    function getReceivableAmountForUser(address target)
        internal
        returns (uint128)
    {
        uint128 receivable = drips.receiveStreamsResult(
            getDripsAccountId(target),
            token,
            type(uint32).max
        );
        return receivable;
    }

    /**
     * @notice Get the squeezable amount for all users
     * @param target The user to query
     * @return Squeezable amount for all users
     * @dev This is the squeezable amount for a user, which means the amount
     * that has already been streamed in the current cycle that is not yet
     * receivable.
     */
    function getTotalSqueezableAmountForUser(address target)
        internal
        returns (uint128)
    {
        uint128 amount = 0;
        amount += getSqueezableAmount(ADDRESS_USER0, target);
        amount += getSqueezableAmount(ADDRESS_USER1, target);
        amount += getSqueezableAmount(ADDRESS_USER2, target);
        amount += getSqueezableAmount(ADDRESS_USER3, target);

        return amount;
    }

    /**
     * @notice Get the squeezable amount for a user
     * @param sender The sender of the stream(s)
     * @param receiver The receiver of the stream(s)
     * @return Squeezable amount for the target user
     * @dev This is the squeezable amount for a user, which means the amount
     * that has already been streamed in the current cycle that is not yet
     * receivable.
     */
    function getSqueezableAmount(address sender, address receiver)
        internal
        returns (uint128)
    {
        uint256 senderDripsAccId = getDripsAccountId(sender);
        uint256 receiverDripsAccId = getDripsAccountId(receiver);

        uint128 amount = drips.squeezeStreamsResult(
            receiverDripsAccId,
            token,
            senderDripsAccId,
            bytes32(0),
            getStreamsHistory(sender)
        );

        return amount;
    }

    /**
     * @notice Get the 'maxEnd' farthest in the future for all users
     * @return 'maxEnd' fartherst in the future for all users
     * @dev This is the 'maxEnd' farthest in the future for all users, which
     * means the farthest in the future that any stream ends for any user.
     */
    function getMaxEndForAllUsers() internal returns (uint32) {
        uint32 maxMaxEnd;

        uint32 maxEndUser0 = getMaxEndForUser(ADDRESS_USER0);
        if (maxEndUser0 > maxMaxEnd) maxMaxEnd = maxEndUser0;
        uint32 maxEndUser1 = getMaxEndForUser(ADDRESS_USER1);
        if (maxEndUser1 > maxMaxEnd) maxMaxEnd = maxEndUser1;
        uint32 maxEndUser2 = getMaxEndForUser(ADDRESS_USER2);
        if (maxEndUser2 > maxMaxEnd) maxMaxEnd = maxEndUser2;
        uint32 maxEndUser3 = getMaxEndForUser(ADDRESS_USER3);
        if (maxEndUser3 > maxMaxEnd) maxMaxEnd = maxEndUser3;

        return maxMaxEnd;
    }

    /**
     * @notice Get the 'maxEnd' for a user
     * @param target The user to query
     * @return The 'maxEnd' for the target user
     */
    function getMaxEndForUser(address target) internal returns (uint32) {
        uint256 targetDripsAccId = getDripsAccountId(target);
        (, , , , uint32 maxEnd) = drips.streamsState(targetDripsAccId, token);
        return maxEnd;
    }

    /**
     * @notice Get the timestamp on which the current cycle started
     * @return Timestamp on which the current cycle started
     */
    function getCurrentCycleStart() internal returns (uint32) {
        uint32 currTimestamp = uint32(block.timestamp);
        return currTimestamp - (currTimestamp % SECONDS_PER_CYCLE);
    }

    /**
     * @notice Get the timestamp on which the current cycle ends
     * @return Timestamp on which the current cycle ends
     */
    function getCurrentCycleEnd() internal returns (uint32) {
        return getCurrentCycleStart() + SECONDS_PER_CYCLE - 1;
    }

    /**
     * @notice Get the cycle number for a given timestamp
     * @param timestamp The timestamp to get the cycle number for
     * @return timestamp Cycle number for the given timestamp
     */
    function getCycleFromTimestamp(uint256 timestamp)
        internal
        returns (uint32)
    {
        return uint32(timestamp / SECONDS_PER_CYCLE + 1);
    }
}
