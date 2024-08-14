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

    mapping(bytes4 => Product) manufacturerStocks;

    uint256 ETHER_WEI_VALUE = 1e18;

    modifier isProductExist(bytes4 _productId) {
        require(productExit[_productId], "Product doesn't Exist");
        _;
    }

    function addProduct(
        string memory _name,
        uint256 _quantity,
        uint256 _price
    ) public {
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
        productHistory[msg.sender].push(_productId);
    }

    function createPayment(
        bytes4 _productId,
        address _to,
        uint256 _amount
    ) public {
        bytes4 _paymentId = bytes4(
            keccak256(
                abi.encodePacked(
                    msg.sender,
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
            from: msg.sender,
            to: _to,
            amount: _amount * ETHER_WEI_VALUE,
            timeStamp: block.timestamp,
            isDone: true
        });
        payments[_paymentId] = payment;
        paymentHistory[msg.sender].push(_paymentId);
        paymentHistory[_to].push(_paymentId);

        (bool success, ) = payable(_to).call{value: _amount}("");
        if (!success) {
            revert PaymentFailed();
        }
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

    function getManufacturerStock(
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
        Product memory product = manufacturerStocks[_productId];
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

contract Supplier is SupplyChain {
    function supplyMaterialToManufacturer(
        bytes4 _productId,
        address _to,
        uint256 _quantity,
        uint256 _amount
    ) public payable isProductExist(_productId) {
        console.log(msg.value);
        require(
            _amount * ETHER_WEI_VALUE ==
                products[_productId].price * _quantity * ETHER_WEI_VALUE,
            "Insufficiant Amount."
        );
        require(msg.value == _amount * ETHER_WEI_VALUE, "");

        Product storage product = products[_productId];
        manufacturerStocks[_productId] = product;
        product.quantity -= _quantity;
        manufacturerStocks[_productId].quantity = _quantity;
        productHistory[msg.sender].push(_productId);
        createPayment(_productId, _to, _amount);
    }
}

contract Manufacturer is SupplyChain {
    function takeRawMaterials(
        address supplier,
        bytes4 _productId,
        address _to,
        uint256 _quantity,
        uint256 _amount
    ) public payable {
        console.log(supplier);
        Supplier(supplier).supplyMaterialToManufacturer(
            _productId,
            _to,
            _quantity,
            _amount
        );
    }
}
