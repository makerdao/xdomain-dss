// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "dss-test/DSSTest.sol";

import {Vat} from '../Vat.sol';
import {Jug} from '../Jug.sol';
import {GemJoin} from '../GemJoin.sol';
import {DaiJoin} from '../DaiJoin.sol';

import {MockToken} from './mocks/Token.sol';


interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
}

contract TestVat is Vat {
    uint256 constant ONE = 10 ** 27;
    function mint(address usr, uint256 wad) public {
        dai[usr] += wad * ONE;
        debt += wad * ONE;
    }
}

contract Usr {
    Vat public vat;
    constructor(Vat vat_) {
        vat = vat_;
    }
    function try_call(address addr, bytes calldata data) external returns (bool) {
        bytes memory _data = data;
        assembly {
            let ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
            let free := mload(0x40)
            mstore(free, ok)
            mstore(0x40, add(free, 32))
            revert(free, 32)
        }
    }
    function can_frob(bytes32 ilk, address u, address v, address w, int256 dink, int256 dart) public returns (bool) {
        string memory sig = "frob(bytes32,address,address,address,int256,int256)";
        bytes memory data = abi.encodeWithSignature(sig, ilk, u, v, w, dink, dart);

        bytes memory can_call = abi.encodeWithSignature("try_call(address,bytes)", vat, data);
        (bool ok, bytes memory success) = address(this).call(can_call);

        ok = abi.decode(success, (bool));
        return ok;
    }
    function can_fork(bytes32 ilk, address src, address dst, int256 dink, int256 dart) public returns (bool) {
        string memory sig = "fork(bytes32,address,address,int256,int256)";
        bytes memory data = abi.encodeWithSignature(sig, ilk, src, dst, dink, dart);

        bytes memory can_call = abi.encodeWithSignature("try_call(address,bytes)", vat, data);
        (bool ok, bytes memory success) = address(this).call(can_call);

        ok = abi.decode(success, (bool));
        return ok;
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


contract FrobTest is DSSTest {
    TestVat   vat;
    MockToken gold;
    Jug       jug;

    GemJoin gemA;
    address me;

    function try_frob(bytes32 ilk, int256 ink_, int256 art_) public returns (bool ok) {
        string memory sig = "frob(bytes32,address,address,address,int256,int256)";
        address self = address(this);
        (ok,) = address(vat).call(abi.encodeWithSignature(sig, ilk, self, self, self, ink_, art_));
    }

    function ray(uint256 wad) internal pure returns (uint) {
        return wad * 10 ** 9;
    }

    function postSetup() internal virtual override {
        vat = new TestVat();

        gold = new MockToken("GEM");
        gold.mint(1000 ether);

        vat.init("gold");
        gemA = new GemJoin(address(vat), "gold", address(gold));

        vat.file("gold", "spot",    ray(1 ether));
        vat.file("gold", "line", rad(1000 ether));
        vat.file("Line",         rad(1000 ether));
        jug = new Jug(address(vat));
        jug.init("gold");
        vat.rely(address(jug));

        gold.approve(address(gemA));
        gold.approve(address(vat));

        vat.rely(address(vat));
        vat.rely(address(gemA));

        gemA.join(address(this), 1000 ether);

        me = address(this);
    }

    function gem(bytes32 ilk, address urn) internal view returns (uint) {
        return vat.gem(ilk, urn);
    }

    function test_setup() public {
        assertEq(gold.balanceOf(address(gemA)), 1000 ether);
        assertEq(gem("gold",    address(this)), 1000 ether);
    }
    function test_join() public {
        address urn = address(this);
        gold.mint(500 ether);
        assertEq(gold.balanceOf(address(this)),    500 ether);
        assertEq(gold.balanceOf(address(gemA)),   1000 ether);
        gemA.join(urn,                             500 ether);
        assertEq(gold.balanceOf(address(this)),      0 ether);
        assertEq(gold.balanceOf(address(gemA)),   1500 ether);
        gemA.exit(urn,                             250 ether);
        assertEq(gold.balanceOf(address(this)),    250 ether);
        assertEq(gold.balanceOf(address(gemA)),   1250 ether);
    }
    function test_lock() public {
        assertEq(vat.ink("gold", address(this)),    0 ether);
        assertEq(gem("gold", address(this)), 1000 ether);
        vat.frob("gold", me, me, me, 6 ether, 0);
        assertEq(vat.ink("gold", address(this)),   6 ether);
        assertEq(gem("gold", address(this)), 994 ether);
        vat.frob("gold", me, me, me, -6 ether, 0);
        assertEq(vat.ink("gold", address(this)),    0 ether);
        assertEq(gem("gold", address(this)), 1000 ether);
    }
    function test_calm() public {
        // calm means that the debt ceiling is not exceeded
        // it's ok to increase debt as long as you remain calm
        vat.file("gold", 'line', rad(10 ether));
        assertTrue( try_frob("gold", 10 ether, 9 ether));
        // only if under debt ceiling
        assertTrue(!try_frob("gold",  0 ether, 2 ether));
    }
    function test_cool() public {
        // cool means that the debt has decreased
        // it's ok to be over the debt ceiling as long as you're cool
        vat.file("gold", 'line', rad(10 ether));
        assertTrue(try_frob("gold", 10 ether,  8 ether));
        vat.file("gold", 'line', rad(5 ether));
        // can decrease debt when over ceiling
        assertTrue(try_frob("gold",  0 ether, -1 ether));
    }
    function test_safe() public {
        // safe means that the cdp is not risky
        // you can't frob a cdp into unsafe
        vat.frob("gold", me, me, me, 10 ether, 5 ether);                // safe draw
        assertTrue(!try_frob("gold", 0 ether, 6 ether));  // unsafe draw
    }
    function test_nice() public {
        // nice means that the collateral has increased or the debt has
        // decreased. remaining unsafe is ok as long as you're nice

        vat.frob("gold", me, me, me, 10 ether, 10 ether);
        vat.file("gold", 'spot', ray(0.5 ether));  // now unsafe

        // debt can't increase if unsafe
        assertTrue(!try_frob("gold",  0 ether,  1 ether));
        // debt can decrease
        assertTrue( try_frob("gold",  0 ether, -1 ether));
        // ink can't decrease
        assertTrue(!try_frob("gold", -1 ether,  0 ether));
        // ink can increase
        assertTrue( try_frob("gold",  1 ether,  0 ether));

        // cdp is still unsafe
        // ink can't decrease, even if debt decreases more
        assertTrue(!this.try_frob("gold", -2 ether, -4 ether));
        // debt can't increase, even if ink increases more
        assertTrue(!this.try_frob("gold",  5 ether,  1 ether));

        // ink can decrease if end state is safe
        assertTrue( this.try_frob("gold", -1 ether, -4 ether));
        vat.file("gold", 'spot', ray(0.4 ether));  // now unsafe
        // debt can increase if end state is safe
        assertTrue( this.try_frob("gold",  5 ether, 1 ether));
    }

    function rad(uint256 wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }
    function test_alt_callers() public {
        Usr ali = new Usr(vat);
        Usr bob = new Usr(vat);
        Usr che = new Usr(vat);

        address a = address(ali);
        address b = address(bob);
        address c = address(che);

        vat.slip("gold", a, int256(rad(20 ether)));
        vat.slip("gold", b, int256(rad(20 ether)));
        vat.slip("gold", c, int256(rad(20 ether)));

        ali.frob("gold", a, a, a, 10 ether, 5 ether);

        // anyone can lock
        assertTrue( ali.can_frob("gold", a, a, a,  1 ether,  0 ether));
        assertTrue( bob.can_frob("gold", a, b, b,  1 ether,  0 ether));
        assertTrue( che.can_frob("gold", a, c, c,  1 ether,  0 ether));
        // but only with their own gems
        assertTrue(!ali.can_frob("gold", a, b, a,  1 ether,  0 ether));
        assertTrue(!bob.can_frob("gold", a, c, b,  1 ether,  0 ether));
        assertTrue(!che.can_frob("gold", a, a, c,  1 ether,  0 ether));

        // only the lad can free
        assertTrue( ali.can_frob("gold", a, a, a, -1 ether,  0 ether));
        assertTrue(!bob.can_frob("gold", a, b, b, -1 ether,  0 ether));
        assertTrue(!che.can_frob("gold", a, c, c, -1 ether,  0 ether));
        // the lad can free to anywhere
        assertTrue( ali.can_frob("gold", a, b, a, -1 ether,  0 ether));
        assertTrue( ali.can_frob("gold", a, c, a, -1 ether,  0 ether));

        // only the lad can draw
        assertTrue( ali.can_frob("gold", a, a, a,  0 ether,  1 ether));
        assertTrue(!bob.can_frob("gold", a, b, b,  0 ether,  1 ether));
        assertTrue(!che.can_frob("gold", a, c, c,  0 ether,  1 ether));
        // the lad can draw to anywhere
        assertTrue( ali.can_frob("gold", a, a, b,  0 ether,  1 ether));
        assertTrue( ali.can_frob("gold", a, a, c,  0 ether,  1 ether));

        vat.mint(address(bob), 1 ether);
        vat.mint(address(che), 1 ether);

        // anyone can wipe
        assertTrue( ali.can_frob("gold", a, a, a,  0 ether, -1 ether));
        assertTrue( bob.can_frob("gold", a, b, b,  0 ether, -1 ether));
        assertTrue( che.can_frob("gold", a, c, c,  0 ether, -1 ether));
        // but only with their own dai
        assertTrue(!ali.can_frob("gold", a, a, b,  0 ether, -1 ether));
        assertTrue(!bob.can_frob("gold", a, b, c,  0 ether, -1 ether));
        assertTrue(!che.can_frob("gold", a, c, a,  0 ether, -1 ether));
    }

    function test_hope() public {
        Usr ali = new Usr(vat);
        Usr bob = new Usr(vat);
        Usr che = new Usr(vat);

        address a = address(ali);
        address b = address(bob);
        address c = address(che);

        vat.slip("gold", a, int256(rad(20 ether)));
        vat.slip("gold", b, int256(rad(20 ether)));
        vat.slip("gold", c, int256(rad(20 ether)));

        ali.frob("gold", a, a, a, 10 ether, 5 ether);

        // only owner can do risky actions
        assertTrue( ali.can_frob("gold", a, a, a,  0 ether,  1 ether));
        assertTrue(!bob.can_frob("gold", a, b, b,  0 ether,  1 ether));
        assertTrue(!che.can_frob("gold", a, c, c,  0 ether,  1 ether));

        ali.hope(address(bob));

        // unless they hope another user
        assertTrue( ali.can_frob("gold", a, a, a,  0 ether,  1 ether));
        assertTrue( bob.can_frob("gold", a, b, b,  0 ether,  1 ether));
        assertTrue(!che.can_frob("gold", a, c, c,  0 ether,  1 ether));
    }

    function test_dust() public {
        assertTrue( try_frob("gold", 9 ether,  1 ether));
        vat.file("gold", "dust", rad(5 ether));
        assertTrue(!try_frob("gold", 5 ether,  2 ether));
        assertTrue( try_frob("gold", 0 ether,  5 ether));
        assertTrue(!try_frob("gold", 0 ether, -5 ether));
        assertTrue( try_frob("gold", 0 ether, -6 ether));
    }
}

contract JoinTest is DSTest {
    TestVat   vat;
    MockToken gem;
    GemJoin   gemA;
    DaiJoin   daiA;
    MockToken dai;
    address   me;

    function setUp() public {
        vat = new TestVat();
        vat.init("eth");

        gem  = new MockToken("Gem");
        gemA = new GemJoin(address(vat), "gem", address(gem));
        vat.rely(address(gemA));

        dai  = new MockToken("Dai");
        daiA = new DaiJoin(address(vat), address(dai));

        me = address(this);
    }
    function try_cage(address a) public payable returns (bool ok) {
        string memory sig = "cage()";
        (ok,) = a.call(abi.encodeWithSignature(sig));
    }
    function try_join_gem(address usr, uint256 wad) public returns (bool ok) {
        string memory sig = "join(address,uint256)";
        (ok,) = address(gemA).call(abi.encodeWithSignature(sig, usr, wad));
    }
    function try_exit_dai(address usr, uint256 wad) public returns (bool ok) {
        string memory sig = "exit(address,uint256)";
        (ok,) = address(daiA).call(abi.encodeWithSignature(sig, usr, wad));
    }
    function test_gem_join() public {
        gem.mint(20 ether);
        gem.approve(address(gemA), 20 ether);
        assertTrue( try_join_gem(address(this), 10 ether));
        assertEq(vat.gem("gem", me), 10 ether);
        assertTrue( try_cage(address(gemA)));
        assertTrue(!try_join_gem(address(this), 10 ether));
        assertEq(vat.gem("gem", me), 10 ether);
    }
    function rad(uint256 wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }
    function test_dai_exit() public {
        address urn = address(this);
        vat.mint(address(this), 100 ether);
        vat.hope(address(daiA));
        assertTrue( try_exit_dai(urn, 40 ether));
        assertEq(dai.balanceOf(address(this)), 40 ether);
        assertEq(vat.dai(me),              rad(60 ether));
    }
    function test_dai_exit_join() public {
        address urn = address(this);
        vat.mint(address(this), 100 ether);
        vat.hope(address(daiA));
        daiA.exit(urn, 60 ether);
        dai.approve(address(daiA), type(uint256).max);
        daiA.join(urn, 30 ether);
        assertEq(dai.balanceOf(address(this)),     30 ether);
        assertEq(vat.dai(me),                  rad(70 ether));
    }
    function test_cage_no_access() public {
        gemA.deny(address(this));
        assertTrue(!try_cage(address(gemA)));
    }
}

contract FoldTest is DSTest {
    Vat vat;

    function ray(uint256 wad) internal pure returns (uint) {
        return wad * 10 ** 9;
    }
    function rad(uint256 wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }
    function tab(bytes32 ilk, address urn) internal view returns (uint) {
        (uint256 ink_, uint256 art_) = vat.urns(ilk, urn); ink_;
        (uint256 Art_, uint256 rate, uint256 spot, uint256 line, uint256 dust) = vat.ilks(ilk);
        Art_; spot; line; dust;
        return art_ * rate;
    }
    function jam(bytes32 ilk, address urn) internal view returns (uint) {
        (uint256 ink_, uint256 art_) = vat.urns(ilk, urn); art_;
        return ink_;
    }

    function setUp() public {
        vat = new Vat();
        vat.init("gold");
        vat.file("Line", rad(100 ether));
        vat.file("gold", "line", rad(100 ether));
    }
    function draw(bytes32 ilk, uint256 dai) internal {
        vat.file("Line", rad(dai));
        vat.file(ilk, "line", rad(dai));
        vat.file(ilk, "spot", 10 ** 27 * 10000 ether);
        address self = address(this);
        vat.slip(ilk, self,  10 ** 27 * 1 ether);
        vat.frob(ilk, self, self, self, int256(1 ether), int256(dai));
    }
    function test_fold() public {
        address self = address(this);
        address ali  = address(bytes20("ali"));
        draw("gold", 1 ether);

        assertEq(tab("gold", self), rad(1.00 ether));
        vat.fold("gold", ali,   int256(ray(0.05 ether)));
        assertEq(tab("gold", self), rad(1.05 ether));
        assertEq(vat.dai(ali),      rad(0.05 ether));
    }
}

contract ForkTest is DSTest {
    Vat vat;
    Usr ali;
    Usr bob;
    address a;
    address b;

    function ray(uint wad) internal pure returns (uint) {
        return wad * 10 ** 9;
    }
    function rad(uint wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }

    function setUp() public {
        vat = new Vat();
        ali = new Usr(vat);
        bob = new Usr(vat);
        a = address(ali);
        b = address(bob);

        vat.init("gems");
        vat.file("gems", "spot", ray(0.5  ether));
        vat.file("gems", "line", rad(1000 ether));
        vat.file("Line",         rad(1000 ether));

        vat.slip("gems", a, 8 ether);
    }
    function test_fork_to_self() public {
        ali.frob("gems", a, a, a, 8 ether, 4 ether);
        assertTrue( ali.can_fork("gems", a, a, 8 ether, 4 ether));
        assertTrue( ali.can_fork("gems", a, a, 4 ether, 2 ether));
        assertTrue(!ali.can_fork("gems", a, a, 9 ether, 4 ether));
    }
    function test_give_to_other() public {
        ali.frob("gems", a, a, a, 8 ether, 4 ether);
        assertTrue(!ali.can_fork("gems", a, b, 8 ether, 4 ether));
        bob.hope(address(ali));
        assertTrue( ali.can_fork("gems", a, b, 8 ether, 4 ether));
    }
    function test_fork_to_other() public {
        ali.frob("gems", a, a, a, 8 ether, 4 ether);
        bob.hope(address(ali));
        assertTrue( ali.can_fork("gems", a, b, 4 ether, 2 ether));
        assertTrue(!ali.can_fork("gems", a, b, 4 ether, 3 ether));
        assertTrue(!ali.can_fork("gems", a, b, 4 ether, 1 ether));
    }
    function test_fork_dust() public {
        ali.frob("gems", a, a, a, 8 ether, 4 ether);
        bob.hope(address(ali));
        assertTrue( ali.can_fork("gems", a, b, 4 ether, 2 ether));
        vat.file("gems", "dust", rad(1 ether));
        assertTrue( ali.can_fork("gems", a, b, 2 ether, 1 ether));
        assertTrue(!ali.can_fork("gems", a, b, 1 ether, 0.5 ether));
    }
}
