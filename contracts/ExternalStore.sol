// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract ExternalStore is ERC1155, Ownable {
    mapping(address => mapping(uint256 => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
     constructor(string memory uri_)ERC1155(uri_) {}
    function wrap(address user, uint256 amount, uint256 id) external onlyOwner {
        _balances[user][id] += amount;
        emit TransferSingle(msg.sender, address(0), user, id, amount);
    }

    function burn(address user, uint256 id, uint256 amount) external onlyOwner {
        _balances[user][id] -= amount;
        emit TransferSingle(msg.sender, user, address(0), id, amount);
    }

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return _balances[account][id];
    }


    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view override returns (uint256[] memory) {
        uint256[] memory batchBalances = new uint256[](accounts.length * ids.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            for (uint256 j = 0; j < ids.length; j++) {
                batchBalances[i * ids.length + j] = _balances[accounts[i]][ids[j]];
            }
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public override {
        require(msg.sender != operator, "ERC1155: setting approval status for self");

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public override {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = msg.sender;
        require(from == msg.sender || isApprovedForAll(from, operator), "ERC1155: caller is not owner nor approved");

        _balances[from][id] -= amount;
        _balances[to][id] += amount;

        emit TransferSingle(operator, from, to, id, amount);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public override {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = msg.sender;
        require(from == msg.sender || isApprovedForAll(from, operator), "ERC1155: caller is not owner nor approved");

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[from][ids[i]] -= amounts[i];
            _balances[to][ids[i]] += amounts[i];
        }

        emit TransferBatch(operator, from, to, ids, amounts);
    }
}