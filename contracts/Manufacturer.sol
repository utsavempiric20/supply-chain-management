// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SupplyChain.sol";
import "./Supplier.sol";

contract Manufacturer {
    SupplyChain supplyChain;
    Supplier supplier;

    uint256 ETHER_WEI_VALUE = 1e18;

    constructor(address _supplyChain, address _supplier) {
        supplyChain = SupplyChain(_supplyChain);
        supplier = Supplier(_supplier);
    }

    function takeRawMaterials(
        address _supplier,
        bytes4 _productId,
        uint256 _quantity,
        uint256 _amount
    ) public payable {
        supplier.supplyMaterialToManufacturer{value: msg.value}(
            _productId,
            msg.sender,
            _supplier,
            _quantity,
            _amount
        );
    }

    function addProduct(
        string memory _name,
        uint256 _quantity,
        uint256 _price
    ) public {
        supplyChain.addProduct(msg.sender, _name, _quantity, _price);
    }

    function distributeProduct(
        bytes4 _productId,
        address _from,
        address _to,
        uint256 _quantity,
        uint256 _amount
    ) public payable {
        (, , uint256 availableQuantity, uint256 price) = supplyChain.getProduct(
            _productId
        );
        require(availableQuantity >= _quantity, "Insufficiant Quantity.");
        require(
            _amount * ETHER_WEI_VALUE == price * _quantity * ETHER_WEI_VALUE,
            "Insufficiant Amount."
        );
        require(msg.value == _amount * ETHER_WEI_VALUE, "Insufficiant Value.");

        supplyChain.updateProductQuantity(_productId, _quantity);
        supplyChain.updateProductStocks(_from, _productId, _quantity);
        supplyChain.createPayment{value: msg.value}(
            _productId,
            _from,
            _to,
            _amount
        );
    }

    function getProduct(
        bytes4 _productId
    )
        public
        view
        returns (
            bytes4 productId,
            string memory name,
            uint256 quantity,
            uint256 price
        )
    {
        return supplyChain.getProduct(_productId);
    }

    function getProductStocks(
        bytes4 _productId
    )
        public
        view
        returns (
            bytes4 productId,
            string memory name,
            uint256 quantity,
            uint256 price
        )
    {
        return supplyChain.getProductStocks(_productId);
    }

    function getProductHistory(
        address person
    ) public view returns (bytes4[] memory) {
        return supplyChain.getProductHistory(person);
    }

    function getStockHistory(
        address person
    ) public view returns (bytes4[] memory) {
        return supplyChain.getStockHistory(person);
    }

    function getPayment(
        bytes4 _paymentId
    )
        public
        view
        returns (
            bytes4 paymentId,
            bytes4 productId,
            address from,
            address to,
            uint256 amount,
            uint256 timeStamp,
            bool isDone
        )
    {
        return supplyChain.getPayment(_paymentId);
    }

    function getPaymentHistory(
        address person
    ) public view returns (bytes4[] memory) {
        return supplyChain.getPaymentHistory(person);
    }
}
