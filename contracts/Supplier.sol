// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SupplyChain.sol";
import "./ProductSupplyCycle.sol";

contract Supplier {
    ProductSupplyCycle productSupplyCycle;

    struct Suppliers {
        bytes4 supplierId;
        string name;
        address accountAddress;
    }

    struct Product {
        bytes4 productQrCode;
        bytes4 productId;
        address supplierAddress;
        string name;
        uint256 quantity;
        uint256 price;
        uint256 timeStamp;
        string location;
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

    mapping(bytes4 => Suppliers) supplier;
    mapping(address => bytes4[]) allSuppliers;
    mapping(address => bool) supplierExistStatus;

    mapping(bytes4 => Product) products;
    mapping(bytes4 => bool) productExitStatus;
    mapping(address => bytes4[]) productHistory;

    mapping(bytes4 => Payment) payments;
    mapping(address => bytes4[]) paymentHistory;

    SupplyChain supplyChain;
    uint256 ETHER_WEI_VALUE = 1e18;

    modifier supplierExist(address _supplierAddress) {
        require(
            !supplierExistStatus[_supplierAddress],
            "Supplier already exist."
        );
        _;
    }

    modifier onlySupplier(address _supplierAddress) {
        require(
            supplierExistStatus[_supplierAddress],
            "Supplier doesn't exist."
        );
        _;
    }

    modifier productExist(bytes4 _productId) {
        require(productExitStatus[_productId], "Product doesn't Exist");
        _;
    }

    constructor(address _productSupplyCycle) {
        productSupplyCycle = ProductSupplyCycle(_productSupplyCycle);
    }

    function registerSupplier(
        string memory _name
    ) public supplierExist(msg.sender) {
        bytes4 supplierId = bytes4(
            keccak256(abi.encodePacked(_name, msg.sender, block.timestamp))
        );
        Suppliers memory _supplier = Suppliers({
            supplierId: supplierId,
            name: _name,
            accountAddress: msg.sender
        });
        supplier[supplierId] = _supplier;
        allSuppliers[address(this)].push(supplierId);
        supplierExistStatus[msg.sender] = true;
    }

    function addProduct(
        string memory _name,
        uint256 _quantity,
        uint256 _price,
        string memory _location
    ) public onlySupplier(msg.sender) returns (bytes4) {
        bytes4 _productId = bytes4(
            keccak256(abi.encodePacked(_name, _price, block.timestamp))
        );

        bytes4 productQrCode = bytes4(
            keccak256(
                abi.encodePacked(_productId, _name, _price, block.timestamp)
            )
        );
        Product memory product = Product({
            productQrCode: productQrCode,
            productId: _productId,
            supplierAddress: msg.sender,
            name: _name,
            quantity: _quantity,
            price: _price,
            timeStamp: block.timestamp,
            location: _location
        });
        products[_productId] = product;
        productExitStatus[_productId] = true;
        productHistory[msg.sender].push(_productId);

        productSupplyCycle.setSupplierProductIdUgid(productQrCode, _productId);
        return _productId;
    }

    // For Manufacturer Interaction
    function purchaseMaterialsByManufacturer(
        bytes4 _productId,
        address _to,
        uint256 _quantity
    ) public productExist(_productId) onlySupplier(_to) {
        require(
            products[_productId].quantity >= _quantity,
            "Quantity Not Available"
        );
        products[_productId].quantity -= _quantity;
    }

    // For Manufacturer Interaction
    function recievePaymentFromManufacturer(
        bytes4 _productId,
        address _from,
        address _to,
        uint256 _quantity,
        uint256 _amount
    )
        public
        payable
        productExist(_productId)
        onlySupplier(_to)
        returns (
            bytes4 paymentId,
            uint256 amount,
            uint256 timeStamp,
            bool isDone
        )
    {
        require(
            _amount >= products[_productId].price * _quantity,
            "Insufficiant Amount."
        );
        require(msg.value >= _amount, "Insufficiant Value");

        // if(msg.value > _amount){
        //     console.log(msg.value,_amount);
        //     uint256 balance = msg.value - products[_productId].price * _quantity;
        //     console.log(balance);
        //     (bool successPayment,) = payable(_from).call{value:balance}("");
        //     require(successPayment, "return payment failed");
        // }

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
            quantity: _quantity,
            amount: _amount,
            timeStamp: block.timestamp,
            isDone: true
        });

        payments[_paymentId] = payment;
        paymentHistory[_to].push(_paymentId);

        (bool success, ) = payable(_to).call{value: msg.value}("");
        require(success, "Payment Failed");
        return (
            payment.paymentId,
            payment.amount,
            payment.timeStamp,
            payment.isDone
        );
    }

    function getSupplier(
        bytes4 _supplierId
    )
        public
        view
        returns (bytes4 supplierId, string memory name, address accountAddress)
    {
        Suppliers memory suppliers = supplier[_supplierId];
        return (suppliers.supplierId, suppliers.name, suppliers.accountAddress);
    }

    function getAllSuppliers(
        address _contractAddress
    ) public view returns (bytes4[] memory) {
        return allSuppliers[_contractAddress];
    }

    function getProduct(
        bytes4 _productId
    )
        public
        view
        returns (
            bytes4 productQrCode,
            bytes4 productId,
            address supplierAddress,
            string memory name,
            uint256 quantity,
            uint256 price,
            uint256 timeStamp,
            string memory location
        )
    {
        Product memory product = products[_productId];
        return (
            product.productQrCode,
            product.productId,
            product.supplierAddress,
            product.name,
            product.quantity,
            product.price,
            product.timeStamp,
            product.location
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
