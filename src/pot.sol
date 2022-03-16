// SPDX-License-Identifier: AGPL-3.0-or-later

/// pot.sol -- Dai Savings Rate

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.12;

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

/*
   "Savings Dai" is obtained when Dai is deposited into
   this contract. Each "Savings Dai" accrues Dai interest
   at the "Dai Savings Rate".

   This contract does not implement a user tradeable token
   and is intended to be used with adapters.

         --- `save` your `dai` in the `pot` ---

   - `dsr`: the Dai Savings Rate
   - `pie`: user balance of Savings Dai

   - `join`: start saving some dai
   - `exit`: remove some dai
   - `drip`: perform rate collection

*/

interface VatLike {
    function move(address,address,uint256) external;
    function suck(address,address,uint256) external;
}

contract Pot {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Pot/not-authorized");
        _;
    }

    // --- Data ---
    mapping (address => uint256) public pie;  // Normalised Savings Dai [wad]

    uint256 public Pie;   // Total Normalised Savings Dai  [wad]
    uint256 public dsr;   // The Dai Savings Rate          [ray]
    uint256 public chi;   // The Rate Accumulator          [ray]

    bytes32        a;     // Don't change the storage layout for now
    address public vow;   // Debt Engine
    uint256 public rho;   // Time of last drip     [unix epoch time]

    uint256 public live;  // Active Flag

    VatLike public immutable vat;   // CDP Engine

    // --- Init ---
    constructor(address vat_) {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        dsr = RAY;
        chi = RAY;
        rho = block.timestamp;
        live = 1;
    }

    // --- Math ---
    uint256 constant RAY = 10 ** 27;
    function rpow(uint256 x, uint256 n, uint256 base) internal pure returns (uint256 z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, base)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y / RAY;
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        require(live == 1, "Pot/not-live");
        require(block.timestamp == rho, "Pot/rho-not-updated");
        if (what == "dsr") dsr = data;
        else revert("Pot/file-unrecognized-param");
    }

    function file(bytes32 what, address addr) external auth {
        if (what == "vow") vow = addr;
        else revert("Pot/file-unrecognized-param");
    }

    function cage() external auth {
        live = 0;
        dsr = RAY;
    }

    // --- Savings Rate Accumulation ---
    function drip() external returns (uint256 tmp) {
        tmp = rmul(rpow(dsr, block.timestamp - rho, RAY), chi);
        uint256 chi_ = tmp - chi;
        chi = tmp;
        rho = block.timestamp;
        vat.suck(address(vow), address(this), Pie * chi_);
    }

    // --- Savings Dai Management ---
    function join(uint256 wad) external {
        require(block.timestamp == rho, "Pot/rho-not-updated");
        pie[msg.sender] = pie[msg.sender] + wad;
        Pie             = Pie             + wad;
        vat.move(msg.sender, address(this), chi * wad);
    }

    function exit(uint256 wad) external {
        pie[msg.sender] = pie[msg.sender] - wad;
        Pie             = Pie             - wad;
        vat.move(address(this), msg.sender, chi * wad);
    }
}
