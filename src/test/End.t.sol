// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "dss-test/DSSTest.sol";
import "ds-value/value.sol";

import {MockToken} from './mocks/Token.sol';

import {Vat}        from '../Vat.sol';
import {Pot}        from '../Pot.sol';
import {GemJoin}    from '../GemJoin.sol';
import {End}        from '../End.sol';
import {Spotter}    from '../Spotter.sol';
import {Cure}       from '../Cure.sol';
import {ClaimToken} from '../ClaimToken.sol';

contract Usr {

    Vat        public vat;
    End        public end;
    ClaimToken public claimToken;

    constructor(Vat vat_, End end_) {
        vat  = vat_;
        end  = end_;
        claimToken = ClaimToken(address(end.claim()));
    }
    function frob(bytes32 ilk, address u, address v, address w, int dink, int dart) public {
        vat.frob(ilk, u, v, w, dink, dart);
    }
    function flux(bytes32 ilk, address src, address dst, uint256 wad) public {
        vat.flux(ilk, src, dst, wad);
    }
    function move(address src, address dst, uint256 rad) public {
        vat.move(src, dst, rad);
    }
    function hope(address usr) public {
        vat.hope(usr);
    }
    function exit(GemJoin gemA, address usr, uint256 wad) public {
        gemA.exit(usr, wad);
    }
    function free(bytes32 ilk) public {
        end.free(ilk);
    }
    function pack(uint256 wad) public {
        end.pack(wad);
    }
    function cash(bytes32 ilk, uint256 wad) public {
        end.cash(ilk, wad);
    }
    function approveClaim(address who, uint256 amount) public {
        claimToken.approve(who, amount);
    }

}

contract MockVow {

    Vat     public vat;

    constructor(Vat _vat) {
        vat = _vat;
    }

    function heal(uint256 amount) external {
        vat.heal(amount);
    }

}

contract EndTest is DSSTest {

    Vat         vat;
    End         end;
    MockVow     vow;
    Pot         pot;
    Spotter     spot;
    Cure        cure;
    ClaimToken  claimToken;

    event Cage();
    event Cage(bytes32 indexed ilk);
    event Skim(bytes32 indexed ilk, address indexed urn, uint256 wad, uint256 art);
    event Free(bytes32 indexed ilk, address indexed usr, uint256 ink);
    event Thaw();
    event Flow(bytes32 indexed ilk);
    event Pack(address indexed usr, uint256 wad);
    event Cash(bytes32 indexed ilk, address indexed usr, uint256 wad);

    struct Ilk {
        DSValue pip;
        MockToken gem;
        GemJoin gemA;
    }

    mapping (bytes32 => Ilk) ilks;

    uint256 constant MLN = 10 ** 6;

    function ray(uint256 wad) internal pure returns (uint) {
        return wad * 10 ** 9;
    }
    function rad(uint256 wad) internal pure returns (uint) {
        return wad * RAY;
    }
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / RAY;
    }
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        (x >= y) ? z = y : z = x;
    }
    function dai(address urn) internal view returns (uint) {
        return vat.dai(urn) / RAY;
    }
    function gem(bytes32 ilk, address urn) internal view returns (uint) {
        return vat.gem(ilk, urn);
    }
    function ink(bytes32 ilk, address urn) internal view returns (uint) {
        (uint256 ink_, uint256 art_) = vat.urns(ilk, urn); art_;
        return ink_;
    }
    function art(bytes32 ilk, address urn) internal view returns (uint) {
        (uint256 ink_, uint256 art_) = vat.urns(ilk, urn); ink_;
        return art_;
    }
    function Art(bytes32 ilk) internal view returns (uint) {
        (uint256 Art_, uint256 rate_, uint256 spot_, uint256 line_, uint256 dust_) = vat.ilks(ilk);
        rate_; spot_; line_; dust_;
        return Art_;
    }
    function balanceOf(bytes32 ilk, address usr) internal view returns (uint) {
        return ilks[ilk].gem.balanceOf(usr);
    }

    function try_pot_file(bytes32 what, uint256 data) public returns(bool ok) {
        string memory sig = "file(bytes32, uint)";
        (ok,) = address(pot).call(abi.encodeWithSignature(sig, what, data));
    }

    function init_collateral(bytes32 name) internal returns (Ilk memory) {
        MockToken coin = new MockToken("");
        coin.mint(500_000 ether);

        DSValue pip = new DSValue();
        spot.file(name, "pip", address(pip));
        spot.file(name, "mat", ray(2 ether));
        // initial collateral price of 6
        pip.poke(bytes32(6 * WAD));
        spot.poke(name);

        vat.init(name);
        vat.file(name, "line", rad(1_000_000 ether));

        GemJoin gemA = new GemJoin(address(vat), name, address(coin));

        coin.approve(address(gemA));
        coin.approve(address(vat));

        vat.rely(address(gemA));

        ilks[name].pip = pip;
        ilks[name].gem = coin;
        ilks[name].gemA = gemA;

        return ilks[name];
    }

    function postSetup() internal virtual override {
        vm.warp(604411200);

        vat = new Vat();
        claimToken = new ClaimToken();

        vow = new MockVow(vat);

        pot = new Pot(address(vat));
        vat.rely(address(pot));
        pot.file("vow", address(vow));

        spot = new Spotter(address(vat));
        vat.file("Line",         rad(1_000_000 ether));
        vat.rely(address(spot));

        cure = new Cure();

        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        end = new End(address(vat));
        end.file("vow", address(vow));
        end.file("pot", address(pot));
        end.file("spot", address(spot));
        end.file("cure", address(cure));
        end.file("claim", address(claimToken));
        end.file("wait", 1 hours);
        vat.rely(address(end));
        spot.rely(address(end));
        pot.rely(address(end));
        cure.rely(address(end));
        claimToken.rely(address(end));
    }

    function testConstructor() public {
        assertEq(end.live(), 1);
        assertEq(end.wards(address(this)), 1);
        assertEq(address(end.vat()), address(vat));
    }

    function testAuth() public {
        checkAuth(address(end), "End");
    }

    function testFile() public {
        checkFileUint(address(end), "End", ["wait"]);
        checkFileAddress(address(end), "End", ["vow", "pot", "spot", "cure", "claim"]);
    }

    function testAuthModifier() public {
        end.deny(address(this));

        bytes[] memory funcs = new bytes[](1);
        funcs[0] = abi.encodeWithSignature("cage()", 0, 0, 0, 0);

        for (uint256 i = 0; i < funcs.length; i++) {
            assertRevert(address(end), funcs[i], "End/not-authorized");
        }
    }

    function testLive() public {
        {
            bytes[] memory funcs = new bytes[](3);
            funcs[0] = abi.encodeWithSignature("cage(bytes32)", 0, 0, 0, 0);
            funcs[1] = abi.encodeWithSelector(End.free.selector, 0, 0, 0, 0);
            funcs[2] = abi.encodeWithSelector(End.thaw.selector, 0, 0, 0, 0);

            for (uint256 i = 0; i < funcs.length; i++) {
                assertRevert(address(end), funcs[i], "End/still-live");
            }
        }

        end.cage();

        {
            bytes[] memory funcs = new bytes[](3);
            funcs[0] = abi.encodeWithSignature("file(bytes32,address)", 0, 0, 0, 0);
            funcs[1] = abi.encodeWithSignature("file(bytes32,uint256)", 0, 0, 0, 0);
            funcs[2] = abi.encodeWithSignature("cage()", 0, 0, 0, 0);

            for (uint256 i = 0; i < funcs.length; i++) {
                assertRevert(address(end), funcs[i], "End/not-live");
            }
        }
    }

    function testCageBasic() public {
        assertEq(end.live(), 1);
        assertEq(vat.live(), 1);
        assertEq(pot.live(), 1);
        assertEq(spot.live(), 1);
        vm.expectEmit(true, true, true, true);
        emit Cage();
        end.cage();
        assertEq(end.live(), 0);
        assertEq(vat.live(), 0);
        assertEq(pot.live(), 0);
        assertEq(spot.live(), 0);
    }

    function testCagePotDrip() public {
        assertEq(pot.live(), 1);
        pot.drip();
        end.cage();

        assertEq(pot.live(), 0);
        assertEq(pot.dsr(), 10 ** 27);
        assertTrue(!try_pot_file("dsr", 10 ** 27 + 1));
    }

    // -- Scenario where there is one over-collateralised CDP
    // -- and there is no Vow deficit or surplus
    function testCageCollateralised() public {
        Ilk memory gold = init_collateral("gold");

        Usr ali = new Usr(vat, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.join(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 gem, 10 ink, 15 tab, 15 dai

        // global checks:
        assertEq(vat.debt(), rad(15 ether));
        assertEq(vat.vice(), 0);

        // collateral price is 5
        gold.pip.poke(bytes32(5 * WAD));
        end.cage();
        vm.expectEmit(true, true, true, true);
        emit Cage("gold");
        end.cage("gold");
        vm.expectEmit(true, true, true, true);
        emit Skim("gold", urn1, 3 ether, 15 ether);
        end.skim("gold", urn1);

        // local checks:
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 7 ether);
        assertEq(vat.sin(address(vow)), rad(15 ether));

        // global checks:
        assertEq(vat.debt(), rad(15 ether));
        assertEq(vat.vice(), rad(15 ether));

        // CDP closing
        vm.expectEmit(true, true, true, true);
        emit Free("gold", address(ali), 7 ether);
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(gem("gold", urn1), 7 ether);
        ali.exit(gold.gemA, address(this), 7 ether);

        vm.warp(block.timestamp + 1 hours);
        vm.expectEmit(true, true, true, true);
        emit Thaw();
        end.thaw();
        assertEq(end.debt(), rad(15 ether));
        assertEq(claimToken.totalSupply(), rad(15 ether));
        assertEq(claimToken.balanceOf(address(end)), rad(15 ether));
        vm.expectEmit(true, true, true, true);
        emit Flow("gold");
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // dai redemption
        claimToken.mint(address(ali), rad(15 ether));
        ali.approveClaim(address(end), rad(15 ether));
        vm.expectEmit(true, true, true, true);
        emit Pack(address(ali), 15 ether);
        ali.pack(15 ether);

        // global checks:
        assertEq(vat.debt(), rad(15 ether));
        assertEq(vat.vice(), rad(15 ether));
        assertEq(vat.sin(address(vow)), rad(15 ether));
        assertEq(claimToken.balanceOf(address(ali)), 0);

        vm.expectEmit(true, true, true, true);
        emit Cash("gold", address(ali), 15 ether);
        ali.cash("gold", 15 ether);

        // local checks:
        assertEq(dai(urn1), 15 ether);
        assertEq(gem("gold", urn1), 3 ether);
        ali.exit(gold.gemA, address(this), 3 ether);

        assertEq(gem("gold", address(end)), 0);
        assertEq(balanceOf("gold", address(gold.gemA)), 0);
    }

    // -- Scenario where there is one over-collateralised and one
    // -- under-collateralised CDP, and no Vow deficit or surplus
    function testCageUndercollateralised() public {
        Ilk memory gold = init_collateral("gold");

        Usr ali = new Usr(vat, end);
        Usr bob = new Usr(vat, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.join(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 gem, 10 ink, 15 tab, 15 dai

        // make a second CDP:
        address urn2 = address(bob);
        gold.gemA.join(urn2, 1 ether);
        bob.frob("gold", urn2, urn2, urn2, 1 ether, 3 ether);
        // bob's urn has 0 gem, 1 ink, 3 tab, 3 dai

        // global checks:
        assertEq(vat.debt(), rad(18 ether));
        assertEq(vat.vice(), 0);

        // collateral price is 2
        gold.pip.poke(bytes32(2 * WAD));
        end.cage();
        end.cage("gold");
        end.skim("gold", urn1);  // over-collateralised
        end.skim("gold", urn2);  // under-collateralised

        // local checks
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 2.5 ether);
        assertEq(art("gold", urn2), 0);
        assertEq(ink("gold", urn2), 0);
        assertEq(vat.sin(address(vow)), rad(18 ether));

        // global checks
        assertEq(vat.debt(), rad(18 ether));
        assertEq(vat.vice(), rad(18 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(gem("gold", urn1), 2.5 ether);
        ali.exit(gold.gemA, address(this), 2.5 ether);

        vm.warp(block.timestamp + 1 hours);
        end.thaw();
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // first dai redemption
        claimToken.mint(address(ali), rad(15 ether));
        ali.approveClaim(address(end), rad(15 ether));
        ali.pack(15 ether);

        // global checks:
        assertEq(vat.debt(), rad(18 ether));
        assertEq(vat.vice(), rad(18 ether));
        assertEq(vat.sin(address(vow)), rad(18 ether));
        assertEq(claimToken.balanceOf(address(ali)), 0);

        ali.cash("gold", 15 ether);

        // local checks:
        assertEq(dai(urn1), 15 ether);
        uint256 fix = end.fix("gold");
        assertEq(gem("gold", urn1), rmul(fix, 15 ether));
        ali.exit(gold.gemA, address(this), rmul(fix, 15 ether));

        // second dai redemption
        claimToken.mint(address(bob), rad(3 ether));
        bob.approveClaim(address(end), rad(3 ether));
        bob.pack(3 ether);

        // global checks:
        assertEq(vat.debt(), rad(18 ether));
        assertEq(vat.vice(), rad(18 ether));
        assertEq(vat.sin(address(vow)), rad(18 ether));
        assertEq(claimToken.balanceOf(address(bob)), 0);

        bob.cash("gold", 3 ether);

        // local checks:
        assertEq(dai(urn2), 3 ether);
        assertEq(gem("gold", urn2), rmul(fix, 3 ether));
        bob.exit(gold.gemA, address(this), rmul(fix, 3 ether));

        // some dust remains in the End because of rounding:
        assertEq(gem("gold", address(end)), 1);
        assertEq(balanceOf("gold", address(gold.gemA)), 1);
    }

    // -- Scenario where there is one over-collateralised CDP
    // -- and there is a deficit in the Vow
    function testCageCollateralisedDeficit() public {
        Ilk memory gold = init_collateral("gold");

        Usr ali = new Usr(vat, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.join(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 gem, 10 ink, 15 tab, 15 dai
        // suck 1 dai and give to ali
        vat.suck(address(vow), address(ali), rad(1 ether));

        // global checks:
        assertEq(vat.debt(), rad(16 ether));
        assertEq(vat.vice(), rad(1 ether));

        // collateral price is 5
        gold.pip.poke(bytes32(5 * WAD));
        end.cage();
        end.cage("gold");
        end.skim("gold", urn1);

        // local checks:
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 7 ether);
        assertEq(vat.sin(address(vow)), rad(16 ether));

        // global checks:
        assertEq(vat.debt(), rad(16 ether));
        assertEq(vat.vice(), rad(16 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(gem("gold", urn1), 7 ether);
        ali.exit(gold.gemA, address(this), 7 ether);

        vm.warp(block.timestamp + 1 hours);
        end.thaw();
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // dai redemption
        claimToken.mint(address(ali), rad(16 ether));
        ali.approveClaim(address(end), rad(16 ether));
        ali.pack(16 ether);

        // global checks:
        assertEq(vat.debt(), rad(16 ether));
        assertEq(vat.vice(), rad(16 ether));
        assertEq(vat.sin(address(vow)), rad(16 ether));
        assertEq(claimToken.balanceOf(address(ali)), 0);


        ali.cash("gold", 16 ether);

        // local checks:
        assertEq(dai(urn1), 16 ether);
        assertEq(gem("gold", urn1), 3 ether);
        ali.exit(gold.gemA, address(this), 3 ether);

        assertEq(gem("gold", address(end)), 0);
        assertEq(balanceOf("gold", address(gold.gemA)), 0);
    }

    // -- Scenario where there is one over-collateralised CDP
    // -- and one under-collateralised CDP and there is a
    // -- surplus in the Vow
    function testCageUndercollateralisedSurplus() public {
        Ilk memory gold = init_collateral("gold");

        Usr ali = new Usr(vat, end);
        Usr bob = new Usr(vat, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.join(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 gem, 10 ink, 15 tab, 15 dai
        // alive gives one dai to the vow, creating surplus
        ali.move(address(ali), address(vow), rad(1 ether));

        // make a second CDP:
        address urn2 = address(bob);
        gold.gemA.join(urn2, 1 ether);
        bob.frob("gold", urn2, urn2, urn2, 1 ether, 3 ether);
        // bob's urn has 0 gem, 1 ink, 3 tab, 3 dai

        // global checks:
        assertEq(vat.debt(), rad(18 ether));
        assertEq(vat.vice(), 0);

        // collateral price is 2
        gold.pip.poke(bytes32(2 * WAD));
        end.cage();
        end.cage("gold");
        end.skim("gold", urn1);  // over-collateralised
        end.skim("gold", urn2);  // under-collateralised

        // local checks
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 2.5 ether);
        assertEq(art("gold", urn2), 0);
        assertEq(ink("gold", urn2), 0);
        assertEq(vat.sin(address(vow)), rad(18 ether));

        // global checks
        assertEq(vat.debt(), rad(18 ether));
        assertEq(vat.vice(), rad(18 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(gem("gold", urn1), 2.5 ether);
        ali.exit(gold.gemA, address(this), 2.5 ether);

        vm.warp(block.timestamp + 1 hours);
        // balance the vow
        vow.heal(rad(1 ether));
        end.thaw();
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // first dai redemption
        claimToken.mint(address(ali), rad(14 ether));
        ali.approveClaim(address(end), rad(14 ether));
        ali.pack(14 ether);

        // global checks:
        assertEq(vat.debt(), rad(17 ether));
        assertEq(vat.vice(), rad(17 ether));

        ali.cash("gold", 14 ether);

        // local checks:
        assertEq(dai(urn1), 14 ether);
        uint256 fix = end.fix("gold");
        assertEq(gem("gold", urn1), rmul(fix, 14 ether));
        ali.exit(gold.gemA, address(this), rmul(fix, 14 ether));

        // second dai redemption
        claimToken.mint(address(bob), rad(16 ether));
        bob.approveClaim(address(end), rad(16 ether));
        bob.pack(3 ether);

        // global checks:
        assertEq(vat.debt(), rad(17 ether));
        assertEq(vat.vice(), rad(17 ether));

        bob.cash("gold", 3 ether);

        // local checks:
        assertEq(dai(urn2), 3 ether);
        assertEq(gem("gold", urn2), rmul(fix, 3 ether));
        bob.exit(gold.gemA, address(this), rmul(fix, 3 ether));

        // nothing left in the End
        assertEq(gem("gold", address(end)), 0);
        assertEq(balanceOf("gold", address(gold.gemA)), 0);
    }

    // -- Scenario where there is one over-collateralised and one
    // -- under-collateralised CDP of different collateral types
    // -- and no Vow deficit or surplus
    function testCageNetUndercollateralisedMultipleIlks() public {
        Ilk memory gold = init_collateral("gold");
        Ilk memory coal = init_collateral("coal");

        Usr ali = new Usr(vat, end);
        Usr bob = new Usr(vat, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.join(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 gem, 10 ink, 15 tab

        // make a second CDP:
        address urn2 = address(bob);
        coal.gemA.join(urn2, 1 ether);
        vat.file("coal", "spot", ray(5 ether));
        bob.frob("coal", urn2, urn2, urn2, 1 ether, 5 ether);
        // bob's urn has 0 gem, 1 ink, 5 tab

        gold.pip.poke(bytes32(2 * WAD));
        // urn1 has 20 dai of ink and 15 dai of tab
        coal.pip.poke(bytes32(2 * WAD));
        // urn2 has 2 dai of ink and 5 dai of tab
        end.cage();
        end.cage("gold");
        end.cage("coal");
        end.skim("gold", urn1);  // over-collateralised
        end.skim("coal", urn2);  // under-collateralised

        vm.warp(block.timestamp + 1 hours);
        end.thaw();
        end.flow("gold");
        end.flow("coal");

        claimToken.mint(address(ali), rad(1000 ether));
        ali.approveClaim(address(end), type(uint256).max);
        claimToken.mint(address(bob), rad(1000 ether));
        bob.approveClaim(address(end), type(uint256).max);

        assertEq(vat.debt(),             rad(20 ether));
        assertEq(vat.vice(),             rad(20 ether));
        assertEq(vat.sin(address(vow)),  rad(20 ether));

        assertEq(end.Art("gold"), 15 ether);
        assertEq(end.Art("coal"),  5 ether);

        assertEq(end.gap("gold"),  0.0 ether);
        assertEq(end.gap("coal"),  1.5 ether);

        // there are 7.5 gold and 1 coal
        // the gold is worth 15 dai and the coal is worth 2 dai
        // the total collateral pool is worth 17 dai
        // the total outstanding debt is 20 dai
        // each dai should get (15/2)/20 gold and (2/2)/20 coal
        assertEq(end.fix("gold"), ray(0.375 ether));
        assertEq(end.fix("coal"), ray(0.050 ether));

        assertEq(gem("gold", address(ali)), 0 ether);
        ali.pack(1 ether);
        ali.cash("gold", 1 ether);
        assertEq(gem("gold", address(ali)), 0.375 ether);

        bob.pack(1 ether);
        bob.cash("coal", 1 ether);
        assertEq(gem("coal", address(bob)), 0.05 ether);

        ali.exit(gold.gemA, address(ali), 0.375 ether);
        bob.exit(coal.gemA, address(bob), 0.05  ether);
        ali.pack(1 ether);
        ali.cash("gold", 1 ether);
        ali.cash("coal", 1 ether);
        assertEq(gem("gold", address(ali)), 0.375 ether);
        assertEq(gem("coal", address(ali)), 0.05 ether);

        ali.exit(gold.gemA, address(ali), 0.375 ether);
        ali.exit(coal.gemA, address(ali), 0.05  ether);

        ali.pack(1 ether);
        ali.cash("gold", 1 ether);
        assertEq(end.out("gold", address(ali)), 3 ether);
        assertEq(end.out("coal", address(ali)), 1 ether);
        ali.pack(1 ether);
        ali.cash("coal", 1 ether);
        assertEq(end.out("gold", address(ali)), 3 ether);
        assertEq(end.out("coal", address(ali)), 2 ether);
        assertEq(gem("gold", address(ali)), 0.375 ether);
        assertEq(gem("coal", address(ali)), 0.05 ether);
    }

    // -- Scenario where flow() used to overflow
    function testOverflow() public {
        Ilk memory gold = init_collateral("gold");

        Usr ali = new Usr(vat, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.join(urn1, 500_000 ether);
        ali.frob("gold", urn1, urn1, urn1, 500_000 ether, 1_000_000 ether);
        // ali's urn has 500_000 ink, 10^6 art (and 10^6 dai since rate == RAY)

        // global checks:
        assertEq(vat.debt(), rad(1_000_000 ether));
        assertEq(vat.vice(), 0);

        // collateral price is 5
        gold.pip.poke(bytes32(5 * WAD));
        end.cage();
        end.cage("gold");
        end.skim("gold", urn1);

        // local checks:
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 300_000 ether);
        assertEq(vat.sin(address(vow)), rad(1_000_000 ether));

        // global checks:
        assertEq(vat.debt(), rad(1_000_000 ether));
        assertEq(vat.vice(), rad(1_000_000 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(gem("gold", urn1), 300_000 ether);
        ali.exit(gold.gemA, address(this), 300_000 ether);

        vm.warp(block.timestamp + 1 hours);
        end.thaw();
        end.flow("gold");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mul(x, WAD) / y;
    }
    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mul(x, RAY) / y;
    }
    function fix_calc_0(uint256 col, uint256 debt) internal pure returns (uint256) {
        return rdiv(mul(col, RAY), debt);
    }
    function fix_calc_1(uint256 col, uint256 debt) internal pure returns (uint256) {
        return wdiv(mul(col, RAY), (debt / 10**9));
    }
    function fix_calc_2(uint256 col, uint256 debt) internal pure returns (uint256) {
        return mul(col, RAY) / (debt / RAY);
    }
    function wAssertCloseEnough(uint256 x, uint256 y) internal {
        uint256 diff = x > y ? x - y : y - x;
        if (diff == 0) return;
        uint256 xErr = mul(diff, WAD) / x;
        uint256 yErr = mul(diff, WAD) / y;
        uint256 err  = xErr > yErr ? xErr : yErr;
        assertTrue(err < WAD / 100_000_000);  // Error no more than one part in a hundred million
    }
    uint256 constant MIN_DEBT   = 10**6 * RAD;  // Minimum debt for fuzz runs
    uint256 constant REDEEM_AMT = 1_000 * WAD;  // Amount of DAI to redeem for error checking
    function testFuzzFixCalcs_0_1(uint256 col_seed, uint192 debt_seed) public {
        uint256 col = col_seed % (115792 * WAD);  // somewhat biased, but not enough to matter
        if (col < 10**12) col += 10**12;  // At least 10^-6 WAD units of collateral; this makes the fixes almost always non-zero.
        uint256 debt = debt_seed;
        if (debt < MIN_DEBT) debt += MIN_DEBT;  // consider at least MIN_DEBT of debt

        uint256 fix0 = fix_calc_0(col, debt);
        uint256 fix1 = fix_calc_1(col, debt);

        // how much collateral can be obtained with a single DAI in each case
        uint256 col0 = rmul(REDEEM_AMT, fix0);
        uint256 col1 = rmul(REDEEM_AMT, fix1);

        // Assert on percentage error of returned collateral
        wAssertCloseEnough(col0, col1);
    }
    function testFuzzFixCalcs_0_2(uint256 col_seed, uint192 debt_seed) public {
        uint256 col = col_seed % (115792 * WAD);  // somewhat biased, but not enough to matter
        if (col < 10**12) col += 10**12;  // At least 10^-6 WAD units of collateral; this makes the fixes almost always non-zero.
        uint256 debt = debt_seed;
        if (debt < MIN_DEBT) debt += MIN_DEBT;  // consider at least MIN_DEBT of debt

        uint256 fix0 = fix_calc_0(col, debt);
        uint256 fix2 = fix_calc_2(col, debt);

        // how much collateral can be obtained with a single DAI in each case
        uint256 col0 = rmul(REDEEM_AMT, fix0);
        uint256 col2 = rmul(REDEEM_AMT, fix2);

        // Assert on percentage error of returned collateral
        wAssertCloseEnough(col0, col2);
    }
    function testFuzzFixCalcs_1_2(uint256 col_seed, uint192 debt_seed) public {
        uint256 col = col_seed % (10**14 * WAD);  // somewhat biased, but not enough to matter
        if (col < 10**12) col += 10**12;  // At least 10^-6 WAD units of collateral; this makes the fixes almost always non-zero.
        uint256 debt = debt_seed;
        if (debt < MIN_DEBT) debt += MIN_DEBT;  // consider at least MIN_DEBT of debt

        uint256 fix1 = fix_calc_1(col, debt);
        uint256 fix2 = fix_calc_2(col, debt);

        // how much collateral can be obtained with a single DAI in each case
        uint256 col1 = rmul(REDEEM_AMT, fix1);
        uint256 col2 = rmul(REDEEM_AMT, fix2);

        // Assert on percentage error of returned collateral
        wAssertCloseEnough(col1, col2);
    }
}
