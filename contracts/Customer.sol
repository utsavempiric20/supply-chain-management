// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Retailer.sol";
import "./ProductSupplyCycle.sol";

contract Customer {
    ProductSupplyCycle productSupplyCycle;

    constructor(address _productSupplyCycle) {
        productSupplyCycle = ProductSupplyCycle(_productSupplyCycle);
    }

    struct Product {
        bytes4 productQrCode;
        bytes4 productId;
        address retailer;
        string name;
        uint256 quantity;
        uint256 price;
    }

    struct Payment {
        bytes4 paymentId;
        bytes4 productId;
        address from;
        address to;
        uint256 quantity;
        uint256 amount;
        uint256 timeStamp;
        bool isDone;
    }

    mapping(bytes4 => Product) products;
    mapping(bytes4 => bool) productExitStatus;
    mapping(address => bytes4[]) productHistory;

    mapping(bytes4 => Payment) payments;
    mapping(address => bytes4[]) paymentHistory;

    uint256 constant ETHER_WEI_VALUE = 1e18;

    function buyProduct(
        address _retailerContractAddress,
        address _retailerAddress,
        bytes4 _productId,
        uint256 _quantity
    ) public {
        Retailer(_retailerContractAddress).buyProductByCustomer(
            _productId,
            _retailerAddress,
            _quantity
        );
        (
            bytes4 productQrCode,
            ,
            ,
            string memory name,
            ,
            uint256 price,
            ,

        ) = Retailer(_retailerContractAddress).getProduct(_productId);

        if (products[_productId].productId != _productId) {
            Product memory _products = Product({
                productQrCode: productQrCode,
                productId: _productId,
                retailer: _retailerAddress,
                name: name,
                quantity: _quantity,
                price: price
            });
            products[_productId] = _products;
            productHistory[msg.sender].push(_productId);
        } else {
            products[_productId].quantity += _quantity;
        }
    }

    function receiveProductFromRetailer(
        address _retailerContractAddress,
        address _retailer,
        address _customer,
        bytes4 _productId,
        uint256 _quantity,
        uint256 _amount
    ) public payable {
        require(products[_productId].quantity == _quantity, "InValid Quantity");
        require(
            _amount == products[_productId].price * _quantity,
            "Insufficiant amount"
        );
        require(msg.value == _amount, "InValid Value");

        (
            bytes4 paymentId,
            uint256 amount,
            uint256 timeStamp,
            bool isDone
        ) = Retailer(_retailerContractAddress).receivePaymentFromCustomer{
                value: msg.value
            }(_productId, _customer, _retailer, _quantity, _amount);

        payments[paymentId].paymentId = paymentId;
        payments[paymentId].productId = _productId;
        payments[paymentId].from = _customer;
        payments[paymentId].to = _retailer;
        payments[paymentId].quantity = _quantity;
        payments[paymentId].amount = amount;
        payments[paymentId].timeStamp = timeStamp;
        payments[paymentId].isDone = isDone;
        paymentHistory[msg.sender].push(paymentId);
    }

    function getProductFullCycle(
        bytes4 _productQrCode
    )
        public
        view
        returns (
            bytes4 productQrCode,
            bytes4 supplierProductId,
            bytes4 manufacturerProductId,
            bytes4 distributorProductId,
            bytes4 retailerProductId
        )
    {
        return productSupplyCycle.getProductFullDetails(_productQrCode);
    }

    function getProduct(
        bytes4 _productId
    )
        public
        view
        returns (
            bytes4 productQrCode,
            bytes4 productId,
            string memory name,
            uint256 quantity,
            uint256 price
        )
    {
        Product memory product = products[_productId];
        return (
            product.productQrCode,
            product.productId,
            product.name,
            product.quantity,
            product.price
        );
    }

    function getProductorStockHistory(
        address _person
    ) public view returns (bytes4[] memory) {
        return productHistory[_person];
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
