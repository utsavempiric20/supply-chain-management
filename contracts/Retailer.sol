// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Distributor.sol";

contract Retailer {
    struct Retailers {
        bytes4 retailerId;
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
        address distributor;
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

    mapping(bytes4 => Retailers) retailer;
    mapping(address => bytes4[]) allRetailer;
    mapping(address => bool) retailerExistStatus;

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

    modifier retailerExist(address _retailerAddress) {
        require(
            !retailerExistStatus[_retailerAddress],
            "Retailer already exist."
        );
        _;
    }

    modifier onlyRetailer(address _retailerAddress) {
        require(
            retailerExistStatus[_retailerAddress],
            "Retailer doesn't exist."
        );
        _;
    }

    function registerRetailer(
        string memory _name
    ) public retailerExist(msg.sender) {
        bytes4 retailerId = bytes4(
            keccak256(abi.encodePacked(_name, msg.sender, block.timestamp))
        );
        Retailers memory _retailers = Retailers({
            retailerId: retailerId,
            name: _name,
            accountAddress: msg.sender
        });
        retailer[retailerId] = _retailers;
        allRetailer[address(this)].push(retailerId);
        retailerExistStatus[msg.sender] = true;
    }

    function addProduct(
        string memory _name,
        uint256 _quantity,
        uint256 _price
    ) public onlyRetailer(msg.sender) returns (bytes4) {
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

    // For Customer Interaction
    function buyProductByCustomer(
        bytes4 _productId,
        address _to,
        uint256 _quantity
    ) public productExist(_productId) onlyRetailer(_to) {
        require(
            products[_productId].quantity >= _quantity,
            "Quantity Not Available"
        );
        products[_productId].quantity -= _quantity;
    }

    // For Customer Interaction
    function receivePaymentFromCustomer(
        bytes4 _productId,
        address _from,
        address _to,
        uint256 _quantity,
        uint256 _amount
    )
        public
        payable
        productExist(_productId)
        onlyRetailer(_to)
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

    // Interact with Distributor
    function purchaseProductsFromDistributor(
        address _distributorContractAddress,
        address _distributorAddress,
        bytes4 _productId,
        uint256 _quantity
    ) public onlyRetailer(msg.sender) {
        Distributor(_distributorContractAddress).purchaseProductByRetailer(
            _productId,
            _distributorAddress,
            _quantity
        );
        (, string memory name, , uint256 price) = Distributor(
            _distributorContractAddress
        ).getProduct(_productId);

        if (stocks[_productId].productId != _productId) {
            Stock memory _stocks = Stock({
                productId: _productId,
                distributor: _distributorAddress,
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

    // Interact with Distributor
    function recieveProductsFromDistributor(
        address _distributorContractAddress,
        address _distributor,
        address _retailer,
        bytes4 _productId,
        uint256 _quantity,
        uint256 _amount
    ) public payable onlyRetailer(msg.sender) {
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
        ) = Distributor(_distributorContractAddress).receivePaymentFromRetailer{
                value: msg.value
            }(_productId, _retailer, _distributor, _quantity, _amount);

        payments[paymentId].paymentId = paymentId;
        payments[paymentId].productId = _productId;
        payments[paymentId].from = _retailer;
        payments[paymentId].to = _distributor;
        payments[paymentId].amount = amount;
        payments[paymentId].timeStamp = timeStamp;
        payments[paymentId].isDone = isDone;
        paymentHistory[msg.sender].push(paymentId);
    }

    function getRetailer(
        bytes4 _retailerId
    )
        public
        view
        returns (bytes4 retailerId, string memory name, address accountAddress)
    {
        Retailers memory retailers = retailer[_retailerId];
        return (retailers.retailerId, retailers.name, retailers.accountAddress);
    }

    function getAllRetailers(
        address _contractAddress
    ) public view returns (bytes4[] memory) {
        return allRetailer[_contractAddress];
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
            address distributor,
            string memory name,
            uint256 quantity,
            uint256 price
        )
    {
        Stock memory stock = stocks[_productId];
        return (
            stock.productId,
            stock.distributor,
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
