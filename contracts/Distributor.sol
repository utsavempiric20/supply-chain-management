// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Manufacturer.sol";
import "./ProductSupplyCycle.sol";

contract Distributor {
    ProductSupplyCycle productSupplyCycle;

    struct Distributors {
        bytes4 distributorId;
        string name;
        address accountAddress;
    }

    struct Product {
        bytes4 productQrCode;
        bytes4 productId;
        address distributorAddress;
        string name;
        uint256 quantity;
        uint256 price;
        uint256 timeStamp;
        string location;
    }

    struct Stock {
        bytes4 buyingId;
        bytes4 productQrCode;
        bytes4 productId;
        address manufacturer;
        string name;
        uint256 newStock;
        uint256 oldStock;
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

    mapping(bytes4 => Distributors) distributor;
    mapping(address => bytes4[]) allDistributor;
    mapping(address => bool) distributorExistStatus;

    mapping(bytes4 => Product) products;
    mapping(bytes4 => bool) productExitStatus;
    mapping(address => bytes4[]) productHistory;

    mapping(bytes4 => Payment) payments;
    mapping(address => bytes4[]) paymentHistory;

    mapping(bytes4 => Stock) stocks;
    mapping(address => bytes4[]) stockHistory;

    mapping(bytes4 => Sell) productSell;
    mapping(address => bytes4[]) sellingHistory;
    mapping(bytes4 => mapping(address => bool)) sellPaymentDone;

    modifier productExist(bytes4 _productId) {
        require(productExitStatus[_productId], "Product doesn't Exist");
        _;
    }

    modifier distributorExist(address _manufacturerAddress) {
        require(
            !distributorExistStatus[_manufacturerAddress],
            "Distributor already exist."
        );
        _;
    }

    modifier onlyDistributor(address _distributorAddress) {
        require(
            distributorExistStatus[_distributorAddress],
            "Distributor doesn't exist."
        );
        _;
    }

    constructor(address _productSupplyCycle) {
        productSupplyCycle = ProductSupplyCycle(_productSupplyCycle);
    }

    function registerDistributor(
        string memory _name
    ) public distributorExist(msg.sender) {
        bytes4 distributorId = bytes4(
            keccak256(abi.encodePacked(_name, msg.sender, block.timestamp))
        );
        Distributors memory _distributors = Distributors({
            distributorId: distributorId,
            name: _name,
            accountAddress: msg.sender
        });
        distributor[distributorId] = _distributors;
        allDistributor[address(this)].push(distributorId);
        distributorExistStatus[msg.sender] = true;
    }

    function addProduct(
        bytes4 _productQrCode,
        string memory _name,
        uint256 _quantity,
        uint256 _price,
        string memory _location
    ) public onlyDistributor(msg.sender) returns (bytes4) {
        bytes4 _productId = bytes4(
            keccak256(abi.encodePacked(_name, _price, block.timestamp))
        );
        Product memory product = Product({
            productQrCode: _productQrCode,
            productId: _productId,
            distributorAddress: msg.sender,
            name: _name,
            quantity: _quantity,
            price: _price,
            timeStamp: block.timestamp,
            location: _location
        });
        products[_productId] = product;
        productExitStatus[_productId] = true;
        productHistory[msg.sender].push(_productId);

        productSupplyCycle.setDistributorProductIdUgid(
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
        Product storage product = products[_productId];
        product.quantity = _quantity;
        product.price = _price;
        product.timeStamp = block.timestamp;
        product.location = _location;
    }

    // For Retailer Interaction
    function purchaseProductByRetailer(
        bytes4 _productId,
        address _from,
        address _to,
        uint256 _quantity
    ) public productExist(_productId) onlyDistributor(_to) returns (bytes4) {
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

    // For Retailer Interaction
    function receivePaymentFromRetailer(
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
        onlyDistributor(_to)
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

        (paymentId, timeStamp, isDone) = receivePayment(
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

    function receivePayment(
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

    // Interact with Manufacturer
    function purchaseProductsFromManufacturer(
        address _manufacturerContractAddress,
        address _manufacturerAddress,
        address _distributorAddress,
        bytes4 _productId,
        uint256 _quantity
    ) public onlyDistributor(msg.sender) {
        bytes4 _sellId = Manufacturer(_manufacturerContractAddress)
            .purchaseProductByDistributor(
                _productId,
                _distributorAddress,
                _manufacturerAddress,
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

        ) = Manufacturer(_manufacturerContractAddress).getProduct(_productId);

        if (stocks[_productId].productId != _productId) {
            Stock memory _stocks = Stock({
                buyingId: _sellId,
                productQrCode: productQrCode,
                productId: _productId,
                manufacturer: _manufacturerAddress,
                name: name,
                newStock: _quantity,
                oldStock: 0,
                price: price
            });
            stocks[_productId] = _stocks;
            stockHistory[msg.sender].push(_productId);
        } else {
            stocks[_productId].oldStock += stocks[_productId].newStock;
            stocks[_productId].newStock = _quantity;
        }
    }

    // Interact with Manufacturer
    function recieveProductsFromManufacturer(
        address _manufacturerContractAddress,
        address _manufacturer,
        address _distributor,
        bytes4 _buyingId,
        bytes4 _productId,
        uint256 _quantity,
        uint256 _amount
    ) public payable onlyDistributor(msg.sender) {
        require(stocks[_productId].newStock == _quantity, "InValid Quantity");
        require(
            _amount == stocks[_productId].price * _quantity,
            "Insufficiant amount"
        );
        require(msg.value == _amount, "InValid Value");
        (bytes4 paymentId, uint256 timeStamp, bool isDone) = Manufacturer(
            _manufacturerContractAddress
        ).receivePaymentFromDistributor{value: msg.value}(
            _buyingId,
            _productId,
            _distributor,
            _manufacturer,
            _quantity,
            _amount
        );

        payments[paymentId].paymentId = paymentId;
        payments[paymentId].productId = _productId;
        payments[paymentId].from = _distributor;
        payments[paymentId].to = _manufacturer;
        payments[paymentId].amount = _amount;
        payments[paymentId].timeStamp = timeStamp;
        payments[paymentId].isDone = isDone;
        paymentHistory[msg.sender].push(paymentId);
    }

    function getDistributor(
        bytes4 _distributorId
    )
        public
        view
        returns (
            bytes4 distributorId,
            string memory name,
            address accountAddress
        )
    {
        Distributors memory distributors = distributor[_distributorId];
        return (
            distributors.distributorId,
            distributors.name,
            distributors.accountAddress
        );
    }

    function getAllDistributors(
        address _contractAddress
    ) public view returns (bytes4[] memory) {
        return allDistributor[_contractAddress];
    }

    function getProduct(
        bytes4 _productId
    )
        public
        view
        returns (
            bytes4 productQrCode,
            bytes4 productId,
            address distributorAddress,
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
            product.distributorAddress,
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
            bytes4 buyingId,
            bytes4 productQrCode,
            bytes4 productId,
            address manufacturer,
            string memory name,
            uint256 newStock,
            uint256 oldStock,
            uint256 price
        )
    {
        Stock memory stock = stocks[_productId];
        return (
            stock.buyingId,
            stock.productQrCode,
            stock.productId,
            stock.manufacturer,
            stock.name,
            stock.newStock,
            stock.oldStock,
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
