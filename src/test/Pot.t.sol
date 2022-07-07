// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "dss-test/DSSTest.sol";

import {Vat} from '../Vat.sol';
import {Pot} from '../Pot.sol';

contract PotTest is DSSTest {

    Vat vat;
    Pot pot;

    event Cage();
    event Drip();
    event Join(address indexed usr, uint256 wad);
    event Exit(address indexed usr, uint256 wad);

    function postSetup() internal virtual override {
        vat = new Vat();
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        pot = new Pot(address(vat));
        vat.rely(address(pot));

        pot.file("vow", TEST_ADDRESS);

        vat.suck(address(this), address(this), 100 * RAD);
        vat.hope(address(pot));
    }

    function testConstructor() public {
        assertEq(address(pot.vat()), address(vat));
        assertEq(pot.wards(address(this)), 1);
        assertEq(pot.dsr(), RAY);
        assertEq(pot.chi(), RAY);
        assertEq(pot.rho(), block.timestamp);
        assertEq(pot.live(), 1);
    }

    function testAuth() public {
        checkAuth(address(pot), "Pot");
    }

    function testFile() public {
        checkFileUint(address(pot), "Pot", ["dsr"]);
        checkFileAddress(address(pot), "Pot", ["vow"]);
    }

    function testFileNotLive() public {
        pot.cage();

        vm.expectRevert("Pot/not-live");
        pot.file("dsr", 1);
    }

    function testFileRhoNotUpdated() public {
        vm.warp(block.timestamp + 1);

        vm.expectRevert("Pot/rho-not-updated");
        pot.file("dsr", 1);
    }

    function testCage() public {
        pot.file("dsr", 123);

        assertEq(pot.live(), 1);
        assertEq(pot.dsr(), 123);

        vm.expectEmit(true, true, true, true);
        emit Cage();
        pot.cage();

        assertEq(pot.live(), 0);
        assertEq(pot.dsr(), RAY);
    }

    function testDrip() public {
        pot.join(100 * WAD);
        pot.file("dsr", 1000000564701133626865910626);  // 5% / day

        assertEq(pot.chi(), RAY);
        assertEq(pot.rho(), block.timestamp);
        assertEq(vat.sin(TEST_ADDRESS), 0);
        assertEq(vat.dai(address(pot)), 100 * RAD);

        vm.warp(block.timestamp + 1 days);

        vm.expectEmit(true, true, true, true);
        emit Drip();
        uint256 chi_ = pot.drip();

        assertEq(pot.chi(), 1050000000000000000000016038);
        assertEq(pot.chi(), chi_);
        assertEq(pot.rho(), block.timestamp);
        assertEq(vat.sin(TEST_ADDRESS), 5000000000000000000001603800000000000000000000);
        assertEq(vat.dai(address(pot)), 105000000000000000000001603800000000000000000000);
    }

    function testJoin() public {
        assertEq(vat.dai(address(this)), 100 * RAD);
        assertEq(pot.pie(address(this)), 0);
        assertEq(pot.Pie(), 0);

        vm.expectEmit(true, true, true, true);
        emit Join(address(this), 100 * WAD);
        pot.join(100 * WAD);

        assertEq(vat.dai(address(this)), 0);
        assertEq(pot.pie(address(this)), 100 * WAD);
        assertEq(pot.Pie(), 100 * WAD);
    }

    function testJoinRhoNotUpdated() public {
        vm.warp(block.timestamp + 1);
        vm.expectRevert("Pot/rho-not-updated");
        pot.join(100 * WAD);
    }

    function testExit() public {
        pot.join(100 * WAD);

        assertEq(vat.dai(address(this)), 0);
        assertEq(pot.pie(address(this)), 100 * WAD);
        assertEq(pot.Pie(), 100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Exit(address(this), 100 * WAD);
        pot.exit(100 * WAD);

        assertEq(vat.dai(address(this)), 100 * RAD);
        assertEq(pot.pie(address(this)), 0);
        assertEq(pot.Pie(), 0);
    }

    function testSave0d() public {
        pot.join(100 * WAD);

        assertEq(vat.dai(address(this)), 0);
        assertEq(pot.pie(address(this)), 100 * WAD);

        pot.drip();
        pot.exit(100 * WAD);

        assertEq(vat.dai(address(this)), 100 * RAD);
    }

    function testSave1d() public {
        pot.join(100 * WAD);
        pot.file("dsr", uint256(1000000564701133626865910626));  // 5% / day
        vm.warp(block.timestamp + 1 days);
        pot.drip();
        assertEq(pot.pie(address(this)), 100 * WAD);
        pot.exit(100 * WAD);
        assertEq(vat.dai(address(this)), 105000000000000000000001603800000000000000000000);
    }

    function testDripMulti() public {
        pot.join(100 * WAD);
        pot.file("dsr", uint256(1000000564701133626865910626));  // 5% / day
        vm.warp(block.timestamp + 1 days);
        pot.drip();
        assertEq(vat.dai(address(pot)), 105000000000000000000001603800000000000000000000);
        pot.file("dsr", uint256(1000001103127689513476993127));  // 10% / day
        vm.warp(block.timestamp + 1 days);
        pot.drip();
        assertEq(vat.sin(TEST_ADDRESS), 15500000000000000000006151700000000000000000000);
        assertEq(vat.dai(address(pot)), 115500000000000000000006151700000000000000000000);
        assertEq(pot.Pie(), 100 * WAD);
        assertEq(pot.chi() / 10 ** 9, 1155 * WAD / 1000);
    }

    function testDripMultiInBlock() public {
        pot.drip();
        uint256 rho = pot.rho();
        assertEq(rho, block.timestamp);
        vm.warp(block.timestamp + 1 days);
        rho = pot.rho();
        assertEq(rho, block.timestamp - 1 days);
        pot.drip();
        rho = pot.rho();
        assertEq(rho, block.timestamp);
        pot.drip();
        rho = pot.rho();
        assertEq(rho, block.timestamp);
    }

    function testSaveMulti() public {
        pot.join(100 * WAD);
        pot.file("dsr", uint256(1000000564701133626865910626));  // 5% / day
        vm.warp(block.timestamp + 1 days);
        pot.drip();
        pot.exit(50 * WAD);
        assertEq(vat.dai(address(this)), 52500000000000000000000801900000000000000000000);
        assertEq(pot.Pie(), 50 * WAD);

        pot.file("dsr", uint256(1000001103127689513476993127));  // 10% / day
        vm.warp(block.timestamp + 1 days);
        pot.drip();
        pot.exit(50 * WAD);
        assertEq(vat.dai(address(this)), 110250000000000000000003877750000000000000000000);
        assertEq(pot.Pie(), 0);
    }

    function testFreshChi() public {
        uint256 rho = pot.rho();
        assertEq(rho, block.timestamp);
        vm.warp(block.timestamp + 1 days);
        assertEq(rho, block.timestamp - 1 days);
        pot.drip();
        pot.join(100 * WAD);
        assertEq(pot.pie(address(this)), 100 * WAD);
        pot.exit(100 * WAD);
        // if we exit in the same transaction we should not earn DSR
        assertEq(vat.dai(address(this)), 100 * RAD);
    }

}
