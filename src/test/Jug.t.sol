// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "dss-test/DSSTest.sol";

import {Jug} from "../Jug.sol";
import {Vat} from "../Vat.sol";

interface VatLike {
    function ilks(bytes32) external view returns (
        uint256 Art,
        uint256 rate,
        uint256 spot,
        uint256 line,
        uint256 dust
    );
}

contract Rpow is Jug {

    constructor(address vat_) Jug(vat_){}

    function pRpow(uint x, uint n, uint b) public pure returns(uint) {
        return _rpow(x, n, b);
    }

}


contract JugTest is DSSTest {
    
    Jug jug;
    Vat vat;

    bytes32 constant ILK = "SOME-ILK-A";

    event Init(bytes32 indexed ilk);
    event File(bytes32 indexed ilk, bytes32 indexed what, uint256 data);
    event Drip(bytes32 indexed ilk);

    function duty(bytes32 ilk) internal view returns (uint256 duty_) {
        (duty_,) = jug.ilks(ilk);
    }

    function rho(bytes32 ilk) internal view returns (uint256 rho_) {
        (, rho_) = jug.ilks(ilk);
    }

    function postSetup() internal virtual override {
        vat  = new Vat();
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        jug = new Jug(address(vat));
        vat.rely(address(jug));
        vat.init(ILK);

        vat.file("Line", 100 * RAD);
        vat.file(ILK, "line", 100 * RAD);
        vat.file(ILK, "spot", RAY);
        vat.slip(ILK, address(this), int256(100 * WAD));
        vat.frob(ILK, address(this), address(this), address(this), int256(100 * WAD), int256(100 * WAD));
    }

    function testConstructor() public {
        assertEq(address(jug.vat()), address(vat));
        assertEq(jug.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(jug), "Jug");
    }

    function testFile() public {
        checkFileUint(address(jug), "Jug", ["base"]);
        checkFileAddress(address(jug), "Jug", ["vow"]);
    }

    function testFileIlk() public {
        jug.init(ILK);

        vm.expectEmit(true, true, true, true);
        emit File(ILK, "duty", 1);
        jug.file(ILK, "duty", 1);
        assertEq(duty(ILK), 1);

        // Cannot set duty if rho not up to date
        vm.warp(block.timestamp + 1);
        vm.expectRevert("Jug/rho-not-updated");
        jug.file(ILK, "duty", 1);
        vm.warp(block.timestamp - 1);

        // Invalid name
        vm.expectRevert("Jug/file-unrecognized-param");
        jug.file(ILK, "badWhat", 1);

        // Not authed
        jug.deny(address(this));
        vm.expectRevert("Jug/not-authorized");
        jug.file(ILK, "duty", 1);
    }

    function testInit() public {
        assertEq(rho(ILK), 0);
        assertEq(duty(ILK), 0);

        vm.expectEmit(true, true, true, true);
        emit Init(ILK);
        jug.init(ILK);

        assertEq(rho(ILK), block.timestamp);
        assertEq(duty(ILK), RAY);
    }

    function testDripUpdatesRho() public {
        jug.init(ILK);

        jug.file(ILK, "duty", 10 ** 27);
        jug.drip(ILK);
        assertEq(rho(ILK), block.timestamp);
        vm.warp(block.timestamp + 1);
        assertEq(rho(ILK), block.timestamp - 1);
        jug.drip(ILK);
        assertEq(rho(ILK), block.timestamp);
        vm.warp(block.timestamp + 1 days);
        jug.drip(ILK);
        assertEq(rho(ILK), block.timestamp);
    }

    function testDripFile() public {
        jug.init(ILK);
        jug.file(ILK, "duty", RAY);
        jug.drip(ILK);
        jug.file(ILK, "duty", 1000000564701133626865910626);  // 5% / day
    }

    function testDrip0d() public {
        jug.init(ILK);
        jug.file(ILK, "duty", 1000000564701133626865910626);  // 5% / day
        assertEq(vat.dai(TEST_ADDRESS), 0);
        jug.drip(ILK);
        assertEq(vat.dai(TEST_ADDRESS), 0);
    }

    function testDrip1d() public {
        jug.init(ILK);
        jug.file("vow", TEST_ADDRESS);

        jug.file(ILK, "duty", 1000000564701133626865910626);  // 5% / day
        vm.warp(block.timestamp + 1 days);
        assertEq(vat.dai(TEST_ADDRESS), 0 ether);
        jug.drip(ILK);
        assertEq(vat.dai(TEST_ADDRESS), 5000000000000000000001603800000000000000000000);
    }

    function testDrip2d() public {
        jug.init(ILK);
        jug.file("vow", TEST_ADDRESS);
        jug.file(ILK, "duty", 1000000564701133626865910626);  // 5% / day

        vm.warp(block.timestamp + 2 days);
        assertEq(vat.dai(TEST_ADDRESS), 0 ether);
        jug.drip(ILK);
        assertEq(vat.dai(TEST_ADDRESS), 10250000000000000000003367800000000000000000000);
    }

    function testDrip3d() public {
        jug.init(ILK);
        jug.file("vow", TEST_ADDRESS);

        jug.file(ILK, "duty", 1000000564701133626865910626);  // 5% / day
        vm.warp(block.timestamp + 3 days);
        assertEq(vat.dai(TEST_ADDRESS), 0 ether);
        jug.drip(ILK);
        assertEq(vat.dai(TEST_ADDRESS), 15762500000000000000005304200000000000000000000);
    }

    function testDripNegative3d() public {
        jug.init(ILK);
        jug.file("vow", TEST_ADDRESS);

        jug.file(ILK, "duty", 999999706969857929985428567);  // -2.5% / day
        vm.warp(block.timestamp + 3 days);
        assertEq(vat.dai(address(this)), 100 * RAD);
        vat.move(address(this), TEST_ADDRESS, 100 * RAD);
        assertEq(vat.dai(TEST_ADDRESS), 100 * RAD);
        jug.drip(ILK);
        assertEq(vat.dai(TEST_ADDRESS), 92685937500000000000002288500000000000000000000);
    }

    function testDripMulti() public {
        jug.init(ILK);
        jug.file("vow", TEST_ADDRESS);

        jug.file(ILK, "duty", 1000000564701133626865910626);  // 5% / day
        vm.warp(block.timestamp + 1 days);
        jug.drip(ILK);
        assertEq(vat.dai(TEST_ADDRESS), 5000000000000000000001603800000000000000000000);
        jug.file(ILK, "duty", 1000001103127689513476993127);  // 10% / day
        vm.warp(block.timestamp + 1 days);
        jug.drip(ILK);
        assertEq(vat.dai(TEST_ADDRESS), 15500000000000000000006151700000000000000000000);
        assertEq(vat.debt(), 115500000000000000000006151700000000000000000000);
        assertEq(vat.rate(ILK) / 10 ** 9, 1.155 ether);
    }

    function testDripBase() public {
        jug.init(ILK);
        jug.file("vow", TEST_ADDRESS);

        jug.file(ILK, "duty", 1050000000000000000000000000);  // 5% / second
        jug.file("base", uint256(50000000000000000000000000)); // 5% / second
        vm.warp(block.timestamp + 1);
        jug.drip(ILK);
        assertEq(vat.dai(TEST_ADDRESS), 10 * RAD);
    }

    function testRpow() public {
        Rpow r = new Rpow(address(vat));
        uint result = r.pRpow(uint256(1000234891009084238901289093), uint256(3724), uint256(1e27));
        // python calc = 2.397991232255757e27 = 2397991232255757e12
        // expect 10 decimal precision
        assertEq(result / uint256(1e17), uint256(2397991232255757e12) / 1e17);
    }

}
