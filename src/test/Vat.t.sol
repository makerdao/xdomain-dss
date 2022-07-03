// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "dss-test/DSSTest.sol";

import {Vat} from '../Vat.sol';
import {Jug} from '../Jug.sol';
import {GemJoin} from '../GemJoin.sol';
import {DaiJoin} from '../DaiJoin.sol';

import {MockToken} from './mocks/Token.sol';

contract User {

    Vat public vat;

    constructor(Vat vat_) {
        vat = vat_;
    }

    function flux(bytes32 ilk, address src, address dst, uint256 wad) public {
        vat.flux(ilk, src, dst, wad);
    }
    function move(address src, address dst, uint256 rad) public {
        vat.move(src, dst, rad);
    }
    function frob(bytes32 ilk, address u, address v, address w, int256 dink, int256 dart) public {
        vat.frob(ilk, u, v, w, dink, dart);
    }
    function fork(bytes32 ilk, address src, address dst, int256 dink, int256 dart) public {
        vat.fork(ilk, src, dst, dink, dart);
    }
    function hope(address usr) public {
        vat.hope(usr);
    }
    function dai() public view returns (uint256) {
        return vat.dai(address(this));
    }
    function gems(bytes32 ilk) public view returns (uint256) {
        return vat.gem(ilk, address(this));
    }
    function ink(bytes32 ilk) public view returns (uint256 _ink) {
        (_ink,) = vat.urns(ilk, address(this));
    }
    function art(bytes32 ilk) public view returns (uint256 _art) {
        (,_art) = vat.urns(ilk, address(this));
    }

}

contract VatTest is DSSTest {

    Vat vat;
    User usr1;
    User usr2;
    address ausr1;
    address ausr2;

    bytes32 constant ILK = "SOME-ILK-A";

    // --- Events ---
    event Init(bytes32 indexed ilk);
    event File(bytes32 indexed ilk, bytes32 indexed what, uint256 data);
    event Cage();
    event Hope(address indexed from, address indexed to);
    event Nope(address indexed from, address indexed to);
    event Slip(bytes32 indexed ilk, address indexed usr, int256 wad);
    event Flux(bytes32 indexed ilk, address indexed src, address indexed dst, uint256 wad);
    event Move(address indexed src, address indexed dst, uint256 rad);
    event Frob(bytes32 indexed i, address indexed u, address v, address w, int256 dink, int256 dart);
    event Fork(bytes32 indexed ilk, address indexed src, address indexed dst, int256 dink, int256 dart);
    event Grab(bytes32 indexed i, address indexed u, address v, address w, int256 dink, int256 dart);
    event Heal(address indexed u, uint256 rad);
    event Suck(address indexed u, address indexed v, uint256 rad);
    event Fold(bytes32 indexed i, address indexed u, int256 rate);

    function postSetup() internal virtual override {
        vat = new Vat();
        usr1 = new User(vat);
        usr2 = new User(vat);
        ausr1 = address(usr1);
        ausr2 = address(usr2);
    }

    modifier setupCdpOps {
        vat.init(ILK);
        vat.file("Line", 1000 * RAD);
        vat.file(ILK, "spot", RAY);     // Collateral price = $1 and 100% CR for simplicity
        vat.file(ILK, "line", 1000 * RAD);
        vat.file(ILK, "dust", 10 * RAD);

        // Give some gems to the users
        vat.slip(ILK, ausr1, int256(100 * WAD));
        vat.slip(ILK, ausr2, int256(100 * WAD));

        _;
    }

    function testConstructor() public {
        assertEq(vat.live(), 1);
        assertEq(vat.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(vat), "Vat");
    }

    function testFile() public {
        checkFileUint(address(vat), "Vat", ["Line"]);
    }

    function testFileIlk() public {
        vm.expectEmit(true, true, true, true);
        emit File(ILK, "spot", 1);
        vat.file(ILK, "spot", 1);
        assertEq(vat.spot(ILK), 1);
        vat.file(ILK, "line", 1);
        assertEq(vat.line(ILK), 1);
        vat.file(ILK, "dust", 1);
        assertEq(vat.dust(ILK), 1);

        // Invalid name
        vm.expectRevert("Vat/file-unrecognized-param");
        vat.file(ILK, "badWhat", 1);

        // Not authed
        vat.deny(address(this));
        vm.expectRevert("Vat/not-authorized");
        vat.file(ILK, "spot", 1);
    }

    function testAuthModifier() public {
        vat.deny(address(this));

        bytes[] memory funcs = new bytes[](6);
        funcs[0] = abi.encodeWithSelector(Vat.init.selector, ILK);
        funcs[1] = abi.encodeWithSelector(Vat.cage.selector);
        funcs[2] = abi.encodeWithSelector(Vat.slip.selector, ILK, address(0), 0);
        funcs[3] = abi.encodeWithSelector(Vat.grab.selector, ILK, address(0), address(0), address(0), 0, 0);
        funcs[4] = abi.encodeWithSelector(Vat.suck.selector, address(0), address(0), 0);
        funcs[5] = abi.encodeWithSelector(Vat.fold.selector, ILK, address(0), 0);


        for (uint256 i = 0; i < funcs.length; i++) {
            assertRevert(address(vat), funcs[i], "Vat/not-authorized");
        }
    }

    function testLive() public {
        vat.cage();

        bytes[] memory funcs = new bytes[](6);
        funcs[0] = abi.encodeWithSelector(Vat.rely.selector, address(0));
        funcs[1] = abi.encodeWithSelector(Vat.deny.selector, address(0));
        funcs[2] = abi.encodeWithSignature("file(bytes32,uint256)", bytes32("Line"), 0);
        funcs[3] = abi.encodeWithSignature("file(bytes32,bytes32,uint256)", ILK, bytes32("Line"), 0);
        funcs[4] = abi.encodeWithSelector(Vat.frob.selector, ILK, address(0), address(0), address(0), 0, 0);
        funcs[5] = abi.encodeWithSelector(Vat.fold.selector, ILK, address(0), 0);

        for (uint256 i = 0; i < funcs.length; i++) {
            assertRevert(address(vat), funcs[i], "Vat/not-live");
        }
    }

    function testInit() public {
        assertEq(vat.rate(ILK), 0);

        vm.expectEmit(true, true, true, true);
        emit Init(ILK);
        vat.init(ILK);

        assertEq(vat.rate(ILK), RAY);
    }

    function testInitCantSetTwice() public {
        vat.init(ILK);
        vm.expectRevert("Vat/ilk-already-init");
        vat.init(ILK);
    }

    function testCage() public {
        assertEq(vat.live(), 1);

        vm.expectEmit(true, true, true, true);
        emit Cage();
        vat.cage();

        assertEq(vat.live(), 0);
    }

    function testHope() public {
        assertEq(vat.can(address(this), TEST_ADDRESS), 0);

        vm.expectEmit(true, true, true, true);
        emit Hope(address(this), TEST_ADDRESS);
        vat.hope(TEST_ADDRESS);

        assertEq(vat.can(address(this), TEST_ADDRESS), 1);
    }

    function testNope() public {
        vat.hope(TEST_ADDRESS);
        
        assertEq(vat.can(address(this), TEST_ADDRESS), 1);

        vm.expectEmit(true, true, true, true);
        emit Nope(address(this), TEST_ADDRESS);
        vat.nope(TEST_ADDRESS);

        assertEq(vat.can(address(this), TEST_ADDRESS), 0);
    }

    function testSlipPositive() public {
        assertEq(vat.gem(ILK, TEST_ADDRESS), 0);

        vm.expectEmit(true, true, true, true);
        emit Slip(ILK, TEST_ADDRESS, int256(100 * WAD));
        vat.slip(ILK, TEST_ADDRESS, int256(100 * WAD));

        assertEq(vat.gem(ILK, TEST_ADDRESS), 100 * WAD);
    }

    function testSlipNegative() public {
        vat.slip(ILK, TEST_ADDRESS, int256(100 * WAD));
        
        assertEq(vat.gem(ILK, TEST_ADDRESS), 100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Slip(ILK, TEST_ADDRESS, -int256(50 * WAD));
        vat.slip(ILK, TEST_ADDRESS, -int256(50 * WAD));

        assertEq(vat.gem(ILK, TEST_ADDRESS), 50 * WAD);
    }

    function testSlipNegativeUnderflow() public {
        assertEq(vat.gem(ILK, TEST_ADDRESS), 0);

        vm.expectRevert(stdError.arithmeticError);
        vat.slip(ILK, TEST_ADDRESS, -int256(50 * WAD));
    }

    function testFluxSelfOther() public {
        vat.slip(ILK, ausr1, int256(100 * WAD));

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);
        assertEq(vat.gem(ILK, ausr2), 0);

        vm.expectEmit(true, true, true, true);
        emit Flux(ILK, ausr1, ausr2, 100 * WAD);
        usr1.flux(ILK, ausr1, ausr2, 100 * WAD);

        assertEq(vat.gem(ILK, ausr1), 0);
        assertEq(vat.gem(ILK, ausr2), 100 * WAD);
    }

    function testFluxOtherSelf() public {
        vat.slip(ILK, ausr1, int256(100 * WAD));

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);
        assertEq(vat.gem(ILK, ausr2), 0);

        usr1.hope(ausr2);
        usr2.flux(ILK, ausr1, ausr2, 100 * WAD);

        assertEq(vat.gem(ILK, ausr1), 0);
        assertEq(vat.gem(ILK, ausr2), 100 * WAD);
    }

    function testFluxOtherSelfNoPermission() public {
        vat.slip(ILK, ausr1, int256(100 * WAD));

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);
        assertEq(vat.gem(ILK, ausr2), 0);

        vm.expectRevert("Vat/not-allowed");
        usr2.flux(ILK, ausr1, ausr2, 100 * WAD);
    }

    function testFluxSelfSelf() public {
        vat.slip(ILK, ausr1, int256(100 * WAD));

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);

        usr1.flux(ILK, ausr1, ausr1, 100 * WAD);

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);
    }

    function testFluxUnderflow() public {
        vm.expectRevert(stdError.arithmeticError);
        usr1.flux(ILK, ausr1, ausr2, 100 * WAD);
    }

    function testMoveSelfOther() public {
        vat.suck(TEST_ADDRESS, ausr1, 100 * RAD);

        assertEq(vat.dai(ausr1), 100 * RAD);
        assertEq(vat.dai(ausr2), 0);

        vm.expectEmit(true, true, true, true);
        emit Move(ausr1, ausr2, 100 * RAD);
        usr1.move(ausr1, ausr2, 100 * RAD);

        assertEq(vat.dai(ausr1), 0);
        assertEq(vat.dai(ausr2), 100 * RAD);
    }

    function testMoveOtherSelf() public {
        vat.suck(TEST_ADDRESS, ausr1, 100 * RAD);

        assertEq(vat.dai(ausr1), 100 * RAD);
        assertEq(vat.dai(ausr2), 0);

        usr1.hope(ausr2);
        usr2.move(ausr1, ausr2, 100 * RAD);

        assertEq(vat.dai(ausr1), 0);
        assertEq(vat.dai(ausr2), 100 * RAD);
    }

    function testMoveOtherSelfNoPermission() public {
        vat.suck(TEST_ADDRESS, ausr1, 100 * RAD);

        assertEq(vat.dai(ausr1), 100 * RAD);
        assertEq(vat.dai(ausr2), 0);

        vm.expectRevert("Vat/not-allowed");
        usr2.move(ausr1, ausr2, 100 * RAD);
    }

    function testMoveSelfSelf() public {
        vat.suck(TEST_ADDRESS, ausr1, 100 * RAD);

        assertEq(vat.dai(ausr1), 100 * RAD);

        usr1.move(ausr1, ausr1, 100 * RAD);

        assertEq(vat.dai(ausr1), 100 * RAD);
    }

    function testMoveUnderflow() public {
        vm.expectRevert(stdError.arithmeticError);
        usr1.move(ausr1, ausr2, 100 * RAD);
    }

    function testFrobNotInit() public {
        vm.expectRevert("Vat/ilk-not-init");
        usr1.frob(ILK, ausr1, ausr1, ausr1, 0, 0);
    }

    function testFrobMint() public setupCdpOps {
        assertEq(usr1.dai(), 0);
        assertEq(usr1.ink(ILK), 0);
        assertEq(usr1.art(ILK), 0);
        assertEq(usr1.gems(ILK), 100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.dai(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
    }

    function testFrobRepay() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.dai(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);

        usr1.frob(ILK, ausr1, ausr1, ausr1, -int256(50 * WAD), -int256(50 * WAD));

        assertEq(usr1.dai(), 50 * RAD);
        assertEq(usr1.ink(ILK), 50 * WAD);
        assertEq(usr1.art(ILK), 50 * WAD);
        assertEq(usr1.gems(ILK), 50 * WAD);
    }

    function testFrobCannotExceedIlkCeiling() public setupCdpOps {
        vat.file(ILK, "line", 10 * RAD);

        vm.expectRevert("Vat/ceiling-exceeded");
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
    }

    function testFrobCannotExceedGlobalCeiling() public setupCdpOps {
        vat.file("Line", 10 * RAD);

        vm.expectRevert("Vat/ceiling-exceeded");
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
    }

    function testFrobNotSafe() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.dai(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);

        // Cannot mint one more DAI it's undercollateralized
        vm.expectRevert("Vat/not-safe");
        usr1.frob(ILK, ausr1, ausr1, ausr1, 0, int256(1 * WAD));

        // Cannot remove even one ink or it's undercollateralized
        vm.expectRevert("Vat/not-safe");
        usr1.frob(ILK, ausr1, ausr1, ausr1, -int256(1 * WAD), 0);
    }

    function testFrobNotSafeLessRisky() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(50 * WAD), int256(50 * WAD));

        assertEq(usr1.dai(), 50 * RAD);
        assertEq(usr1.ink(ILK), 50 * WAD);
        assertEq(usr1.art(ILK), 50 * WAD);
        assertEq(usr1.gems(ILK), 50 * WAD);

        vat.file(ILK, "spot", RAY / 2);     // Vault is underwater

        // Can repay debt even if it's undercollateralized
        usr1.frob(ILK, ausr1, ausr1, ausr1, 0, -int256(1 * WAD));

        assertEq(usr1.dai(), 49 * RAD);
        assertEq(usr1.ink(ILK), 50 * WAD);
        assertEq(usr1.art(ILK), 49 * WAD);
        assertEq(usr1.gems(ILK), 50 * WAD);

        // Can add gems even if it's undercollateralized
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(1 * WAD), 0);

        assertEq(usr1.dai(), 49 * RAD);
        assertEq(usr1.ink(ILK), 51 * WAD);
        assertEq(usr1.art(ILK), 49 * WAD);
        assertEq(usr1.gems(ILK), 49 * WAD);
    }

    function testFrobPermissionlessAddCollateral() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.dai(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
        assertEq(usr2.gems(ILK), 100 * WAD);

        usr2.frob(ILK, ausr1, ausr2, ausr2, int256(100 * WAD), 0);

        assertEq(usr1.dai(), 100 * RAD);
        assertEq(usr1.ink(ILK), 200 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
        assertEq(usr2.gems(ILK), 0);
    }

    function testFrobPermissionlessRepay() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        vat.suck(TEST_ADDRESS, ausr2, 100 * RAD);

        assertEq(usr1.dai(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
        assertEq(usr2.dai(), 100 * RAD);

        usr2.frob(ILK, ausr1, ausr2, ausr2, 0, -int256(100 * WAD));

        assertEq(usr1.dai(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 0);
        assertEq(usr1.gems(ILK), 0);
        assertEq(usr2.dai(), 0);
    }

}
