// SPDX-License-Identifier: MIT

import "./IHevm.sol";
import "./EchidnaConfig.sol";
import "./Debugger.sol";

contract EchidnaSetup is EchidnaConfig {
    IHevm hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    ERC20PresetFixedSupply token;
    Drips drips;
    AddressDriver driver;

    constructor() EchidnaConfig() {
        // token
        token = new ERC20PresetFixedSupply(
            "Test Token",
            "TEST",
            STARTING_BALANCE * 4,
            address(this)
        );

        // drips
        Drips dripsLogic = new Drips(SECONDS_PER_CYCLE);
        drips = Drips(address(new ManagedProxy(dripsLogic, address(this))));

        // address driver
        uint32 driverId = drips.registerDriver(address(this));
        AddressDriver driverLogic = new AddressDriver(
            drips,
            address(0),
            driverId
        );
        driver = AddressDriver(
            address(new ManagedProxy(driverLogic, address(this)))
        );
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
