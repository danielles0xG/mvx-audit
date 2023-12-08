// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC2981, IERC165} from "@openzeppelin-contracts/interfaces/IERC2981.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Stages, Collection} from "../libs/MvxStruct.sol";
import {Clone} from "../../lib/solady/src/utils/Clone.sol"; 

abstract contract MintingStages is Clone, AccessControl, ERC721Upgradeable, IERC2981 {
    /// sender => mintType => counter amount
    mapping(address => mapping(bytes4 => uint256)) public mintsPerWallet;

    /* ACCESS ROLES */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* MINTER ROLES */
    bytes32 public constant WL_MINTER_ROLE = keccak256("WL_MINTER_ROLE");
    bytes32 public constant OG_MINTER_ROLE = keccak256("OG_MINTER_ROLE");

    Stages public mintingStages;
    Collection public collectionData;
    address public platformFeeReceiver;
    uint72 public updateStageFee;

    uint16 public platformFee;
    uint8 public publicStageWeeks;
    uint40 public stageTimeCap;
    bool public initalized = false;

    event UpdateWLevent(address indexed sender, uint256 listLength);
    event UpdateOgEvent(address indexed sender, uint256 listLength);
    event WithdrawEvent(address sender, uint256 balance, address feeReceiver, uint256 fee);
    event OGmintEvent(address indexed sender, uint256 value, address to, uint256 amount, uint256 _ogMintPrice);
    event WLmintEvent(address indexed sender, uint256 value, address to, uint256 amount, uint256 wlMintPrice);
    event MintEvent(address indexed sender, uint256 value, address to, uint256 amount, uint256 mintPrice);
    event OwnerMintEvent(address indexed sender, address to, uint256 amount);
    event RoyaltyFeeUpdate(address indexed sender, address receiver, uint96 royaltyFee);
    event BurnEvent(address indexed sender, uint256 tokenId);
    event ValidStages();
    // event Log(string, uint8);
    event Log(string, address);
    event Log(string, uint256);

    error TokenNotExistsError();
    error FixedMaxSupply();
    error WithdrawError(uint8 isPlaformCall); // 0 = yes, 1 = no, fail admin
    error MintForOwnerError(uint8);
    error MintError(bytes4, uint8);
    error RoyaltyFeeError(uint8);
    error InvalidCollectionData(uint8);

    modifier OnlyAdminOrOperator() {
        require(hasRole(ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Only Admin or Operator");
        _;
    }


    function _msgData() internal view override(ContextUpgradeable,Context) returns (bytes calldata) {
        return msg.data;
    }

    function _msgSender() internal view override(ContextUpgradeable,Context) returns (address) {
        return super._msgSender();
    }
    /// OG MINTING
    function updateOGMintPrice(uint72 _price) external OnlyAdminOrOperator {
        require(_price > 0, "Invalid price amount");
        mintingStages.ogMintPrice = _price;
    }

    function updateOGMintMax(uint16 _ogMintMax) external OnlyAdminOrOperator {
        require(_ogMintMax > 0, "Invalid max amount");
        mintingStages.ogMintMaxPerUser = _ogMintMax;
    }

    /// WL MINTING
    function updateWhitelistMintPrice(uint72 _whitelistMintPrice) external OnlyAdminOrOperator {
        require(_whitelistMintPrice > 0, "Invalid price amount");
        mintingStages.whitelistMintPrice = _whitelistMintPrice;
    }

    function updateWLMintMax(uint16 _whitelistMintMax) external OnlyAdminOrOperator {
        require(_whitelistMintMax > 0, "Invalid max amount");
        mintingStages.whitelistMintMaxPerUser = _whitelistMintMax;
    }

    // REGULAR MINTING
    function updateMintPrice(uint72 _mintPrice) external OnlyAdminOrOperator {
        require(_mintPrice > 0, "Invalid price amount");
        mintingStages.mintPrice = _mintPrice;
    }

    function updateMintMax(uint16 _mintMax) external OnlyAdminOrOperator {
        require(_mintMax > 0, "Invalid mint amount");
        mintingStages.mintMaxPerUser = _mintMax;
    }

    /// @param _minterList address array of OG's or WL's
    /// @param _mintRole 0 = OG, 1 = WL
    /// @dev reverts if any address in the array is address zero
    function updateMinterRoles(address[] calldata _minterList, uint8 _mintRole) public OnlyAdminOrOperator {
        require(_mintRole == 0 || _mintRole == 1, "Error only OG=0,WL=1");
        uint256 minters = _minterList.length;
        if (minters > 0) {
            for (uint256 i; i < minters;) {
                require(_minterList[i] != address(0x0), "Invalid Address");
                _mintRole == 0 ? _grantRole(OG_MINTER_ROLE, _minterList[i]) : _grantRole(WL_MINTER_ROLE, _minterList[i]);
                unchecked {
                    ++i;
                }
            }
        }
    }

    function supportsInterface(bytes4 _interfaceId) public view override(AccessControl,ERC721Upgradeable,IERC165) returns (bool) {
        return _interfaceId == type(IERC2981).interfaceId
            || super.supportsInterface(_interfaceId);
    }

    function _maxDiff(uint40 a, uint40 b) internal returns (uint40) {
        if (b > a) {
            return b - a;
        } else {
            revert InvalidCollectionData(1);
        }
    }

    /// @notice Ensures stage order as 1st og, 2nd wl, 3rd public, even is one is not present.
    function _validateCollection(uint128 maxSupply,Stages calldata mintingStages_) internal returns(Stages memory _stg){
        _stg = mintingStages_;
        if(_stg.mintMaxPerUser + _stg.ogMintMaxPerUser + _stg.whitelistMintMaxPerUser > maxSupply) revert InvalidCollectionData(2);
        uint256 ogTime = _stg.ogMintStart > 0 ? _maxDiff(_stg.ogMintStart, _stg.ogMintEnd) : 0;
        uint256 wlTime = _stg.whitelistMintStart > 0 ? _maxDiff(_stg.whitelistMintStart, _stg.whitelistMintEnd) : 0;
        uint256 pbTime = _stg.mintStart > 0 ? _maxDiff(_stg.mintStart, _stg.mintEnd) : 0;
        if ((ogTime + wlTime + pbTime) > (60 * 60 * 24 * stageTimeCap)) revert InvalidCollectionData(3);
        emit ValidStages();
    }
}
