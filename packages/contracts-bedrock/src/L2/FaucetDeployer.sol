// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Interfaces
import { IOptimismPortal2 } from "interfaces/L1/IOptimismPortal2.sol";

import { NativeAssetFaucet } from "src/L2/NativeAssetFaucet.sol";

/// @title ICreate2Deployer
/// @notice Interface for the CREATE2 Deployer predeploy
interface ICreate2Deployer {
    function deploy(uint256 _value, bytes32 _salt, bytes memory _code) external returns (address);
}

contract FaucetDeployer {
    /// @notice The address of the CREATE2 Deployer predeploy on L2.
    address internal constant CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;

    /// @notice The salt prefix for the Faucet system.
    string internal constant SALT_SEED = "Faucet";

    /// @notice Deploys a contract via CREATE2 on L2 by depositing a transaction to the OptimismPortal2
    /// @param _portal The OptimismPortal2 address on L1
    /// @param _creationCode The creation code of the contract to deploy (e.g., type(NativeAssetFaucet).creationCode)
    /// @param _gasLimit Gas limit for the L2 transaction
    /// @param _owner Owner of the NativeAssetFaucet contract
    /// @param _permissionlessAmount Permissionless amount for the NativeAssetFaucet contract
    function depositCreate2(
        address _portal,
        bytes memory _creationCode,
        address _owner,
        uint256 _permissionlessAmount,
        uint64 _gasLimit
    )
        public
    {
        bytes memory _initCode = bytes.concat(_creationCode, abi.encode(_owner, _permissionlessAmount));
        bytes32 _salt = keccak256(abi.encodePacked(SALT_SEED, ":", _owner));
        IOptimismPortal2(payable(_portal)).depositTransaction({
            _to: CREATE2_DEPLOYER,
            _value: 0,
            _gasLimit: _gasLimit,
            _isCreation: false,
            _data: abi.encodeCall(ICreate2Deployer.deploy, (0, _salt, _initCode))
        });
    }

    /// @notice Calls a contract on L2 by depositing a transaction to the OptimismPortal2
    /// @param _portal The OptimismPortal2 address on L1
    /// @param _target Address of the NativeAssetFaucet contract
    /// @param _to Address to mint the tokens to
    /// @param _amount Amount of tokens to mint
    /// @param _gasLimit Gas limit for the L2 transaction
    function depositCall(address _portal, address _target, address _to, uint256 _amount, uint64 _gasLimit) public {
        IOptimismPortal2(payable(_portal)).depositTransaction({
            _to: _target,
            _value: 0,
            _gasLimit: _gasLimit,
            _isCreation: false,
            _data: abi.encodeCall(NativeAssetFaucet.mint, (_to, _amount))
        });
    }
}
