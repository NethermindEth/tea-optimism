// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Test } from "forge-std/Test.sol";
import { FaucetDeployer } from "src/L2/FaucetDeployer.sol";
import { NativeAssetFaucet } from "src/L2/NativeAssetFaucet.sol";

/// @title MockOptimismPortal2
/// @notice Mock contract for IOptimismPortal2 used in testing
contract MockOptimismPortal2 {
    event DepositTransactionCalled(address indexed to, uint256 value, uint64 gasLimit, bool isCreation, bytes data);

    function depositTransaction(
        address _to,
        uint256 _value,
        uint64 _gasLimit,
        bool _isCreation,
        bytes memory _data
    )
        external
        payable
    {
        emit DepositTransactionCalled(_to, _value, _gasLimit, _isCreation, _data);
    }
}

/// @title ICreate2Deployer
/// @notice Interface for the CREATE2 Deployer predeploy
interface ICreate2Deployer {
    function deploy(uint256 _value, bytes32 _salt, bytes memory _code) external returns (address);
}

/// @title FaucetDeployer_TestInit
/// @notice Reusable test initialization for `FaucetDeployer` tests.
abstract contract FaucetDeployer_TestInit is Test {
    FaucetDeployer internal deployer;
    MockOptimismPortal2 internal mockPortal;
    address internal owner;
    address internal recipient;
    uint256 internal permissionlessAmount;
    uint64 internal gasLimit;
    address internal constant CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;

    event DepositTransactionCalled(address indexed to, uint256 value, uint64 gasLimit, bool isCreation, bytes data);

    function setUp() public virtual {
        deployer = new FaucetDeployer();
        mockPortal = new MockOptimismPortal2();
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");
        permissionlessAmount = 1 ether;
        gasLimit = 500_000;
    }
}

/// @title FaucetDeployer_DepositCreate2_Test
/// @notice Tests for the `depositCreate2` function
contract FaucetDeployer_DepositCreate2_Test is FaucetDeployer_TestInit {
    bytes internal creationCode;

    function setUp() public override {
        super.setUp();
        creationCode = type(NativeAssetFaucet).creationCode;
    }

    /// @notice Tests that depositCreate2 correctly calls the portal with proper parameters
    function test_depositCreate2_callsPortal_succeeds() public {
        bytes memory initCode = bytes.concat(creationCode, abi.encode(owner, permissionlessAmount));
        bytes32 salt = keccak256(abi.encodePacked("Faucet", ":", owner));
        bytes memory expectedData = abi.encodeCall(ICreate2Deployer.deploy, (0, salt, initCode));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(CREATE2_DEPLOYER, 0, gasLimit, false, expectedData);

        deployer.depositCreate2(address(mockPortal), creationCode, owner, permissionlessAmount, gasLimit);
    }

    /// @notice Tests that depositCreate2 uses correct salt format
    function test_depositCreate2_usesCorrectSalt_succeeds() public {
        bytes32 expectedSalt = keccak256(abi.encodePacked("Faucet", ":", owner));

        bytes memory initCode = bytes.concat(creationCode, abi.encode(owner, permissionlessAmount));
        bytes memory expectedData = abi.encodeCall(ICreate2Deployer.deploy, (0, expectedSalt, initCode));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(CREATE2_DEPLOYER, 0, gasLimit, false, expectedData);

        deployer.depositCreate2(address(mockPortal), creationCode, owner, permissionlessAmount, gasLimit);
    }

    /// @notice Tests that depositCreate2 encodes constructor arguments correctly
    function test_depositCreate2_encodesConstructorArgs_succeeds() public {
        bytes memory expectedInitCode = bytes.concat(creationCode, abi.encode(owner, permissionlessAmount));
        bytes32 salt = keccak256(abi.encodePacked("Faucet", ":", owner));
        bytes memory expectedData = abi.encodeCall(ICreate2Deployer.deploy, (0, salt, expectedInitCode));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(CREATE2_DEPLOYER, 0, gasLimit, false, expectedData);

        deployer.depositCreate2(address(mockPortal), creationCode, owner, permissionlessAmount, gasLimit);
    }

    /// @notice Tests depositCreate2 with different owners
    function testFuzz_depositCreate2_differentOwners_succeeds(address _owner, uint256 _permissionlessAmount) public {
        vm.assume(_owner != address(0));

        bytes memory initCode = bytes.concat(creationCode, abi.encode(_owner, _permissionlessAmount));
        bytes32 salt = keccak256(abi.encodePacked("Faucet", ":", _owner));
        bytes memory expectedData = abi.encodeCall(ICreate2Deployer.deploy, (0, salt, initCode));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(CREATE2_DEPLOYER, 0, gasLimit, false, expectedData);

        deployer.depositCreate2(address(mockPortal), creationCode, _owner, _permissionlessAmount, gasLimit);
    }

    /// @notice Tests depositCreate2 with different gas limits
    function testFuzz_depositCreate2_differentGasLimits_succeeds(uint64 _gasLimit) public {
        vm.assume(_gasLimit > 21000); // Minimum gas for a transaction

        bytes memory initCode = bytes.concat(creationCode, abi.encode(owner, permissionlessAmount));
        bytes32 salt = keccak256(abi.encodePacked("Faucet", ":", owner));
        bytes memory expectedData = abi.encodeCall(ICreate2Deployer.deploy, (0, salt, initCode));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(CREATE2_DEPLOYER, 0, _gasLimit, false, expectedData);

        deployer.depositCreate2(address(mockPortal), creationCode, owner, permissionlessAmount, _gasLimit);
    }
}

/// @title FaucetDeployer_DepositCall_Test
/// @notice Tests for the `depositCall` function
contract FaucetDeployer_DepositCall_Test is FaucetDeployer_TestInit {
    address internal faucetTarget;

    function setUp() public override {
        super.setUp();
        faucetTarget = makeAddr("faucetTarget");
    }

    /// @notice Tests that depositCall correctly calls the portal with proper parameters
    function test_depositCall_callsPortal_succeeds() public {
        uint256 amount = 10 ether;
        bytes memory expectedData = abi.encodeCall(NativeAssetFaucet.mint, (recipient, amount));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(faucetTarget, 0, gasLimit, false, expectedData);

        deployer.depositCall(address(mockPortal), faucetTarget, recipient, amount, gasLimit);
    }

    /// @notice Tests that depositCall encodes the mint function call correctly
    function test_depositCall_encodesMintCall_succeeds() public {
        uint256 amount = 5 ether;
        bytes memory expectedData = abi.encodeCall(NativeAssetFaucet.mint, (recipient, amount));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(faucetTarget, 0, gasLimit, false, expectedData);

        deployer.depositCall(address(mockPortal), faucetTarget, recipient, amount, gasLimit);
    }

    /// @notice Tests depositCall with different recipients and amounts
    function testFuzz_depositCall_differentRecipients_succeeds(address _recipient, uint256 _amount) public {
        vm.assume(_recipient != address(0));

        bytes memory expectedData = abi.encodeCall(NativeAssetFaucet.mint, (_recipient, _amount));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(faucetTarget, 0, gasLimit, false, expectedData);

        deployer.depositCall(address(mockPortal), faucetTarget, _recipient, _amount, gasLimit);
    }

    /// @notice Tests depositCall with different gas limits
    function testFuzz_depositCall_differentGasLimits_succeeds(uint64 _gasLimit) public {
        vm.assume(_gasLimit > 21000); // Minimum gas for a transaction

        uint256 amount = 1 ether;
        bytes memory expectedData = abi.encodeCall(NativeAssetFaucet.mint, (recipient, amount));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(faucetTarget, 0, _gasLimit, false, expectedData);

        deployer.depositCall(address(mockPortal), faucetTarget, recipient, amount, _gasLimit);
    }

    /// @notice Tests depositCall with zero amount
    function test_depositCall_zeroAmount_succeeds() public {
        uint256 amount = 0;
        bytes memory expectedData = abi.encodeCall(NativeAssetFaucet.mint, (recipient, amount));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(faucetTarget, 0, gasLimit, false, expectedData);

        deployer.depositCall(address(mockPortal), faucetTarget, recipient, amount, gasLimit);
    }

    /// @notice Tests depositCall with different faucet targets
    function testFuzz_depositCall_differentTargets_succeeds(address _target) public {
        vm.assume(_target != address(0));

        uint256 amount = 1 ether;
        bytes memory expectedData = abi.encodeCall(NativeAssetFaucet.mint, (recipient, amount));

        vm.expectEmit(true, true, true, true);
        emit DepositTransactionCalled(_target, 0, gasLimit, false, expectedData);

        deployer.depositCall(address(mockPortal), _target, recipient, amount, gasLimit);
    }
}
