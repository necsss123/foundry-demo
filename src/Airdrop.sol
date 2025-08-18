// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Airdrop {
    error Airdrop__AddrNotEmpty();
    error Airdrop__NonUserCall();
    error Airdrop__AlreadyClaimed();
    error Airdrop__FailedToCollect();

    IERC20 private immutable i_airdropToken;
    uint256 private s_totalTokensWithdrawn;

    mapping(address => bool) private s_wasClaimed;
    uint256 public constant TOKENS_PER_CLAIM = 100 * 1e18;

    event TokensAirdropped(address indexed beneficiary);

    constructor(address _airdropToken) {
        if (_airdropToken == address(0)) {
            revert Airdrop__AddrNotEmpty();
        }

        i_airdropToken = IERC20(_airdropToken);
    }

    function withdrawTokens() public {
        if (msg.sender != tx.origin) {
            revert Airdrop__NonUserCall();
        }

        address beneficiary = msg.sender;

        if (s_wasClaimed[beneficiary]) {
            revert Airdrop__AlreadyClaimed();
        }

        s_wasClaimed[msg.sender] = true;

        bool success = i_airdropToken.transfer(beneficiary, TOKENS_PER_CLAIM);

        if (!success) {
            revert Airdrop__FailedToCollect();
        }

        s_totalTokensWithdrawn = s_totalTokensWithdrawn + TOKENS_PER_CLAIM;
        emit TokensAirdropped(beneficiary);
    }

    /*
     * Getter Functions
     */

    function getAirdropToken() public view returns (address) {
        return address(i_airdropToken);
    }
}
