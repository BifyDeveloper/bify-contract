// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./WhitelistManagerExtended.sol";

/**
 * @title WhitelistManagerFactory
 * @dev Factory contract for creating WhitelistManagerExtended instances
 */
contract WhitelistManagerFactory is Ownable {
    event WhitelistManagerCreated(
        address indexed creator,
        address indexed managerAddress,
        string name
    );

    mapping(address => address[]) public creatorManagers;
    address[] public allManagers;

    /**
     * @notice Create a new WhitelistManagerExtended instance
     * @param _name Name for the whitelist
     * @return managerAddress Address of the created whitelist manager
     */
    function createWhitelistManager(
        string memory _name
    ) external returns (address managerAddress) {
        WhitelistManagerExtended manager = new WhitelistManagerExtended(_name);

        manager.transferOwnership(msg.sender);

        managerAddress = address(manager);
        creatorManagers[msg.sender].push(managerAddress);
        allManagers.push(managerAddress);

        emit WhitelistManagerCreated(msg.sender, managerAddress, _name);

        return managerAddress;
    }

    /**
     * @notice Create a new WhitelistManagerExtended instance with specific owner
     * @param _name Name for the whitelist
     * @param _owner Target owner for the whitelist manager
     * @return managerAddress Address of the created whitelist manager
     */
    function createWhitelistManagerForOwner(
        string memory _name,
        address _owner
    ) external returns (address managerAddress) {
        require(_owner != address(0), "Invalid owner address");

        WhitelistManagerExtended manager = new WhitelistManagerExtended(_name);

        manager.transferOwnership(_owner);

        managerAddress = address(manager);
        creatorManagers[_owner].push(managerAddress);
        allManagers.push(managerAddress);

        emit WhitelistManagerCreated(_owner, managerAddress, _name);

        return managerAddress;
    }

    /**
     * @notice Get all whitelist managers created by an address
     * @param _creator Creator address
     * @return Array of whitelist manager addresses
     */
    function getCreatorManagers(
        address _creator
    ) external view returns (address[] memory) {
        return creatorManagers[_creator];
    }

    /**
     * @notice Get all whitelist managers
     * @return Array of all whitelist manager addresses
     */
    function getAllManagers() external view returns (address[] memory) {
        return allManagers;
    }
}
