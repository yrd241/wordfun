// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/WordGambling.sol";
import "../src/WordFunToken.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // 首先部署 WordFunToken
        WordFunToken wordFunToken = new WordFunToken();
        
        // 然后部署 WordGambling 合约
        WordGambling gambling = new WordGambling(address(wordFunToken));

        vm.stopBroadcast();
        
        console.log("WordFunToken deployed at:", address(wordFunToken));
        console.log("WordGambling deployed at:", address(gambling));
    }
} 