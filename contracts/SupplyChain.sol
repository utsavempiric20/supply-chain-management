// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "hardhat/console.sol";

contract SupplyChain {
    error PaymentFailed();

    struct Product {
        bytes4 productId;
        string name;
        uint256 quantity;
        uint256 price;
    }

    struct Payment {
        bytes4 paymentId;
        bytes4 productId;
        address from;
        address to;
        uint256 amount;
        uint256 timeStamp;
        bool isDone;
    }

    mapping(bytes4 => Product) products;
    mapping(bytes4 => bool) productExit;
    mapping(address => bytes4[]) productHistory;

    mapping(bytes4 => Payment) payments;
    mapping(address => bytes4[]) paymentHistory;

    mapping(bytes4 => Product) productStocks;
    mapping(address => bytes4[]) stockHistory;

    uint256 ETHER_WEI_VALUE = 1e18;

    modifier isProductExist(bytes4 _productId) {
        require(productExit[_productId], "Product doesn't Exist");
        _;
    }

    function addProduct(
        address _from,
        string memory _name,
        uint256 _quantity,
        uint256 _price
    ) public returns (bytes4) {
        bytes4 _productId = bytes4(
            keccak256(abi.encodePacked(_name, _price, block.timestamp))
        );
        Product memory product = Product({
            productId: _productId,
            name: _name,
            quantity: _quantity,
            price: _price
        });
        products[_productId] = product;
        productExit[_productId] = true;
        productHistory[_from].push(_productId);
        return _productId;
    }

    function createPayment(
        bytes4 _productId,
        address _from,
        address _to,
        uint256 _amount
    ) public payable isProductExist(_productId) {
        bytes4 _paymentId = bytes4(
            keccak256(
                abi.encodePacked(
                    _from,
                    _productId,
                    _to,
                    _amount,
                    block.timestamp
                )
            )
        );
        Payment memory payment = Payment({
            paymentId: _paymentId,
            productId: _productId,
            from: _from,
            to: _to,
            amount: _amount * ETHER_WEI_VALUE,
            timeStamp: block.timestamp,
            isDone: true
        });
        payments[_paymentId] = payment;
        paymentHistory[_from].push(_paymentId);
        paymentHistory[_to].push(_paymentId);
        console.log(_from, _to, msg.value);
        (bool success, ) = payable(_to).call{value: msg.value}("");
        if (!success) {
            revert PaymentFailed();
        }
    }

    function updateProductQuantity(
        bytes4 _productId,
        uint256 _quantity
    ) public {
        products[_productId].quantity -= _quantity;
    }

    function updateProductStocks(
        address _from,
        bytes4 _productId,
        uint256 _quantity
    ) public {
        Product storage product = products[_productId];
        productStocks[_productId] = product;
        productStocks[_productId].quantity = _quantity;
        stockHistory[_from].push(_productId);
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
        Product memory product = products[_productId];
        return (
            product.productId,
            product.name,
            product.quantity,
            product.price
        );
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
        Product memory product = productStocks[_productId];
        return (
            product.productId,
            product.name,
            product.quantity,
            product.price
        );
    }

    function getProductHistory(
        address person
    ) public view returns (bytes4[] memory) {
        return productHistory[person];
    }

    function getStockHistory(
        address person
    ) public view returns (bytes4[] memory) {
        return stockHistory[person];
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
        Payment memory payment = payments[_paymentId];
        return (
            payment.paymentId,
            payment.productId,
            payment.from,
            payment.to,
            payment.amount,
            payment.timeStamp,
            payment.isDone
        );
    }

    function getPaymentHistory(
        address person
    ) public view returns (bytes4[] memory) {
        return paymentHistory[person];
    }
}
