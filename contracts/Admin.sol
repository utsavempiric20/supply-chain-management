// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Supplier.sol";
import "./Manufacturer.sol";
import "./Distributor.sol";
import "./Retailer.sol";

contract Admin {
    address admin;

    mapping(address => address[]) suppliers;
    mapping(address => address[]) manufacturers;
    mapping(address => address[]) distributors;
    mapping(address => address[]) retailers;

    constructor() {
        admin = msg.sender;
    }

    function addSuppliers(address _productSupplyCycle) public {
        Supplier supplier = new Supplier(_productSupplyCycle);
        suppliers[msg.sender].push(address(supplier));
    }

    function addManufacturers(address _productSupplyCycle) public {
        Manufacturer manufacturer = new Manufacturer(_productSupplyCycle);
        manufacturers[msg.sender].push(address(manufacturer));
    }

    function addDistributors(address _productSupplyCycle) public {
        Distributor distributor = new Distributor(_productSupplyCycle);
        distributors[msg.sender].push(address(distributor));
    }

    function addRetailers(address _productSupplyCycle) public {
        Retailer retailer = new Retailer(_productSupplyCycle);
        retailers[msg.sender].push(address(retailer));
    }

    function getAllSuppliers() public view returns (address[] memory) {
        return suppliers[msg.sender];
    }

    function getAllManufacturers() public view returns (address[] memory) {
        return manufacturers[msg.sender];
    }

    function getAllDistributors() public view returns (address[] memory) {
        return distributors[msg.sender];
    }

    function getAllRetailers() public view returns (address[] memory) {
        return retailers[msg.sender];
    }
}
