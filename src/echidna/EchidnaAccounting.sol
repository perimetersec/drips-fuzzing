// SPDX-License-Identifier: MIT

import "./EchidnaStorage.sol";
import "./Debugger.sol";

contract EchidnaAccounting is EchidnaStorage {
    function getDripsBalancesTotalForAllUsers() internal returns (uint256) {
        uint256 user0Total = getDripsBalancesTotalForUser(ADDRESS_USER0);
        uint256 user1Total = getDripsBalancesTotalForUser(ADDRESS_USER1);
        uint256 user2Total = getDripsBalancesTotalForUser(ADDRESS_USER2);
        uint256 user3Total = getDripsBalancesTotalForUser(ADDRESS_USER3);

        return user0Total + user1Total + user2Total + user3Total;
    }

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

    function getCurrentStreamBalanceForUser(address target)
        internal
        returns (uint128)
    {
        return getStreamBalanceForUser(target, uint32(block.timestamp));
    }

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

    function getReceivableAmountForAllUsers() internal returns (uint128) {
        uint128 receivable;
        receivable += getReceivableAmountForUser(ADDRESS_USER0);
        receivable += getReceivableAmountForUser(ADDRESS_USER1);
        receivable += getReceivableAmountForUser(ADDRESS_USER2);
        receivable += getReceivableAmountForUser(ADDRESS_USER3);
        return receivable;
    }

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

    function getMaxEndForUser(address target) internal returns (uint32) {
        uint256 targetDripsAccId = getDripsAccountId(target);
        (, , , , uint32 maxEnd) = drips.streamsState(targetDripsAccId, token);
        return maxEnd;
    }

    function getCurrentCycleStart() internal returns (uint32) {
        uint32 currTimestamp = uint32(block.timestamp);
        return currTimestamp - (currTimestamp % SECONDS_PER_CYCLE);
    }

    function getCurrentCycleEnd() internal returns (uint32) {
        return getCurrentCycleStart() + SECONDS_PER_CYCLE - 1;
    }

    function getCycleFromTimestamp(uint256 timestamp)
        internal
        returns (uint32 cycle)
    {
        return uint32(timestamp / SECONDS_PER_CYCLE + 1);
    }
}
