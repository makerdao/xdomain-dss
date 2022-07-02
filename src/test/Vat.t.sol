// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "dss-test/DSSTest.sol";

import {Vat} from '../Vat.sol';
import {Jug} from '../Jug.sol';
import {GemJoin} from '../GemJoin.sol';
import {DaiJoin} from '../DaiJoin.sol';

import {MockToken} from './mocks/Token.sol';

contract Usr {

    Vat public vat;

    constructor(Vat vat_) {
        vat = vat_;
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

}


contract VatTest is DSSTest {

    Vat vat;

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
    }

    function testConstructor() public {
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

}
