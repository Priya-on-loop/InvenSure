// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ExpiryTracker {

    struct Product {
        uint256 productId;
        string name;
        uint256 expiryDate;
        bool isRecycled;
    }

    mapping(uint256 => Product) public products;

    event ProductAdded(uint256 productId, string name, uint256 expiryDate);
    event ProductRecycled(uint256 productId, uint256 recycledDate);

    function addProduct(
        uint256 _productId,
        string memory _name,
        uint256 _expiryDate
    ) public {
        products[_productId] = Product(
            _productId,
            _name,
            _expiryDate,
            false
        );

        emit ProductAdded(_productId, _name, _expiryDate);
    }

    function markAsRecycled(uint256 _productId) public {
        require(!products[_productId].isRecycled, "Already recycled");

        products[_productId].isRecycled = true;

        emit ProductRecycled(_productId, block.timestamp);
    }

    function getProduct(uint256 _productId) public view returns (
        uint256,
        string memory,
        uint256,
        bool
    ) {
        Product memory p = products[_productId];
        return (p.productId, p.name, p.expiryDate, p.isRecycled);
    }
}