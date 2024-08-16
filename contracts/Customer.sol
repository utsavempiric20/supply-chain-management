// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SupplyChain.sol";
import "./Retailer.sol";

contract Customer {
    SupplyChain supplyChain;
    Retailer retailer;

    uint256 ETHER_WEI_VALUE = 1e18;

    constructor(address _supplyChain, address _retailer) {
        supplyChain = SupplyChain(_supplyChain);
        retailer = Retailer(_retailer);
    }

    function buyProduct(
        address _retailer,
        bytes4 _productId,
        uint256 _quantity,
        uint256 _amount
    ) public payable {
        retailer.sellToCustomer{value: msg.value}(
            _productId,
            msg.sender,
            _retailer,
            _quantity,
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

    function getProductHistory(
        address person
    ) public view returns (bytes4[] memory) {
        return supplyChain.getProductHistory(person);
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
