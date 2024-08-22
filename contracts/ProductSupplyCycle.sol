// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ProductSupplyCycle {
    struct ProductCycle {
        bytes4 productQrCode;
        bytes4 supplierProductId;
        bytes4 manufacturerProductId;
        bytes4 distributorProductId;
        bytes4 retailerProductId;
    }

    mapping(bytes4 => ProductCycle) productLifeCycle;

    function setSupplierProductIdUgid(
        bytes4 _productQrCode,
        bytes4 _supplierProductId
    ) public {
        productLifeCycle[_productQrCode].productQrCode = _productQrCode;
        productLifeCycle[_productQrCode].supplierProductId = _supplierProductId;
    }

    function setManufacturerProductIdUgid(
        bytes4 _productQrCode,
        bytes4 _manufacturerProductId
    ) public {
        productLifeCycle[_productQrCode]
            .manufacturerProductId = _manufacturerProductId;
    }

    function setDistributorProductIdUgid(
        bytes4 _productQrCode,
        bytes4 _distributorProductId
    ) public {
        productLifeCycle[_productQrCode]
            .distributorProductId = _distributorProductId;
    }

    function setRetailerProductIdUgid(
        bytes4 _productQrCode,
        bytes4 _retailerProductId
    ) public {
        productLifeCycle[_productQrCode].retailerProductId = _retailerProductId;
    }

    function getProductFullDetails(
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
        ProductCycle memory productCycle = productLifeCycle[_productQrCode];
        return (
            productCycle.productQrCode,
            productCycle.supplierProductId,
            productCycle.manufacturerProductId,
            productCycle.distributorProductId,
            productCycle.retailerProductId
        );
    }
}
