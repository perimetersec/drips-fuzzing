// SPDX-License-Identifier: MIT

import "../tools/IHevm.sol";
import "./EchidnaConfig.sol";

contract EchidnaSetup is EchidnaConfig {
    IHevm hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    ERC20PresetFixedSupply token;
    DripsEchidna drips;
    AddressDriverEchidna driver;

    constructor() EchidnaConfig() {
        // token
        token = new ERC20PresetFixedSupply(
            "Test Token",
            "TEST",
            STARTING_BALANCE * 4,
            address(this)
        );

        // drips
        drips = new DripsEchidna(SECONDS_PER_CYCLE);
        drips.unpause_noModifiers();

        // address driver
        uint32 driverId = drips.registerDriver(address(this));
        driver = new AddressDriverEchidna(
            drips,
            address(0),
            driverId
        );
        driver.unpause_noModifiers();
        drips.updateDriverAddress(driverId, address(driver));

        // set up token balances
        token.transfer(ADDRESS_USER0, STARTING_BALANCE);
        hevm.prank(ADDRESS_USER0);
        token.approve(address(driver), type(uint256).max);
        token.transfer(ADDRESS_USER1, STARTING_BALANCE);
        hevm.prank(ADDRESS_USER1);
        token.approve(address(driver), type(uint256).max);
        token.transfer(ADDRESS_USER2, STARTING_BALANCE);
        hevm.prank(ADDRESS_USER2);
        token.approve(address(driver), type(uint256).max);
        token.transfer(ADDRESS_USER3, STARTING_BALANCE);
        hevm.prank(ADDRESS_USER3);
        token.approve(address(driver), type(uint256).max);

        STARTING_TIMESTAMP = block.timestamp;
    }
}
