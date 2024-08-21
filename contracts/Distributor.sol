// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Manufacturer.sol";

contract Distributor {
    struct Distributors {
        bytes4 distributorId;
        string name;
        address accountAddress;
    }

    struct Product {
        bytes4 productId;
        string name;
        uint256 quantity;
        uint256 price;
    }

    struct Stock {
        bytes4 productId;
        address manufacturer;
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

    uint256 ETHER_WEI_VALUE = 1e18;

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
        string memory _name,
        uint256 _quantity,
        uint256 _price
    ) public onlyDistributor(msg.sender) returns (bytes4) {
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
        productExitStatus[_productId] = true;
        productHistory[msg.sender].push(_productId);
        return _productId;
    }

    // For Retailer Interaction
    function purchaseProductByRetailer(
        bytes4 _productId,
        address _to,
        uint256 _quantity
    ) public productExist(_productId) onlyDistributor(_to) {
        require(
            products[_productId].quantity >= _quantity,
            "Quantity Not Available"
        );
        products[_productId].quantity -= _quantity;
    }

    // For Retailer Interaction
    function receivePaymentFromRetailer(
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

    // Interact with Manufacturer
    function purchaseProductsFromManufacturer(
        address _manufacturerContractAddress,
        address _manufacturerAddress,
        bytes4 _productId,
        uint256 _quantity
    ) public onlyDistributor(msg.sender) {
        Manufacturer(_manufacturerContractAddress).purchaseProductByDistributor(
            _productId,
            _manufacturerAddress,
            _quantity
        );
        (, string memory name, , uint256 price) = Manufacturer(
            _manufacturerContractAddress
        ).getProduct(_productId);

        if (stocks[_productId].productId != _productId) {
            Stock memory _stocks = Stock({
                productId: _productId,
                manufacturer: _manufacturerAddress,
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

    // Interact with Manufacturer
    function recieveProductsFromManufacturer(
        address _manufacturerContractAddress,
        address _manufacturer,
        address _distributor,
        bytes4 _productId,
        uint256 _quantity,
        uint256 _amount
    ) public payable onlyDistributor(msg.sender) {
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
        ) = Manufacturer(_manufacturerContractAddress)
                .receivePaymentFromDistributor{value: msg.value}(
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
        payments[paymentId].amount = amount;
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
            bytes4 productId,
            address manufacturer,
            string memory name,
            uint256 quantity,
            uint256 price
        )
    {
        Stock memory stock = stocks[_productId];
        return (
            stock.productId,
            stock.manufacturer,
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
