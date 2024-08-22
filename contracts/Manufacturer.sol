// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Supplier.sol";
import "./ProductSupplyCycle.sol";

contract Manufacturer {
    ProductSupplyCycle productSupplyCycle;

    struct Manufacturers {
        bytes4 manufacturerId;
        string name;
        address accountAddress;
    }

    struct Product {
        bytes4 productQrCode;
        bytes4 productId;
        address manufacturerAddress;
        string name;
        uint256 quantity;
        uint256 price;
        uint256 timeStamp;
        string location;
    }

    struct Stock {
        bytes4 productQrCode;
        bytes4 productId;
        address supplier;
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

    mapping(bytes4 => Manufacturers) manufacturer;
    mapping(address => bytes4[]) allManufacturer;
    mapping(address => bool) manufacturerExistStatus;

    mapping(bytes4 => Product) products;
    mapping(bytes4 => bool) productExitStatus;
    mapping(address => bytes4[]) productHistory;

    mapping(bytes4 => Payment) payments;
    mapping(address => bytes4[]) paymentHistory;

    mapping(bytes4 => Stock) stocks;
    mapping(address => bytes4[]) stockHistory;

    uint256 ETHER_WEI_VALUE = 1e18;

    modifier productExist(bytes4 _productId) {
        require(productExitStatus[_productId], "Product doesn't Exist");
        _;
    }

    modifier manufacturerExist(address _manufacturerAddress) {
        require(
            !manufacturerExistStatus[_manufacturerAddress],
            "Manufacturer already exist."
        );
        _;
    }

    modifier onlyManufacturer(address _manufacturerAddress) {
        require(
            manufacturerExistStatus[_manufacturerAddress],
            "Manufacturer doesn't exist."
        );
        _;
    }

    constructor(address _productSupplyCycle) {
        productSupplyCycle = ProductSupplyCycle(_productSupplyCycle);
    }

    function registerManufacturer(
        string memory _name
    ) public manufacturerExist(msg.sender) {
        bytes4 manufacturerId = bytes4(
            keccak256(abi.encodePacked(_name, msg.sender, block.timestamp))
        );
        Manufacturers memory _manufacturer = Manufacturers({
            manufacturerId: manufacturerId,
            name: _name,
            accountAddress: msg.sender
        });
        manufacturer[manufacturerId] = _manufacturer;
        allManufacturer[address(this)].push(manufacturerId);
        manufacturerExistStatus[msg.sender] = true;
    }

    function addProduct(
        bytes4 _productQrCode,
        string memory _name,
        uint256 _quantity,
        uint256 _price,
        string memory _location
    ) public onlyManufacturer(msg.sender) returns (bytes4) {
        bytes4 _productId = bytes4(
            keccak256(abi.encodePacked(_name, _price, block.timestamp))
        );
        Product memory product = Product({
            productQrCode: _productQrCode,
            productId: _productId,
            manufacturerAddress: msg.sender,
            name: _name,
            quantity: _quantity,
            price: _price,
            timeStamp: block.timestamp,
            location: _location
        });
        products[_productId] = product;
        productExitStatus[_productId] = true;
        productHistory[msg.sender].push(_productId);

        productSupplyCycle.setManufacturerProductIdUgid(
            _productQrCode,
            _productId
        );

        return _productId;
    }

    function updateProductStocks(
        bytes4 _productId,
        uint256 _quantity,
        uint256 _price,
        string memory _location
    ) public productExist(_productId) {
        products[_productId].quantity = _quantity;
        products[_productId].price = _price;
        products[_productId].timeStamp = block.timestamp;
        products[_productId].location = _location;
    }

    // For Distributor Interaction
    function purchaseProductByDistributor(
        bytes4 _productId,
        address _to,
        uint256 _quantity
    ) public productExist(_productId) onlyManufacturer(_to) {
        require(
            products[_productId].quantity >= _quantity,
            "Quantity Not Available"
        );
        products[_productId].quantity -= _quantity;
    }

    // For Distributor Interaction
    function receivePaymentFromDistributor(
        bytes4 _productId,
        address _from,
        address _to,
        uint256 _quantity,
        uint256 _amount
    )
        public
        payable
        productExist(_productId)
        onlyManufacturer(_to)
        returns (
            bytes4 paymentId,
            uint256 amount,
            uint256 timeStamp,
            bool isDone
        )
    {
        require(
            _amount == products[_productId].price * _quantity,
            "Insufficiant Amount."
        );
        require(msg.value == _amount, "Insufficiant Value");

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

    // Interact with Supplier
    function purchaseMaterialsFromSupplier(
        address _supplierContractAddress,
        address _supplierAddress,
        bytes4 _productId,
        uint256 _quantity
    ) public onlyManufacturer(msg.sender) {
        Supplier(_supplierContractAddress).purchaseMaterialsByManufacturer(
            _productId,
            _supplierAddress,
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

        ) = Supplier(_supplierContractAddress).getProduct(_productId);

        if (stocks[_productId].productId != _productId) {
            Stock memory _stocks = Stock({
                productQrCode: productQrCode,
                productId: _productId,
                supplier: _supplierAddress,
                name: name,
                quantity: _quantity,
                price: price
            });
            stocks[_productId] = _stocks;
            stockHistory[msg.sender].push(_productId);
        } else {
            stocks[_productId].quantity += _quantity;
        }
    }

    // Interact with Supplier
    function recieveMaterialsFromSupplier(
        address _supplierContractAddress,
        address _supplier,
        address _manufacturer,
        bytes4 _productId,
        uint256 _quantity,
        uint256 _amount
    ) public payable onlyManufacturer(msg.sender) {
        require(stocks[_productId].quantity == _quantity, "InValid Quantity");
        require(
            _amount == stocks[_productId].price * _quantity,
            "Insufficiant amount"
        );
        require(msg.value == _amount, "InValid Value");

        (
            bytes4 paymentId,
            uint256 amount,
            uint256 timeStamp,
            bool isDone
        ) = Supplier(_supplierContractAddress).recievePaymentFromManufacturer{
                value: msg.value
            }(_productId, _manufacturer, _supplier, _quantity, _amount);

        payments[paymentId].paymentId = paymentId;
        payments[paymentId].productId = _productId;
        payments[paymentId].from = _manufacturer;
        payments[paymentId].to = _supplier;
        payments[paymentId].amount = amount;
        payments[paymentId].timeStamp = timeStamp;
        payments[paymentId].isDone = isDone;
        paymentHistory[msg.sender].push(paymentId);
    }

    function paymentToSupplier(
        address _supplierContractAddress,
        address _supplier,
        address _manufacturer,
        bytes4 _productCode,
        bytes4 _productId,
        uint256 _quantity,
        uint256 _amount
    ) internal {}

    function getManufacturer(
        bytes4 _manufacturerId
    )
        public
        view
        returns (
            bytes4 manufacturerId,
            string memory name,
            address accountAddress
        )
    {
        Manufacturers memory manufacturers = manufacturer[_manufacturerId];
        return (
            manufacturers.manufacturerId,
            manufacturers.name,
            manufacturers.accountAddress
        );
    }

    function getAllManufacturers(
        address _contractAddress
    ) public view returns (bytes4[] memory) {
        return allManufacturer[_contractAddress];
    }

    function getProduct(
        bytes4 _productId
    )
        public
        view
        returns (
            bytes4 productQrCode,
            bytes4 productId,
            address manufacturerAddress,
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
            product.manufacturerAddress,
            product.name,
            product.quantity,
            product.price,
            product.timeStamp,
            product.location
        );
    }

    function getProductorStockHistory(
        address _person,
        bool _productOrstock
    ) public view returns (bytes4[] memory) {
        return
            _productOrstock == true
                ? productHistory[_person]
                : stockHistory[_person];
    }

    function getStocks(
        bytes4 _productId
    )
        public
        view
        returns (
            bytes4 productQrCode,
            bytes4 productId,
            address supplier,
            string memory name,
            uint256 quantity,
            uint256 price
        )
    {
        Stock memory stock = stocks[_productId];
        return (
            stock.productQrCode,
            stock.productId,
            stock.supplier,
            stock.name,
            stock.quantity,
            stock.price
        );
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
