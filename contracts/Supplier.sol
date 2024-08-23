// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

    struct Sell {
        bytes4 sellId;
        bytes4 productId;
        address supplierAddress;
        address manufacturerAddress;
        uint256 quantity;
        uint256 price;
        uint256 amount;
        bool paymentDone;
    }

    mapping(bytes4 => Suppliers) supplier;
    mapping(address => bytes4[]) allSuppliers;
    mapping(address => bool) supplierExistStatus;

    mapping(bytes4 => Product) products;
    mapping(bytes4 => bool) productExitStatus;
    mapping(address => bytes4[]) productHistory;

    mapping(bytes4 => Payment) payments;
    mapping(address => bytes4[]) paymentHistory;

    mapping(bytes4 => Sell) productSell;
    mapping(address => bytes4[]) sellingHistory;
    mapping(bytes4 => mapping(address => bool)) sellPaymentDone;

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

    function updateProductStocks(
        bytes4 _productId,
        uint256 _quantity,
        uint256 _price,
        string memory _location
    ) public productExist(_productId) {
        Product storage product = products[_productId];
        product.quantity = _quantity;
        product.price = _price;
        product.timeStamp = block.timestamp;
        product.location = _location;
    }

    // For Manufacturer Interaction
    function purchaseMaterialsByManufacturer(
        bytes4 _productId,
        address _from,
        address _to,
        uint256 _quantity
    ) public productExist(_productId) onlySupplier(_to) returns (bytes4) {
        require(
            !sellPaymentDone[_productId][_from],
            "pay payment for previous Buying stock."
        );
        require(
            products[_productId].quantity >= _quantity,
            "Quantity Not Available"
        );
        bytes4 _sellId = bytes4(
            keccak256(
                abi.encodePacked(
                    _productId,
                    _from,
                    _to,
                    _quantity,
                    block.timestamp
                )
            )
        );
        Sell memory _sell = Sell({
            sellId: _sellId,
            productId: _productId,
            supplierAddress: _to,
            manufacturerAddress: _from,
            quantity: _quantity,
            price: products[_productId].price,
            amount: products[_productId].price * _quantity,
            paymentDone: false
        });
        productSell[_sellId] = _sell;
        sellingHistory[_to].push(_sellId);
        sellPaymentDone[_productId][_from] = true;

        products[_productId].quantity -= _quantity;
        return _sellId;
    }

    // For Manufacturer Interaction
    function recievePaymentFromManufacturer(
        bytes4 _sellId,
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
        returns (bytes4 paymentId, uint256 timeStamp, bool isDone)
    {
        require(productSell[_sellId].sellId == _sellId, "Invalid BuyingId.");
        require(
            productSell[_sellId].manufacturerAddress == _from,
            "Invalid user."
        );
        require(
            sellPaymentDone[_productId][_from],
            "Buy Stoks Firstly and then pay amount."
        );
        require(
            _amount == products[_productId].price * _quantity,
            "Insufficiant Amount."
        );
        require(msg.value == _amount, "Insufficiant Value");

        (paymentId, timeStamp, isDone) = recievePayment(
            _sellId,
            _productId,
            _from,
            _to,
            _quantity,
            _amount
        );

        (bool success, ) = payable(_to).call{value: msg.value}("");
        require(success, "Payment Failed");
        return (paymentId, timeStamp, isDone);
    }

    function recievePayment(
        bytes4 _sellId,
        bytes4 _productId,
        address _from,
        address _to,
        uint256 _quantity,
        uint256 _amount
    ) internal returns (bytes4 paymentId, uint256 timeStamp, bool isDone) {
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
        Sell storage selledProduct = productSell[_sellId];
        selledProduct.paymentDone = true;
        sellPaymentDone[_productId][_from] = false;
        return (payment.paymentId, payment.timeStamp, payment.isDone);
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

    function getSellProduct(
        bytes4 _sellId
    )
        public
        view
        returns (
            bytes4 sellId,
            bytes4 productId,
            address supplierAddress,
            address manufacturerAddress,
            uint256 quantity,
            uint256 price,
            uint256 amount,
            bool paymentDone
        )
    {
        Sell memory sell = productSell[_sellId];
        return (
            sell.sellId,
            sell.productId,
            sell.supplierAddress,
            sell.manufacturerAddress,
            sell.quantity,
            sell.price,
            sell.amount,
            sell.paymentDone
        );
    }

    function getSellingHistory() public view returns (bytes4[] memory) {
        return sellingHistory[msg.sender];
    }
}
