// SPDX-License-Identifier: MIT

import "./base/EchidnaBase.sol";

contract EchidnaSplits is EchidnaBase {
    ///@notice Test internal accounting after splitting
    function testSplit(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        uint128 colBalBefore = drips.collectable(targetDripsAccId, token);
        uint128 splitBalBefore = drips.splittable(targetDripsAccId, token);

        (uint128 collectableAmt, uint128 splitAmt) = split(targetAccId);

        uint128 colBalAfter = drips.collectable(targetDripsAccId, token);
        uint128 splitBalAfter = drips.splittable(targetDripsAccId, token);

        // for now we don't care about the split amount because setSplits
        // is not being fuzzed
        assert(splitAmt == 0);

        assert(colBalAfter == colBalBefore + collectableAmt);
        assert(splitBalAfter == splitBalBefore - collectableAmt);

        if (collectableAmt > 0) {
            assert(colBalAfter > colBalBefore);
        } else {
            assert(colBalAfter == colBalBefore);
        }
    }

    ///@notice Splitting should never revert
    function testSplitShouldNotRevert(uint8 targetAccId) public {
        address target = getAccount(targetAccId);
        uint256 targetDripsAccId = getDripsAccountId(target);

        try
            drips.split(targetDripsAccId, token, new SplitsReceiver[](0))
        {} catch {
            assert(false);
        }
    }
}
