// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

interface IERC1271 {
    function isValidSignature(
        bytes32,
        bytes memory
    ) external view returns (bytes4);
}

contract SignerMock is IERC1271 {
    function isValidSignature(bytes32, bytes memory) external view returns (bytes4 sig) {
        if (block.timestamp % 2 == 0) {
            sig = IERC1271.isValidSignature.selector;
        }
    }
}
