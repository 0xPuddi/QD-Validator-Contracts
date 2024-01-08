// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { LibReentrancyGuardStorage } from './LibReentrancyGuardStorage.sol';

/**
 * @title Utility contract for preventing reentrancy attacks
 */
abstract contract LibReentrancyGuard {
    modifier nonReentrant() {
        LibReentrancyGuardStorage.Layout storage l = LibReentrancyGuardStorage
            .layout();
        require(l.status != 2, 'ReentrancyGuard: reentrant call');
        l.status = 2;
        _;
        l.status = 1;
    }
}