interface ICompound {
    function supply(address asset, address borrowAsset, uint256 amount) external;
    function borrow(address asset, address borrowAsset, uint256 amount) external;
    function repayBorrow(address asset, address borrowAsset, uint256 amount) external;
}