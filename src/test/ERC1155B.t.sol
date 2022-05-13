// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {DSInvariantTest} from "./utils/DSInvariantTest.sol";

import {MockERC1155B} from "./utils/mocks/MockERC1155B.sol";
import {ERC1155BUser} from "./utils/users/ERC1155BUser.sol";

import {ERC1155TokenReceiver} from "../tokens/ERC1155.sol";

// TODO: test invalid_amount errors
// TODO: test ownerOf()
// TODO: fuzz testing
// TODO: test custom safe batch transfer
// TODO: test cant burn unminted tokens

contract ERC1155BRecipient is ERC1155TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    uint256 public amount;
    bytes public mintData;

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) public override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        amount = _amount;
        mintData = _data;

        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    address public batchOperator;
    address public batchFrom;
    uint256[] internal _batchIds;
    uint256[] internal _batchAmounts;
    bytes public batchData;

    function batchIds() external view returns (uint256[] memory) {
        return _batchIds;
    }

    function batchAmounts() external view returns (uint256[] memory) {
        return _batchAmounts;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external override returns (bytes4) {
        batchOperator = _operator;
        batchFrom = _from;
        _batchIds = _ids;
        _batchAmounts = _amounts;
        batchData = _data;

        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

contract RevertingERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        revert(string(abi.encodePacked(ERC1155TokenReceiver.onERC1155Received.selector)));
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        revert(string(abi.encodePacked(ERC1155TokenReceiver.onERC1155BatchReceived.selector)));
    }
}

contract WrongReturnDataERC1155BRecipient is ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        return 0xCAFEBEEF;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC1155BRecipient {}

contract ERC1155BTest is DSTestPlus, ERC1155TokenReceiver {
    MockERC1155B token;

    mapping(address => mapping(uint256 => uint256)) public userMintAmounts;
    mapping(address => mapping(uint256 => uint256)) public userTransferOrBurnAmounts;

    function setUp() public {
        token = new MockERC1155B();
    }

    function testMintToEOA() public {
        token.mint(address(0xBEEF), 1337, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
    }

    function testMintToERC1155Recipient() public {
        ERC1155BRecipient to = new ERC1155BRecipient();

        token.mint(address(to), 1337, "testing 123");

        assertEq(token.balanceOf(address(to), 1337), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.mintData(), "testing 123");
    }

    function testBatchMintToEOA() public {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.batchMint(address(0xBEEF), ids, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.balanceOf(address(0xBEEF), 1338), 1);
        assertEq(token.balanceOf(address(0xBEEF), 1339), 1);
        assertEq(token.balanceOf(address(0xBEEF), 1340), 1);
        assertEq(token.balanceOf(address(0xBEEF), 1341), 1);
    }

    function testBatchMintToERC1155Recipient() public {
        ERC1155BRecipient to = new ERC1155BRecipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;
        amounts[4] = 1;

        token.batchMint(address(to), ids, "testing 123");

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), address(0));
        assertUintArrayEq(to.batchIds(), ids);
        assertUintArrayEq(to.batchAmounts(), amounts);
        assertBytesEq(to.batchData(), "testing 123");

        assertEq(token.balanceOf(address(to), 1337), 1);
        assertEq(token.balanceOf(address(to), 1338), 1);
        assertEq(token.balanceOf(address(to), 1339), 1);
        assertEq(token.balanceOf(address(to), 1340), 1);
        assertEq(token.balanceOf(address(to), 1341), 1);
    }

    function testBurn() public {
        token.mint(address(0xBEEF), 1337, "");

        token.burn(1337);

        assertEq(token.balanceOf(address(0xBEEF), 1337), 0);
    }

    function testBatchBurn() public {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.batchMint(address(0xBEEF), ids, "");

        token.batchBurn(address(0xBEEF), ids);

        assertEq(token.balanceOf(address(0xBEEF), 1337), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1338), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1339), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1340), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1341), 0);
    }

    function testApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);

        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function testSafeTransferFromToEOA() public {
        ERC1155BUser from = new ERC1155BUser(token);

        token.mint(address(from), 1337, "");

        from.setApprovalForAll(address(this), true);

        token.safeTransferFrom(address(from), address(0xBEEF), 1337, 1, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.balanceOf(address(from), 1337), 0);
    }

    function testSafeTransferFromToERC1155Recipient() public {
        ERC1155BRecipient to = new ERC1155BRecipient();

        ERC1155BUser from = new ERC1155BUser(token);

        token.mint(address(from), 1337, "");

        from.setApprovalForAll(address(this), true);

        token.safeTransferFrom(address(from), address(to), 1337, 1, "testing 123");

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(from));
        assertEq(to.id(), 1337);
        assertBytesEq(to.mintData(), "testing 123");

        assertEq(token.balanceOf(address(to), 1337), 1);
        assertEq(token.balanceOf(address(from), 1337), 0);
    }

    function testSafeTransferFromSelf() public {
        token.mint(address(this), 1337, "");

        token.safeTransferFrom(address(this), address(0xBEEF), 1337, 1, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.balanceOf(address(this), 1337), 0);
    }

    function testSafeBatchTransferFromToEOA() public {
        ERC1155BUser from = new ERC1155BUser(token);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(address(from), ids, "");

        from.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(address(from), address(0xBEEF), ids, transferAmounts, "");

        assertEq(token.balanceOf(address(from), 1337), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);

        assertEq(token.balanceOf(address(from), 1338), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1338), 1);

        assertEq(token.balanceOf(address(from), 1339), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1339), 1);

        assertEq(token.balanceOf(address(from), 1340), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1340), 1);

        assertEq(token.balanceOf(address(from), 1341), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1341), 1);
    }

    function testSafeBatchTransferFromToERC1155Recipient() public {
        ERC1155BUser from = new ERC1155BUser(token);

        ERC1155BRecipient to = new ERC1155BRecipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(address(from), ids, "");

        from.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(address(from), address(to), ids, transferAmounts, "testing 123");

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), address(from));
        assertUintArrayEq(to.batchIds(), ids);
        assertUintArrayEq(to.batchAmounts(), transferAmounts);
        assertBytesEq(to.batchData(), "testing 123");

        assertEq(token.balanceOf(address(from), 1337), 0);
        assertEq(token.balanceOf(address(to), 1337), 1);

        assertEq(token.balanceOf(address(from), 1338), 0);
        assertEq(token.balanceOf(address(to), 1338), 1);

        assertEq(token.balanceOf(address(from), 1339), 0);
        assertEq(token.balanceOf(address(to), 1339), 1);

        assertEq(token.balanceOf(address(from), 1340), 0);
        assertEq(token.balanceOf(address(to), 1340), 1);

        assertEq(token.balanceOf(address(from), 1341), 0);
        assertEq(token.balanceOf(address(to), 1341), 1);
    }

    function testBatchBalanceOf() public {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.mint(address(0xBEEF), 1337, "");
        token.mint(address(0xCAFE), 1338, "");
        token.mint(address(0xFACE), 1339, "");
        token.mint(address(0xDEAD), 1340, "");
        token.mint(address(0xFEED), 1341, "");

        uint256[] memory balances = token.balanceOfBatch(tos, ids);

        assertEq(balances[0], 1);
        assertEq(balances[1], 1);
        assertEq(balances[2], 1);
        assertEq(balances[3], 1);
        assertEq(balances[4], 1);
    }

    function testFailMintToZero() public {
        token.mint(address(0), 1337, "");
    }

    function testFailMintToNonERC1155Recipient() public {
        token.mint(address(new NonERC1155BRecipient()), 1337, "");
    }

    function testFailMintToRevertingERC1155Recipient() public {
        token.mint(address(new RevertingERC1155Recipient()), 1337, "");
    }

    function testFailMintToWrongReturnDataERC1155Recipient() public {
        token.mint(address(new RevertingERC1155Recipient()), 1337, "");
    }

    function testFailBurnInsufficientBalance() public {
        token.burn(1337);
    }

    function testFailSafeTransferFromInsufficientBalance() public {
        ERC1155BUser from = new ERC1155BUser(token);

        from.setApprovalForAll(address(this), true);

        token.safeTransferFrom(address(from), address(0xBEEF), 1337, 1, "");
    }

    function testFailSafeTransferFromSelfInsufficientBalance() public {
        token.safeTransferFrom(address(this), address(0xBEEF), 1337, 1, "");
    }

    function testFailSafeTransferFromToZero() public {
        token.safeTransferFrom(address(this), address(0), 1337, 1, "");
    }

    function testFailSafeTransferFromToNonERC1155Recipient() public {
        token.mint(address(this), 1337, "");
        token.safeTransferFrom(address(this), address(new NonERC1155BRecipient()), 1337, 1, "");
    }

    function testFailSafeTransferFromToRevertingERC1155Recipient() public {
        token.mint(address(this), 1337, "");
        token.safeTransferFrom(address(this), address(new RevertingERC1155Recipient()), 1337, 1, "");
    }

    function testFailSafeTransferFromToWrongReturnDataERC1155Recipient() public {
        token.mint(address(this), 1337, "");
        token.safeTransferFrom(address(this), address(new WrongReturnDataERC1155BRecipient()), 1337, 1, "");
    }

    function testFailSafeBatchTransferInsufficientBalance() public {
        ERC1155BUser from = new ERC1155BUser(token);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        from.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(address(from), address(0xBEEF), ids, transferAmounts, "");
    }

    function testFailSafeBatchTransferFromToZero() public {
        ERC1155BUser from = new ERC1155BUser(token);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(address(from), ids, "");

        from.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(address(from), address(0), ids, transferAmounts, "");
    }

    function testFailSafeBatchTransferFromToNonERC1155Recipient() public {
        ERC1155BUser from = new ERC1155BUser(token);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(address(from), ids, "");

        from.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(address(from), address(new NonERC1155BRecipient()), ids, transferAmounts, "");
    }

    function testFailSafeBatchTransferFromToRevertingERC1155Recipient() public {
        ERC1155BUser from = new ERC1155BUser(token);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(address(from), ids, "");

        from.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(address(from), address(new RevertingERC1155Recipient()), ids, transferAmounts, "");
    }

    function testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient() public {
        ERC1155BUser from = new ERC1155BUser(token);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(address(from), ids, "");

        from.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(
            address(from),
            address(new WrongReturnDataERC1155BRecipient()),
            ids,
            transferAmounts,
            ""
        );
    }

    function testFailSafeBatchTransferFromWithArrayLengthMismatch() public {
        ERC1155BUser from = new ERC1155BUser(token);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory transferAmounts = new uint256[](4);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;

        token.batchMint(address(from), ids, "");

        from.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(address(from), address(0xBEEF), ids, transferAmounts, "");
    }

    function testFailBatchMintToZero() public {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.batchMint(address(0), ids, "");
    }

    function testFailBatchMintToNonERC1155Recipient() public {
        NonERC1155BRecipient to = new NonERC1155BRecipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.batchMint(address(to), ids, "");
    }

    function testFailBatchMintToRevertingERC1155Recipient() public {
        RevertingERC1155Recipient to = new RevertingERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.batchMint(address(to), ids, "");
    }

    function testFailBatchMintToWrongReturnDataERC1155Recipient() public {
        WrongReturnDataERC1155BRecipient to = new WrongReturnDataERC1155BRecipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.batchMint(address(to), ids, "");
    }

    function testFailBatchBurnInsufficientBalance() public {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.batchBurn(address(0xBEEF), ids);
    }

    function testFailBalanceOfBatchWithArrayMismatch() public view {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](4);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;

        token.balanceOfBatch(tos, ids);
    }

    // function testMintToEOA(
    //     address to,
    //     uint256 id,
    //     uint256 amount,
    //     bytes memory mintData
    // ) public {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     token.mint(to, id, amount, mintData);

    //     assertEq(token.balanceOf(to, id), amount);
    // }

    // function testMintToERC1155Recipient(
    //     uint256 id,
    //     uint256 amount,
    //     bytes memory mintData
    // ) public {
    //     ERC1155BRecipient to = new ERC1155BRecipient();

    //     token.mint(address(to), id, amount, mintData);

    //     assertEq(token.balanceOf(address(to), id), amount);

    //     assertEq(to.operator(), address(this));
    //     assertEq(to.from(), address(0));
    //     assertEq(to.id(), id);
    //     assertBytesEq(to.mintData(), mintData);
    // }

    // function testBatchMintToEOA(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) public {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[to][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[to][id] += mintAmount;
    //     }

    //     token.batchMint(to, normalizedIds, normalizedAmounts, mintData);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];

    //         assertEq(token.balanceOf(to, id), userMintAmounts[to][id]);
    //     }
    // }

    // function testBatchMintToERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) public {
    //     ERC1155BRecipient to = new ERC1155BRecipient();

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(to)][id] += mintAmount;
    //     }

    //     token.batchMint(address(to), normalizedIds, normalizedAmounts, mintData);

    //     assertEq(to.batchOperator(), address(this));
    //     assertEq(to.batchFrom(), address(0));
    //     assertUintArrayEq(to.batchIds(), normalizedIds);
    //     assertUintArrayEq(to.batchAmounts(), normalizedAmounts);
    //     assertBytesEq(to.batchData(), mintData);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];

    //         assertEq(token.balanceOf(address(to), id), userMintAmounts[address(to)][id]);
    //     }
    // }

    // function testBurn(
    //     address to,
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData,
    //     uint256 burnAmount
    // ) public {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     burnAmount = bound(burnAmount, 0, mintAmount);

    //     token.mint(to, id, mintAmount, mintData);

    //     token.burn(to, id, burnAmount);

    //     assertEq(token.balanceOf(address(to), id), mintAmount - burnAmount);
    // }

    // function testBatchBurn(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory burnAmounts,
    //     bytes memory mintData
    // ) public {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     uint256 minLength = min3(ids.length, mintAmounts.length, burnAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedBurnAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         normalizedBurnAmounts[i] = bound(burnAmounts[i], 0, normalizedMintAmounts[i]);

    //         userMintAmounts[address(to)][id] += normalizedMintAmounts[i];
    //         userTransferOrBurnAmounts[address(to)][id] += normalizedBurnAmounts[i];
    //     }

    //     token.batchMint(to, normalizedIds, normalizedMintAmounts, mintData);

    //     token.batchBurn(to, normalizedIds, normalizedBurnAmounts);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];

    //         assertEq(token.balanceOf(to, id), userMintAmounts[to][id] - userTransferOrBurnAmounts[to][id]);
    //     }
    // }

    // function testApproveAll(address to, bool approved) public {
    //     token.setApprovalForAll(to, approved);

    //     assertBoolEq(token.isApprovedForAll(address(this), to), approved);
    // }

    // function testSafeTransferFromToEOA(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData,
    //     uint256 transferAmount,
    //     address to,
    //     bytes memory transferData
    // ) public {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     ERC1155BUser from = new ERC1155BUser(token);

    //     token.mint(address(from), id, mintAmount, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeTransferFrom(address(from), to, id, transferAmount, transferData);

    //     assertEq(token.balanceOf(to, id), transferAmount);
    //     assertEq(token.balanceOf(address(from), id), mintAmount - transferAmount);
    // }

    // function testSafeTransferFromToERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData,
    //     uint256 transferAmount,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BRecipient to = new ERC1155BRecipient();

    //     ERC1155BUser from = new ERC1155BUser(token);

    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     token.mint(address(from), id, mintAmount, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeTransferFrom(address(from), address(to), id, transferAmount, transferData);

    //     assertEq(to.operator(), address(this));
    //     assertEq(to.from(), address(from));
    //     assertEq(to.id(), id);
    //     assertBytesEq(to.mintData(), transferData);

    //     assertEq(token.balanceOf(address(to), id), transferAmount);
    //     assertEq(token.balanceOf(address(from), id), mintAmount - transferAmount);
    // }

    // function testSafeTransferFromSelf(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData,
    //     uint256 transferAmount,
    //     address to,
    //     bytes memory transferData
    // ) public {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     token.mint(address(this), id, mintAmount, mintData);

    //     token.safeTransferFrom(address(this), to, id, transferAmount, transferData);

    //     assertEq(token.balanceOf(to, id), transferAmount);
    //     assertEq(token.balanceOf(address(this), id), mintAmount - transferAmount);
    // }

    // function testSafeBatchTransferFromToEOA(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     ERC1155BUser from = new ERC1155BUser(token);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(from)][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[address(from)][id] += mintAmount;
    //         userTransferOrBurnAmounts[address(from)][id] += transferAmount;
    //     }

    //     token.batchMint(address(from), normalizedIds, normalizedMintAmounts, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeBatchTransferFrom(address(from), to, normalizedIds, normalizedTransferAmounts, transferData);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];

    //         assertEq(token.balanceOf(address(to), id), userTransferOrBurnAmounts[address(from)][id]);
    //         assertEq(
    //             token.balanceOf(address(from), id),
    //             userMintAmounts[address(from)][id] - userTransferOrBurnAmounts[address(from)][id]
    //         );
    //     }
    // }

    // function testSafeBatchTransferFromToERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BUser from = new ERC1155BUser(token);

    //     ERC1155BRecipient to = new ERC1155BRecipient();

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(from)][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[address(from)][id] += mintAmount;
    //         userTransferOrBurnAmounts[address(from)][id] += transferAmount;
    //     }

    //     token.batchMint(address(from), normalizedIds, normalizedMintAmounts, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeBatchTransferFrom(address(from), address(to), normalizedIds, normalizedTransferAmounts, transferData);

    //     assertEq(to.batchOperator(), address(this));
    //     assertEq(to.batchFrom(), address(from));
    //     assertUintArrayEq(to.batchIds(), normalizedIds);
    //     assertUintArrayEq(to.batchAmounts(), normalizedTransferAmounts);
    //     assertBytesEq(to.batchData(), transferData);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];
    //         uint256 transferAmount = userTransferOrBurnAmounts[address(from)][id];

    //         assertEq(token.balanceOf(address(to), id), transferAmount);
    //         assertEq(token.balanceOf(address(from), id), userMintAmounts[address(from)][id] - transferAmount);
    //     }
    // }

    // function testBatchBalanceOf(
    //     address[] memory tos,
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) public {
    //     uint256 minLength = min3(tos.length, ids.length, amounts.length);

    //     address[] memory normalizedTos = new address[](minLength);
    //     uint256[] memory normalizedIds = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];
    //         address to = tos[i] == address(0) ? address(0xBEEF) : tos[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[to][id];

    //         normalizedTos[i] = to;
    //         normalizedIds[i] = id;

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         token.mint(to, id, mintAmount, mintData);

    //         userMintAmounts[to][id] += mintAmount;
    //     }

    //     uint256[] memory balances = token.balanceOfBatch(normalizedTos, normalizedIds);

    //     for (uint256 i = 0; i < normalizedTos.length; i++) {
    //         assertEq(balances[i], token.balanceOf(normalizedTos[i], normalizedIds[i]));
    //     }
    // }

    // function testFailMintToZero(
    //     uint256 id,
    //     uint256 amount,
    //     bytes memory data
    // ) public {
    //     token.mint(address(0), id, amount, data);
    // }

    // function testFailMintToNonERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData
    // ) public {
    //     token.mint(address(new NonERC1155BRecipient()), id, mintAmount, mintData);
    // }

    // function testFailMintToRevertingERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData
    // ) public {
    //     token.mint(address(new RevertingERC1155Recipient()), id, mintAmount, mintData);
    // }

    // function testFailMintToWrongReturnDataERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData
    // ) public {
    //     token.mint(address(new RevertingERC1155Recipient()), id, mintAmount, mintData);
    // }

    // function testFailBurnInsufficientBalance(
    //     address to,
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 burnAmount,
    //     bytes memory mintData
    // ) public {
    //     burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

    //     token.mint(to, id, mintAmount, mintData);
    //     token.burn(to, id, burnAmount);
    // }

    // function testFailSafeTransferFromInsufficientBalance(
    //     address to,
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BUser from = new ERC1155BUser(token);

    //     transferAmount = bound(transferAmount, mintAmount + 1, type(uint256).max);

    //     token.mint(address(from), id, mintAmount, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeTransferFrom(address(from), to, id, transferAmount, transferData);
    // }

    // function testFailSafeTransferFromSelfInsufficientBalance(
    //     address to,
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     transferAmount = bound(transferAmount, mintAmount + 1, type(uint256).max);

    //     token.mint(address(this), id, mintAmount, mintData);
    //     token.safeTransferFrom(address(this), to, id, transferAmount, transferData);
    // }

    // function testFailSafeTransferFromToZero(
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     token.mint(address(this), id, mintAmount, mintData);
    //     token.safeTransferFrom(address(this), address(0), id, transferAmount, transferData);
    // }

    // function testFailSafeTransferFromToNonERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     token.mint(address(this), id, mintAmount, mintData);
    //     token.safeTransferFrom(address(this), address(new NonERC1155BRecipient()), id, transferAmount, transferData);
    // }

    // function testFailSafeTransferFromToRevertingERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     token.mint(address(this), id, mintAmount, mintData);
    //     token.safeTransferFrom(
    //         address(this),
    //         address(new RevertingERC1155Recipient()),
    //         id,
    //         transferAmount,
    //         transferData
    //     );
    // }

    // function testFailSafeTransferFromToWrongReturnDataERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     token.mint(address(this), id, mintAmount, mintData);
    //     token.safeTransferFrom(
    //         address(this),
    //         address(new WrongReturnDataERC1155BRecipient()),
    //         id,
    //         transferAmount,
    //         transferData
    //     );
    // }

    // function testFailSafeBatchTransferInsufficientBalance(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BUser from = new ERC1155BUser(token);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     if (minLength == 0) revert();

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(from)][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], mintAmount + 1, type(uint256).max);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[address(from)][id] += mintAmount;
    //     }

    //     token.batchMint(address(from), normalizedIds, normalizedMintAmounts, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeBatchTransferFrom(address(from), to, normalizedIds, normalizedTransferAmounts, transferData);
    // }

    // function testFailSafeBatchTransferFromToZero(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BUser from = new ERC1155BUser(token);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(from)][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[address(from)][id] += mintAmount;
    //     }

    //     token.batchMint(address(from), normalizedIds, normalizedMintAmounts, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeBatchTransferFrom(address(from), address(0), normalizedIds, normalizedTransferAmounts, transferData);
    // }

    // function testFailSafeBatchTransferFromToNonERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BUser from = new ERC1155BUser(token);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(from)][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[address(from)][id] += mintAmount;
    //     }

    //     token.batchMint(address(from), normalizedIds, normalizedMintAmounts, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeBatchTransferFrom(
    //         address(from),
    //         address(new NonERC1155BRecipient()),
    //         normalizedIds,
    //         normalizedTransferAmounts,
    //         transferData
    //     );
    // }

    // function testFailSafeBatchTransferFromToRevertingERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BUser from = new ERC1155BUser(token);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(from)][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[address(from)][id] += mintAmount;
    //     }

    //     token.batchMint(address(from), normalizedIds, normalizedMintAmounts, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeBatchTransferFrom(
    //         address(from),
    //         address(new RevertingERC1155Recipient()),
    //         normalizedIds,
    //         normalizedTransferAmounts,
    //         transferData
    //     );
    // }

    // function testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BUser from = new ERC1155BUser(token);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(from)][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[address(from)][id] += mintAmount;
    //     }

    //     token.batchMint(address(from), normalizedIds, normalizedMintAmounts, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeBatchTransferFrom(
    //         address(from),
    //         address(new WrongReturnDataERC1155BRecipient()),
    //         normalizedIds,
    //         normalizedTransferAmounts,
    //         transferData
    //     );
    // }

    // function testFailSafeBatchTransferFromWithArrayLengthMismatch(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) public {
    //     ERC1155BUser from = new ERC1155BUser(token);

    //     if (ids.length == transferAmounts.length) revert();

    //     token.batchMint(address(from), ids, mintAmounts, mintData);

    //     from.setApprovalForAll(address(this), true);

    //     token.safeBatchTransferFrom(address(from), to, ids, transferAmounts, transferData);
    // }

    // function testFailBatchMintToZero(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) public {
    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(0)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(0)][id] += mintAmount;
    //     }

    //     token.batchMint(address(0), normalizedIds, normalizedAmounts, mintData);
    // }

    // function testFailBatchMintToNonERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) public {
    //     NonERC1155BRecipient to = new NonERC1155BRecipient();

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(to)][id] += mintAmount;
    //     }

    //     token.batchMint(address(to), normalizedIds, normalizedAmounts, mintData);
    // }

    // function testFailBatchMintToRevertingERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) public {
    //     RevertingERC1155Recipient to = new RevertingERC1155Recipient();

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(to)][id] += mintAmount;
    //     }

    //     token.batchMint(address(to), normalizedIds, normalizedAmounts, mintData);
    // }

    // function testFailBatchMintToWrongReturnDataERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) public {
    //     WrongReturnDataERC1155BRecipient to = new WrongReturnDataERC1155BRecipient();

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(to)][id] += mintAmount;
    //     }

    //     token.batchMint(address(to), normalizedIds, normalizedAmounts, mintData);
    // }

    // function testFailBatchMintWithArrayMismatch(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) public {
    //     if (ids.length == amounts.length) revert();

    //     token.batchMint(address(to), ids, amounts, mintData);
    // }

    // function testFailBatchBurnInsufficientBalance(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory burnAmounts,
    //     bytes memory mintData
    // ) public {
    //     uint256 minLength = min3(ids.length, mintAmounts.length, burnAmounts.length);

    //     if (minLength == 0) revert();

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedBurnAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[to][id];

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         normalizedBurnAmounts[i] = bound(burnAmounts[i], normalizedMintAmounts[i] + 1, type(uint256).max);

    //         userMintAmounts[to][id] += normalizedMintAmounts[i];
    //     }

    //     token.batchMint(to, normalizedIds, normalizedMintAmounts, mintData);

    //     token.batchBurn(to, normalizedIds, normalizedBurnAmounts);
    // }

    // function testFailBatchBurnWithArrayLengthMismatch(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory burnAmounts,
    //     bytes memory mintData
    // ) public {
    //     if (ids.length == burnAmounts.length) revert();

    //     token.batchMint(to, ids, mintAmounts, mintData);

    //     token.batchBurn(to, ids, burnAmounts);
    // }

    // function testFailBalanceOfBatchWithArrayMismatch(address[] memory tos, uint256[] memory ids) public view {
    //     if (tos.length == ids.length) revert();

    //     token.balanceOfBatch(tos, ids);
    // }
}
