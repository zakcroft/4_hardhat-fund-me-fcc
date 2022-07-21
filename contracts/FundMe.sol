// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";
import "hardhat/console.sol";

// opcode for gas https://github.com/crytic/evm-opcodes
// Storage read and rights are high so optimise there first.

// Error codes are much cheaper
error FundMe__NotOwner();
error FundMe__NotEnoughETH();

/**
    @title A contract for funding
    @author me
    @notice its a demo
*/

contract FundMe {
    //Type declarations
    using PriceConverter for uint256;

    // State Variables
    mapping(address => uint256) private s_addressToAmountFunded;
    address[] private s_funders;
    address private i_owner;
    uint256 public constant MINIMUM_USD = 50 * 10**18;
    AggregatorV3Interface private s_priceFeed;

    // modifiers
    modifier onlyOwner() {
        // require(msg.sender == owner);
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    // Functions Order: Style guide
    //// constructor
    //// receive
    //// fallback
    //// external
    //// public
    //// internal
    //// private
    //// view / pure

    constructor(address priceFeedAddress) {
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
        i_owner = msg.sender;
        //console.log("Price feed address set", priceFeedAddress);
    }

    receive() external payable {
        // safe guard funds sent to contract address and no calldata is provided (no function)
        fund();
    }

    fallback() external payable {
        // safe guard funds sent to non existent function in calldata / also if no receive() function.
        fund();
    }

    function fund() public payable {
        if (msg.value.getConversionRate(s_priceFeed) <= MINIMUM_USD) {
            revert FundMe__NotEnoughETH();
        }
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    function withdraw() public payable onlyOwner {
        address[] memory m_funders = s_funders;
        for (
            uint256 funderIndex = 0;
            funderIndex < m_funders.length;
            funderIndex++
        ) {
            address funder = m_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);

        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    // making variable Private from public save a small amount of gas.
    // Also adding the getter hides the s_ for storage variables from public users calling the contract
    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getFunders(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(address addr)
        public
        view
        returns (uint256)
    {
        return s_addressToAmountFunded[addr];
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}
