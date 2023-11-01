// SPDX-License-Identifier: MIT O
pragma solidity 0.8.20;

import "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {
    IMvxCollection,
    Ownable,
    Math,
    LibClone,
    Stages,
    Member,
    Collection,
    Artist,
    Partner
} from "./lib/FactoryLibs.sol";

//
// ███╗   ███╗██╗   ██╗██╗  ██╗ ██████╗  █████╗ ██████╗
// ████╗ ████║██║   ██║╚██╗██╔╝ ██╔══██╗██╔══██╗██╔══██╗
// ██╔████╔██║██║   ██║ ╚███╔╝  ██████╔╝███████║██║  ██║
// ██║╚██╔╝██║╚██╗ ██╔╝ ██╔██╗  ██╔═══╝ ██╔══██║██║  ██║
// ██║ ╚═╝ ██║ ╚████╔╝ ██╔╝ ██╗ ██║     ██║  ██║██████╔╝
// ╚═╝     ╚═╝  ╚═══╝  ╚═╝  ╚═╝ ╚═╝     ╚═╝  ╚═╝╚═════╝
//
/// @title MvxPad
/// @author Moonvera
/// @dev Handles Mvx Launchpad Partners
/// @dev Creates minimal proxies clones of ERC721A
contract MvxFactory is OwnableUpgradeable, UUPSUpgradeable {
    using Math for uint256;

    // Current IMvxCollection template
    address public collectionImpl;

    // nft collection deploy fee
    uint256 public collectionCount;

    mapping(address => Artist) public artists; // artists addr => Artist data, expires
    mapping(address => Partner) public partners; // collection addr => Collection data, expires
    mapping(address => Member) public members; // Members addr => Member data, expires

    error InvalidColletion();
    error Unathorized();
    error UpdatePartnerError();
    error AdminWithdrawError();
    error DiscountError(uint8);
    error GrantReferralError(uint8);
    error WithdrawPartnerError(uint8);
    error WithdrawReferralError(uint8);
    error UpdateMemberError(uint8);
    error CreateError(uint8);

    event WithdrawAdmin(uint256 amount);
    event CreateEvent(address indexed _sender, address _impl, address _cloneAddress);
    event MemberDiscount(address indexed _sender, uint256 _deployFee,uint256 _discountAmt);
    event ArtistDiscount(address indexed _sender, uint256 _deployFee,uint256 _discountAmt);
    event GrantReferralDiscount(address indexed _artist, address _sender, address _collection);
    event WithdrawPartner(address indexed _sender, address _collection, uint256 _balance);
    event WithdrawReferral(address indexed _sender, address _artist, uint256 _referralBalance);
    event ReferralBalanceUpdate(address indexed _referral, uint256 _amount);
    event PartnerBalanceUpdate(address indexed _partner, uint256 _balance);
    event UpdateCollectionImpl(address _newImpl);
    
    event UpdatePartner(Partner);
    event UpdateMember(Member);
    event FactoryBalanceUpdate(uint256);

    modifier auth() {
        require(msg.sender == owner() || members[msg.sender].expiration > block.timestamp, "Auth");
        _;
    }

    function initialize() public initializer {
        __Ownable_init_unchained();
    }

    receive() external payable {}

    fallback() external payable {
        revert Unathorized();
    }

    ///0x0000000000000000000000000000000000000000000000000000000000000000
    ///                     OWNER UPDATES
    ///0x0000000000000000000000000000000000000000000000000000000000000000

    /// @notice Grants create colletion rights to MVX member
    function updateMember(
        address _newMember,
        address _collection,
        uint256 _deployFee, // fixed amount
        uint96 _platformFee, // percent basis points
        uint96 _discount, // percent basis points
        uint256 _expirationDays
    ) external payable onlyOwner {
        if (_newMember == address(0x0)) revert UpdateMemberError(1);
        require(_platformFee < 10_000 && _discount < 10_000);

        members[_newMember] = Member({
            collection: _collection,
            deployFee: _deployFee,
            platformFee: _platformFee,
            discount: _discount,
            expiration: block.timestamp + (_expirationDays * 60 * 60 * 24)
        });
        emit UpdateMember(members[_newMember]);
    }

    /// @notice All percentages are in bp
    function updatePartnership(
        address _collection,
        address _admin,
        uint96 _adminOwnPercent,
        uint96 _referralOwnPercent,
        uint96 _discountPercent,
        uint40 _expireDaysFromNow
    ) external onlyOwner {
        if (_admin == address(0x0)) revert UpdatePartnerError();
        partners[_collection] = Partner({
            admin: _admin,
            adminOwnPercent: _adminOwnPercent,
            referralOwnPercent: _referralOwnPercent,
            balance: 0,
            discount: _discountPercent,
            expiration: uint40(block.timestamp + (_expireDaysFromNow * (60 * 60 * 24)))
        });
        emit UpdatePartner(partners[_collection]);
    }

    /// @notice Access: only Owner
    /// @param _impl Clone's proxy implementation of IMvxCollection logic
    /// @dev payable for gas saving
    function updateCollectionImpl(address _impl) external payable onlyOwner {
        if (!IMvxCollection(_impl).supportsInterface(0xc21b8f28)) {
            // ERC721A interface Id
            revert InvalidColletion();
        }
        collectionImpl = _impl;
        emit UpdateCollectionImpl(collectionImpl);
    }

    function deletePartnership(address _collection) external onlyOwner {
        delete partners[_collection];
    }

    function deleteArtist(address _artist) external onlyOwner {
        delete artists[_artist];
    }

    function deleteMember(address _member) external onlyOwner {
        delete members[_member];
    }

    ///0x0000000000000000000000000000000000000000000000000000000000000000
    ///                         WITHDRAWS
    ///0x0000000000000000000000000000000000000000000000000000000000000000

    function withdraw() external payable onlyOwner {
        uint256 _balance = address(this).balance;
        (bool sent,) = payable(msg.sender).call{value: _balance}("");
        if (!sent) revert AdminWithdrawError();
        emit WithdrawAdmin(_balance);
    }

    function withdrawPartner(address _collection) external {
        address _sender = payable(msg.sender);
        Partner memory _partner = partners[_collection];
        uint256 _balance = _partner.balance;
        if (_partner.admin != _sender) revert WithdrawPartnerError(1);
        if (!(_balance > 0)) revert WithdrawPartnerError(2);
        _partner.balance = 0;
        (bool sent,) = _sender.call{value: _balance}("");
        if (!sent) revert WithdrawPartnerError(3);
        emit WithdrawPartner(_sender, _collection, _balance);
    }

    function withdrawReferral(address artist_) external {
        address _sender = msg.sender;
        Artist memory _artist = artists[artist_];
        if (_artist.referral != _sender) revert WithdrawReferralError(1);
        uint256 _referralBalance = _artist.referralBalance;
        if (_referralBalance == 0) revert WithdrawReferralError(2);
        delete artists[artist_];
        (bool sent,) = _sender.call{value: _referralBalance}("");
        if (!sent) revert WithdrawReferralError(3);
        emit WithdrawReferral(_sender, artist_, _referralBalance);
    }

    ///0x0000000000000000000000000000000000000000000000000000000000000000
    ///                      GRANT REFERRALS
    ///0x0000000000000000000000000000000000000000000000000000000000000000

    /// @notice Access: owner & members of any collection created with this launchpad contract
    /// @dev Only valid if there is a partnership/discount between the collection admin and Mvx
    /// @dev 10 days max to use referral discount
    function grantReferral(address _extCollection, address _artist) external {
        address _referral = msg.sender;
        
        // Check if msg.sender is part of the Collection.
        bool isCollectionMember = IMvxCollection(_extCollection).balanceOf(_referral) > 0;
        if (!isCollectionMember) revert GrantReferralError(1);
        Partner memory partner = partners[_extCollection];

        // Check if the collection has a current partnership with mvx.
        bool hasDiscount = partner.discount > 0 && partner.expiration > block.timestamp;
        if (!hasDiscount) revert GrantReferralError(2);

        // If referral is artist - No need to use referral system, talk to mvx admin.
        if(_referral == _artist) revert GrantReferralError(3);

        // Check if artist has a referral already - only one referral allowed per artist per collection
        if (artists[_artist].referral != address(0x0)) revert GrantReferralError(4);

        artists[_artist] = Artist(_referral, 0, _extCollection); // 20% referrals
        emit GrantReferralDiscount(_artist, _referral, _extCollection);
    }

    ///0x0000000000000000000000000000000000000000000000000000000000000000
    ///                      CREATE COLLECTION
    ///0x0000000000000000000000000000000000000000000000000000000000000000
    event Log(string,address);
    event Log(string,uint);
    event Log(string);
    function createCollection(
        Collection calldata _nftsData,
        Stages calldata _mintingStages,
        address[] calldata _ogs,
        address[] calldata _wls
    ) external payable auth returns (address _clone) {
        address _sender = msg.sender;
        uint256 _msgValue = msg.value;

        Artist memory _artist = artists[_sender];
        Member memory member = members[_sender];
        uint256 _deployFee = member.deployFee;

         // Apply member discount over Artist discount
        if (member.discount > 0) {

            uint256 _discountAmt =  _percent(_deployFee, member.discount);
            if (_msgValue < _deployFee - _discountAmt) revert CreateError(1);
            emit MemberDiscount(_sender,_deployFee,_discountAmt);
        
       // Apply artist discount from Partnerhip agreement if has no Member discount
        } else if (_artist.referral != address(0)) {

            Partner memory _partner = partners[_artist.collection];
            uint256 _discountAmount = _percent(_deployFee, _partner.discount);
            if (_msgValue < _deployFee - _discountAmount) revert CreateError(2);
            _applyArtistDiscount(_artist,_partner, _sender, _msgValue, _deployFee,_discountAmount);
             emit ArtistDiscount(_sender,_deployFee,_discountAmount);

        // No discount
        }else{
            if (_msgValue < _deployFee) revert CreateError(3);
        }

        // encode seder to clone immutable arg
        bytes memory data = abi.encodePacked(_sender);

        // Lib clone minimal proxy with immutable args
        _clone = LibClone.clone(address(collectionImpl), data);
        if (_clone == address(0)) revert CreateError(4);

        // Init Art collection minimal proxy clone
        IMvxCollection(_clone).initialize(
            member.platformFee, // set by MvxFactory owner
            _nftsData,
            _mintingStages,
            _ogs,
            _wls
        );

        // Member single time deploy
        member.expiration = 0;
        member.collection = _clone;
        members[_sender] = member;
        unchecked {
            collectionCount = collectionCount + 1;
        }
        emit CreateEvent(_sender, collectionImpl, _clone);
    }

    ///0x0000000000000000000000000000000000000000000000000000000000000000
    ///                         UI VIEWS
    ///0x0000000000000000000000000000000000000000000000000000000000000000
    function getTime() public view returns (uint256 _time) {
        _time = block.timestamp;
    }

    /// @param _daysFromNow current timestamp plus days
    function getTime(uint256 _daysFromNow) public view returns (uint256 _time) {
        _time = block.timestamp + (_daysFromNow * 60 * 60 * 24);
    }

    function getPartnerBalance(address _collection) public view returns (uint256 _balance) {
        _balance = partners[_collection].balance;
    }

    function getReferralBalance(address _artist) public view returns (uint256 _balance) {
        _balance = artists[_artist].referralBalance;
    }

    ///0x0000000000000000000000000000000000000000000000000000000000000000
    ///                      INTERNAL LOGIC
    ///0x0000000000000000000000000000000000000000000000000000000000000000
    function _applyArtistDiscount(
        Artist memory _artist,
        Partner memory _partner,
        address _sender,
        uint256 _msgValue, 
        uint256 _deployFee,
        uint256 _discountAmount ) internal {

        uint256 _deployFeeAfterDiscounts = _deployFee - _discountAmount; // - 20% == msg.value
        uint256 remain = _deployFeeAfterDiscounts;

        // Update Referral balance
        uint256 _referralAmount = _percent(_deployFeeAfterDiscounts, _partner.referralOwnPercent);
        remain = remain - _referralAmount;

        _artist.referralBalance = _referralAmount;
        artists[_sender] = _artist;
        emit ReferralBalanceUpdate(_artist.referral, _referralAmount);

        // Update Partner balance
        uint256 _partnerAmount = _percent(_deployFeeAfterDiscounts, _partner.adminOwnPercent);
        remain = remain - _partnerAmount;
        _partner.balance = _partner.balance + _partnerAmount;
        partners[_artist.collection] = _partner;
        emit PartnerBalanceUpdate(_partner.admin, _partnerAmount);

        if (remain + _partnerAmount + _referralAmount < _deployFeeAfterDiscounts) revert DiscountError(2);
        emit FactoryBalanceUpdate(remain);
    }

    function _percent(uint256 a, uint96 b) internal pure returns (uint256) {
        return a.mulDiv(b, 10_000);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function upgradeTo(address _newImplementation) public override onlyOwner {
        super.upgradeTo(_newImplementation);
    }
}
