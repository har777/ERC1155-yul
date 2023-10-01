// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./lib/YulDeployer.sol";
import { ERC1155TokenReceiver } from "./solady/ERC1155TokenReceiver.sol";
import { ERC1155Recipient } from "./solady/ERC1155Solady.t.sol";
import { DSTestPlus } from "./solady/DSTestPlus.sol";

interface IERC1155 {
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external;

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external;

    function balanceOf(
        address _owner,
        uint256 _id
    ) external view returns (uint256);

    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) external view returns (uint256[] memory);

    function setApprovalForAll(address _operator, bool _approved) external;

    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool);

    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    function mint(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory data
    ) external;

    function burn(
        address _to,
        uint256 _id,
        uint256 _amount
    ) external;

    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external;

    function setURI(string memory uri) external;

    function uri(uint256 id) external returns (string memory);
}

contract ERC1155Test is Test, ERC1155TokenReceiver {
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    YulDeployer yulDeployer = new YulDeployer();

    IERC1155 erc1155;

    function setUp() public {
        erc1155 = IERC1155(yulDeployer.deployContract("ERC1155"));
    }

    function testCannotSendEther() public {
        vm.expectRevert();
        payable(address(erc1155)).transfer(1 wei);
    }

    function testApprovalForAll() public {
        assertEq(erc1155.isApprovedForAll(address(this), address(0xBEEF)), false);
        assertEq(erc1155.isApprovedForAll(address(this), address(0xAEEF)), false);

        vm.expectEmit(true, true, false, true, address(erc1155));
        emit ApprovalForAll(address(this), address(0xBEEF), true);

        erc1155.setApprovalForAll(address(0xBEEF), true);
        assertEq(erc1155.isApprovedForAll(address(this), address(0xBEEF)), true);
        assertEq(erc1155.isApprovedForAll(address(this), address(0xAEEF)), false);

        vm.expectEmit(true, true, false, true, address(erc1155));
        emit ApprovalForAll(address(this), address(0xBEEF), false);

        erc1155.setApprovalForAll(address(0xBEEF), false);
        assertEq(erc1155.isApprovedForAll(address(this), address(0xBEEF)), false);
        assertEq(erc1155.isApprovedForAll(address(this), address(0xAEEF)), false);
    }

    function testBalanceOf() public {
        assertEq(erc1155.balanceOf(address(this), 1), 0);
        assertEq(erc1155.balanceOf(address(this), 2), 0);
        assertEq(erc1155.balanceOf(address(0xBEEF), 1), 0);

        erc1155.mint(address(this), 1, 10, "");

        assertEq(erc1155.balanceOf(address(this), 1), 10);
        assertEq(erc1155.balanceOf(address(this), 2), 0);
        assertEq(erc1155.balanceOf(address(0xBEEF), 1), 0);

        erc1155.mint(address(this), 2, 5, "");

        assertEq(erc1155.balanceOf(address(this), 1), 10);
        assertEq(erc1155.balanceOf(address(this), 2), 5);
        assertEq(erc1155.balanceOf(address(0xBEEF), 1), 0);

        erc1155.burn(address(this), 1, 4);

        assertEq(erc1155.balanceOf(address(this), 1), 6);
        assertEq(erc1155.balanceOf(address(this), 2), 5);
        assertEq(erc1155.balanceOf(address(0xBEEF), 1), 0);

        erc1155.burn(address(this), 2, 1);

        assertEq(erc1155.balanceOf(address(this), 1), 6);
        assertEq(erc1155.balanceOf(address(this), 2), 4);
        assertEq(erc1155.balanceOf(address(0xBEEF), 1), 0);
    }

    function testSafeTransferFrom() public {
        erc1155.mint(address(this), 1, 10, "");
        erc1155.mint(address(this), 2, 5, "");

        vm.expectEmit(true, true, true, true, address(erc1155));
        emit TransferSingle(address(this), address(this), address(0xBEEF), 1, 4);

        erc1155.safeTransferFrom(address(this), address(0xBEEF), 1, 4, "");
        assertEq(erc1155.balanceOf(address(this), 1), 6);
        assertEq(erc1155.balanceOf(address(0xBEEF), 1), 4);

        vm.expectEmit(true, true, true, true, address(erc1155));
        emit TransferSingle(address(this), address(this), address(0xAEEF), 2, 4);

        erc1155.safeTransferFrom(address(this), address(0xAEEF), 2, 4, "");
        assertEq(erc1155.balanceOf(address(this), 2), 1);
        assertEq(erc1155.balanceOf(address(0xAEEF), 2), 4);

        vm.prank(address(0xAEEF));
        erc1155.setApprovalForAll(address(0xCEEF), true);

        vm.expectEmit(true, true, true, true, address(erc1155));
        emit TransferSingle(address(0xCEEF), address(0xAEEF), address(0xBEEF), 2, 2);

        vm.prank(address(0xCEEF));
        erc1155.safeTransferFrom(address(0xAEEF), address(0xBEEF), 2, 2, "");
        assertEq(erc1155.balanceOf(address(this), 2), 1);
        assertEq(erc1155.balanceOf(address(0xAEEF), 2), 2);
        assertEq(erc1155.balanceOf(address(0xBEEF), 2), 2);
    }

    function testBatchMint() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 5;
        tokenIds[1] = 10;
        uint256[] memory tokenQuantities = new uint256[](2);
        tokenQuantities[0] = 7;
        tokenQuantities[1] = 12;

        vm.expectEmit(true, true, true, true, address(erc1155));
        emit TransferBatch(address(0xAEEF), address(0), address(this), tokenIds, tokenQuantities);

        vm.prank(address(0xAEEF));
        erc1155.batchMint(address(this), tokenIds, tokenQuantities, "");

        assertEq(erc1155.balanceOf(address(this), 5), 7);
        assertEq(erc1155.balanceOf(address(this), 10), 12);
    }

    function testBatchBurn() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 5;
        tokenIds[1] = 10;
        uint256[] memory tokenQuantities = new uint256[](2);
        tokenQuantities[0] = 7;
        tokenQuantities[1] = 12;

        vm.expectEmit(true, true, true, true, address(erc1155));
        emit TransferBatch(address(0xAEEF), address(0), address(this), tokenIds, tokenQuantities);

        vm.prank(address(0xAEEF));
        erc1155.batchMint(address(this), tokenIds, tokenQuantities, "");

        assertEq(erc1155.balanceOf(address(this), 5), 7);
        assertEq(erc1155.balanceOf(address(this), 10), 12);

        uint256[] memory tokenBurnQuantities = new uint256[](2);
        tokenBurnQuantities[0] = 7;
        tokenBurnQuantities[1] = 4;

        vm.expectEmit(true, true, true, true, address(erc1155));
        emit TransferBatch(address(0xAEEF), address(this), address(0), tokenIds, tokenBurnQuantities);

        vm.prank(address(0xAEEF));

        erc1155.batchBurn(address(this), tokenIds, tokenBurnQuantities);

        assertEq(erc1155.balanceOf(address(this), 5), 0);
        assertEq(erc1155.balanceOf(address(this), 10), 8);
    }

    function testSafeBatchTransferFrom() public {
        uint256[] memory tokenIds1 = new uint256[](2);
        tokenIds1[0] = 5;
        tokenIds1[1] = 10;
        uint256[] memory tokenQuantities1 = new uint256[](2);
        tokenQuantities1[0] = 7;
        tokenQuantities1[1] = 12;

        uint256[] memory tokenIds2 = new uint256[](4);
        tokenIds2[0] = 5;
        tokenIds2[1] = 10;
        tokenIds2[2] = 15;
        tokenIds2[3] = 20;
        uint256[] memory tokenQuantities2 = new uint256[](4);
        tokenQuantities2[0] = 20;
        tokenQuantities2[1] = 42;
        tokenQuantities2[2] = 16;
        tokenQuantities2[3] = 27;

        erc1155.batchMint(address(0xAEEF), tokenIds1, tokenQuantities1, "");
        erc1155.batchMint(address(0xBEEF), tokenIds2, tokenQuantities2, "");

        uint256[] memory tokenIds3 = new uint256[](2);
        tokenIds3[0] = 5;
        tokenIds3[1] = 10;
        uint256[] memory tokenQuantities3 = new uint256[](2);
        tokenQuantities3[0] = 6;
        tokenQuantities3[1] = 12;

        vm.expectEmit(true, true, true, true, address(erc1155));
        emit TransferBatch(address(0xAEEF), address(0xAEEF), address(0xBEEF), tokenIds3, tokenQuantities3);

        vm.prank(address(0xAEEF));
        erc1155.safeBatchTransferFrom(address(0xAEEF), address(0xBEEF), tokenIds3, tokenQuantities3, "");

        assertEq(erc1155.balanceOf(address(0xAEEF), 5), 1);
        assertEq(erc1155.balanceOf(address(0xAEEF), 10), 0);
        assertEq(erc1155.balanceOf(address(0xBEEF), 5), 26);
        assertEq(erc1155.balanceOf(address(0xBEEF), 10), 54);
        assertEq(erc1155.balanceOf(address(0xBEEF), 15), 16);
        assertEq(erc1155.balanceOf(address(0xBEEF), 20), 27);
    }

    function testBalanceOfBatch() public {
        uint256[] memory tokenIds1 = new uint256[](2);
        tokenIds1[0] = 5;
        tokenIds1[1] = 10;
        uint256[] memory tokenQuantities1 = new uint256[](2);
        tokenQuantities1[0] = 7;
        tokenQuantities1[1] = 12;

        uint256[] memory tokenIds2 = new uint256[](4);
        tokenIds2[0] = 5;
        tokenIds2[1] = 10;
        tokenIds2[2] = 15;
        tokenIds2[3] = 20;
        uint256[] memory tokenQuantities2 = new uint256[](4);
        tokenQuantities2[0] = 20;
        tokenQuantities2[1] = 42;
        tokenQuantities2[2] = 16;
        tokenQuantities2[3] = 27;

        erc1155.batchMint(address(0xAEEF), tokenIds1, tokenQuantities1, "");
        erc1155.batchMint(address(0xBEEF), tokenIds2, tokenQuantities2, "");

        address[] memory testAddresses = new address[](2);
        testAddresses[0] = address(0xAEEF);
        testAddresses[1] = address(0xBEEF);
        uint256[] memory testIds = new uint256[](2);
        testIds[0] = 10;
        testIds[1] = 20;
        uint256[] memory expectedResults = new uint256[](2);
        expectedResults[0] = 12;
        expectedResults[1] = 27;

        assertEq(erc1155.balanceOfBatch(testAddresses, testIds), expectedResults);

        vm.expectRevert("LENGTH_MISMATCH");
        uint256[] memory badTestIds = new uint256[](1);
        testIds[0] = 10;
        erc1155.balanceOfBatch(testAddresses, badTestIds);

        vm.expectRevert("NOT_AUTHORIZED");
        erc1155.safeTransferFrom(address(0xAEEF), address(0xBEEF), 1, 2, "");
    }
}

contract ERC1155TestReceiver is Test {
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    YulDeployer yulDeployer = new YulDeployer();

    IERC1155 erc1155;

    function setUp() public {
        erc1155 = IERC1155(yulDeployer.deployContract("ERC1155"));
    }

    function testMint() public {
        ERC1155Recipient to = new ERC1155Recipient();

        erc1155.mint(address(to), 1337, 1, "testing 123");

        assertEq(erc1155.balanceOf(address(to), 1337), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertEq(to.mintData(), "testing 123");
    }

    function testBadDestinationRevertMessage() public {
        vm.expectRevert("UNSAFE_RECIPIENT");
        erc1155.mint(address(this), 1337, 1, "testing 123");

        vm.expectRevert("UNSAFE_RECIPIENT");
        erc1155.mint(address(0), 1337, 1, "testing 123");

        erc1155.mint(address(1), 1337, 1, "testing 123");

        ERC1155Recipient to = new ERC1155Recipient();
        erc1155.mint(address(to), 1337, 1, "testing 123");
    }
}

contract URITest is Test {
    YulDeployer yulDeployer = new YulDeployer();

    IERC1155 erc1155;

    function setUp() public {
        erc1155 = IERC1155(yulDeployer.deployContract("ERC1155"));
    }

    function testURI() public {
        assertEq(erc1155.uri(1), "");

        string memory test = "testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing";
        erc1155.setURI(test);
        assertEq(erc1155.uri(1), test);

        test = "testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing ";
        erc1155.setURI(test);
        assertEq(erc1155.uri(1), test);

        test = "";
        erc1155.setURI(test);
        assertEq(erc1155.uri(1), test);

        test = "testing testing";
        erc1155.setURI(test);
        assertEq(erc1155.uri(1), test);

        test = " ";
        erc1155.setURI(test);
        assertEq(erc1155.uri(1), test);

        test = "                                                                                                                                       ";
        erc1155.setURI(test);
        assertEq(erc1155.uri(1), test);

        test = "9";
        erc1155.setURI(test);
        assertEq(erc1155.uri(1), test);

        test = "hmmmm will this really work ????? ?? ??";
        erc1155.setURI(test);
        assertEq(erc1155.uri(1), test);
    }

    function testURIFuzz(string memory test) public {
        erc1155.setURI(test);
        string memory response = erc1155.uri(1);

        assertEq(response, test);
    }
}
