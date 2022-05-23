// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Efficient bitmap library for mapping integers to single bit booleans.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/LibBitmap.sol)
library LibBitmap {
    struct Bitmap {
        mapping(uint256 => uint256) map;
    }

    function get(Bitmap storage bitmap, uint256 index) internal view returns (bool isSet) {
        uint256 value = bitmap.map[index >> 8] & (1 << (index & 0xff));

        assembly {
            isSet := value // Assign isSet to whether the value is non zero.
        }
    }

    function set(Bitmap storage bitmap, uint256 index) internal {
        bitmap.map[index >> 8] |= (1 << (index & 0xff));
    }

    function unset(Bitmap storage bitmap, uint256 index) internal {
        bitmap.map[index >> 8] &= ~(1 << (index & 0xff));
    }

    function setTo(
        Bitmap storage bitmap,
        uint256 index,
        bool shouldSet
    ) internal {
        uint256 value = bitmap.map[index >> 8];

        assembly {
            // Set the bit at `shift` without branching.
            let shift := and(index, 0xff)
            value := xor(value, shl(shift, xor(and(shr(shift, value), 1), shouldSet)))
        }
        bitmap.map[index >> 8] = value;
    }
}
