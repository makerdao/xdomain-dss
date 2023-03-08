// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "dss-test/DSSTest.sol";

import { Cure } from "../Cure.sol";

contract SourceMock {

    uint256 public cure;

    constructor(uint256 cure_) {
        cure = cure_;
    }

    function update(uint256 cure_) external {
        cure = cure_;
    }

}

contract CureTest is DSSTest {

    Cure cure;

    event Lift(address indexed src);
    event Drop(address indexed src);
    event Load(address indexed src);
    event Cage();

    function postSetup() internal virtual override {
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        cure = new Cure();
    }

    function testConstructor() public {
        assertEq(cure.live(), 1);
        assertEq(cure.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(cure), "Cure");
    }

    function testFile() public {
        checkFileUint(address(cure), "Cure", ["wait"]);
    }

    function testAuthModifier() public {
        cure.deny(address(this));

        bytes[] memory funcs = new bytes[](3);
        funcs[0] = abi.encodeWithSelector(Cure.lift.selector, 0, 0, 0, 0);
        funcs[1] = abi.encodeWithSelector(Cure.drop.selector, 0, 0, 0, 0);
        funcs[2] = abi.encodeWithSelector(Cure.cage.selector, 0, 0, 0, 0);

        for (uint256 i = 0; i < funcs.length; i++) {
            assertRevert(address(cure), funcs[i], "Cure/not-authorized");
        }
    }

    function testLive() public {
        cure.cage();

        bytes[] memory funcs = new bytes[](6);
        funcs[0] = abi.encodeWithSelector(Cure.rely.selector, 0, 0, 0, 0);
        funcs[1] = abi.encodeWithSelector(Cure.deny.selector, 0, 0, 0, 0);
        funcs[2] = abi.encodeWithSelector(Cure.file.selector, 0, 0, 0, 0);
        funcs[3] = abi.encodeWithSelector(Cure.lift.selector, 0, 0, 0, 0);
        funcs[4] = abi.encodeWithSelector(Cure.drop.selector, 0, 0, 0, 0);
        funcs[5] = abi.encodeWithSelector(Cure.cage.selector, 0, 0, 0, 0);

        for (uint256 i = 0; i < funcs.length; i++) {
            assertRevert(address(cure), funcs[i], "Cure/not-live");
        }
    }

    function testAddSourceDelSource() public {
        assertEq(cure.tCount(), 0);

        address addr1 = address(new SourceMock(0));
        vm.expectEmit(true, true, true, true);
        emit Lift(addr1);
        cure.lift(addr1);
        assertEq(cure.tCount(), 1);

        address addr2 = address(new SourceMock(0));
        vm.expectEmit(true, true, true, true);
        emit Lift(addr2);
        cure.lift(addr2);
        assertEq(cure.tCount(), 2);

        address addr3 = address(new SourceMock(0));
        vm.expectEmit(true, true, true, true);
        emit Lift(addr3);
        cure.lift(addr3);
        assertEq(cure.tCount(), 3);

        assertEq(cure.srcs(0), addr1);
        assertEq(cure.pos(addr1), 1);
        assertEq(cure.srcs(1), addr2);
        assertEq(cure.pos(addr2), 2);
        assertEq(cure.srcs(2), addr3);
        assertEq(cure.pos(addr3), 3);

        vm.expectEmit(true, true, true, true);
        emit Drop(addr3);
        cure.drop(addr3);
        assertEq(cure.tCount(), 2);
        assertEq(cure.srcs(0), addr1);
        assertEq(cure.pos(addr1), 1);
        assertEq(cure.srcs(1), addr2);
        assertEq(cure.pos(addr2), 2);

        vm.expectEmit(true, true, true, true);
        emit Lift(addr3);
        cure.lift(addr3);
        assertEq(cure.tCount(), 3);
        assertEq(cure.srcs(0), addr1);
        assertEq(cure.pos(addr1), 1);
        assertEq(cure.srcs(1), addr2);
        assertEq(cure.pos(addr2), 2);
        assertEq(cure.srcs(2), addr3);
        assertEq(cure.pos(addr3), 3);

        vm.expectEmit(true, true, true, true);
        emit Drop(addr1);
        cure.drop(addr1);
        assertEq(cure.tCount(), 2);
        assertEq(cure.srcs(0), addr3);
        assertEq(cure.pos(addr3), 1);
        assertEq(cure.srcs(1), addr2);
        assertEq(cure.pos(addr2), 2);

        vm.expectEmit(true, true, true, true);
        emit Lift(addr1);
        cure.lift(addr1);
        assertEq(cure.tCount(), 3);
        assertEq(cure.srcs(0), addr3);
        assertEq(cure.pos(addr3), 1);
        assertEq(cure.srcs(1), addr2);
        assertEq(cure.pos(addr2), 2);
        assertEq(cure.srcs(2), addr1);
        assertEq(cure.pos(addr1), 3);

        address addr4 = address(new SourceMock(0));
        vm.expectEmit(true, true, true, true);
        emit Lift(addr4);
        cure.lift(addr4);
        assertEq(cure.tCount(), 4);
        assertEq(cure.srcs(0), addr3);
        assertEq(cure.pos(addr3), 1);
        assertEq(cure.srcs(1), addr2);
        assertEq(cure.pos(addr2), 2);
        assertEq(cure.srcs(2), addr1);
        assertEq(cure.pos(addr1), 3);
        assertEq(cure.srcs(3), addr4);
        assertEq(cure.pos(addr4), 4);

        vm.expectEmit(true, true, true, true);
        emit Drop(addr2);
        cure.drop(addr2);
        assertEq(cure.tCount(), 3);
        assertEq(cure.srcs(0), addr3);
        assertEq(cure.pos(addr3), 1);
        assertEq(cure.srcs(1), addr4);
        assertEq(cure.pos(addr4), 2);
        assertEq(cure.srcs(2), addr1);
        assertEq(cure.pos(addr1), 3);
    }

    function testDelSourceNonExisting() public {
        address addr1 = address(new SourceMock(0));
        cure.lift(addr1);
        address addr2 = address(new SourceMock(0));
        vm.expectRevert("Cure/non-existing-source");
        cure.drop(addr2);
    }

    function testCage() public {
        assertEq(cure.live(), 1);
        vm.expectEmit(true, true, true, true);
        emit Cage();
        cure.cage();
        assertEq(cure.live(), 0);
    }

    function testCure() public {
        address source1 = address(new SourceMock(15_000));
        address source2 = address(new SourceMock(30_000));
        address source3 = address(new SourceMock(50_000));
        cure.lift(source1);
        cure.lift(source2);
        cure.lift(source3);

        cure.cage();

        cure.load(source1);
        assertEq(cure.say(), 15_000);
        assertEq(cure.tell(), 15_000); // It doesn't fail as wait == 0
        cure.load(source2);
        assertEq(cure.say(), 45_000);
        assertEq(cure.tell(), 45_000);
        cure.load(source3);
        assertEq(cure.say(), 95_000);
        assertEq(cure.tell(), 95_000);
    }

    function testCureAllLoaded() public {
        address source1 = address(new SourceMock(15_000));
        address source2 = address(new SourceMock(30_000));
        address source3 = address(new SourceMock(50_000));
        cure.lift(source1);
        assertEq(cure.tCount(), 1);
        cure.lift(source2);
        assertEq(cure.tCount(), 2);
        cure.lift(source3);
        assertEq(cure.tCount(), 3);

        cure.file("wait", 10);

        cure.cage();

        cure.load(source1);
        assertEq(cure.lCount(), 1);
        assertEq(cure.say(), 15_000);
        cure.load(source2);
        assertEq(cure.lCount(), 2);
        assertEq(cure.say(), 45_000);
        cure.load(source3);
        assertEq(cure.lCount(), 3);
        assertEq(cure.say(), 95_000);
        assertEq(cure.tell(), 95_000);
    }

    function testCureWaitPassed() public {
        address source1 = address(new SourceMock(15_000));
        address source2 = address(new SourceMock(30_000));
        address source3 = address(new SourceMock(50_000));
        cure.lift(source1);
        cure.lift(source2);
        cure.lift(source3);

        cure.file("wait", 10);

        cure.cage();

        cure.load(source1);
        cure.load(source2);
        vm.warp(block.timestamp + 10);
        assertEq(cure.tell(), 45_000);
    }

    function testWaitNotPassed() public {
        address source1 = address(new SourceMock(15_000));
        address source2 = address(new SourceMock(30_000));
        address source3 = address(new SourceMock(50_000));
        cure.lift(source1);
        cure.lift(source2);
        cure.lift(source3);

        cure.file("wait", 10);

        cure.cage();

        cure.load(source1);
        cure.load(source2);
        vm.warp(block.timestamp + 9);
        vm.expectRevert("Cure/missing-load-and-time-not-passed");
        cure.tell();
    }

    function testLoadMultipleTimes() public {
        address source1 = address(new SourceMock(2_000));
        address source2 = address(new SourceMock(3_000));
        cure.lift(source1);
        cure.lift(source2);

        cure.cage();

        vm.expectEmit(true, true, true, true);
        emit Load(source1);
        cure.load(source1);
        assertEq(cure.lCount(), 1);
        cure.load(source2);
        assertEq(cure.lCount(), 2);
        assertEq(cure.tell(), 5_000);

        SourceMock(source1).update(4_000);
        assertEq(cure.tell(), 5_000);

        cure.load(source1);
        assertEq(cure.lCount(), 2);
        assertEq(cure.tell(), 7_000);

        SourceMock(source2).update(6_000);
        assertEq(cure.tell(), 7_000);

        cure.load(source2);
        assertEq(cure.lCount(), 2);
        assertEq(cure.tell(), 10_000);
    }

    function testLoadNoChange() public {
        address source = address(new SourceMock(2_000));
        cure.lift(source);

        cure.cage();

        cure.load(source);
        assertEq(cure.tell(), 2_000);

        cure.load(source);
        assertEq(cure.tell(), 2_000);
    }

    function testLoadNotCaged() public {
        address source = address(new SourceMock(2_000));
        cure.lift(source);

        vm.expectRevert("Cure/still-live");
        cure.load(source);
    }

    function testLoadNotAdded() public {
        address source = address(new SourceMock(2_000));

        cure.cage();

        vm.expectRevert("Cure/non-existing-source");
        cure.load(source);
    }

}
