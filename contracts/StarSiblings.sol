// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StarSiblings is ERC1155, Ownable { 

    // Star Sailor Siblings (SSS): 0x49aC61f2202f6A2f108D59E77535337Ea41F6540
    address public burnContractERC721;

    uint256 public currChapter;

    struct Chapter {
        string description;
        string uri;
        address[] starSiblings;
        uint256 burnThreshold;
        uint256 entryLimit;
        uint256 tokenId;
        bool transferable;
        bool unique;
        bool active;
        bool locked;
    }

    mapping(uint256 => Chapter) public chapters;
    mapping(address => mapping(uint256 => uint256)) public entries;

    constructor() ERC1155("") {
        burnContractERC721 = 0x3A0c5DCd221BA43B340EdAC5B7C36662fBF5685d;
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(AdminControl, ERC1155) 
        returns (bool) 
    {
        return 
            ERC1155.supportsInterface(interfaceId) 
            || AdminControl.supportsInterface(interfaceId) 
            || super.supportsInterface(interfaceId);
    }
    
    function updateChapter(
        string memory _description, 
        string memory _uri, 
        address[] memory _starSiblings, 
        uint256 _burnThreshold, 
        uint256 _entryLimit, 
        uint256 _tokenId, 
        bool _transferable, 
        bool _unique,
        bool _active,
        bool _isCurrChapter
    ) external onlyOwner {
        require(!chapters[_tokenId].locked, "You must unlock chapter to overwrite");
        Chapter storage chapter = chapters[_tokenId];
        chapter.description = _description;
        chapter.uri = _uri;
        chapter.starSiblings = _starSiblings;
        chapter.burnThreshold = _burnThreshold;
        chapter.entryLimit = _entryLimit;
        chapter.tokenId = _tokenId;
        chapter.transferable = _transferable;
        chapter.unique = _unique;
        chapter.active = _active;
        chapter.locked = true;

        if (_isCurrChapter) {
            currChapter = _tokenId;
        }
    }

    function burnAvatar(uint256[] calldata tokenIds) external {
        Chapter memory chapter = chapters[currChapter];
        require(chapter.active, "This chapter is not active");
        require(tokenIds.length > 0, "TokenIds can not be empty");
        if (chapter.unique) 
        {
          require(
             entries[msg.sender][currChapter] == 0,
             "This chapter is only accepting unqiue addresses" 
          );  
        }

        bool ovenHungee;
        uint256 amount;
        if (chapter.burnThreshold == 0) 
        {   
            require(
            chapter.starSiblings.length + 1 <= chapter.entryLimit, 
            "Burn limit surpassed"
            );

            ovenHungee = false;
            amount = 1;
        } 
        else 
        {   
            require(
            tokenIds.length % chapter.burnThreshold == 0, 
            "Token(s) amount is not a multiple of threshold"
            );
            require(
            chapter.starSiblings.length + (tokenIds.length / chapter.burnThreshold) <= chapter.entryLimit, 
            "Burn limit surpassed"
            );

            ovenHungee = true;
            amount = tokenIds.length / chapter.burnThreshold;
        }

        address[] memory accounts = new address[](1);
        accounts[0] = msg.sender;

        burn(tokenIds, msg.sender, ovenHungee);
        mint(accounts, amount, chapter.tokenId);
    }

    function awardSiblings(address[] memory accounts, uint256 amount, uint256 _tokenId) 
        external 
        onlyOwner 
    {
        mint(accounts, amount, _tokenId);
    }

    /** 
    * @dev Toggles between 4 bool options within a specified chapter
    * @param _tokenId can also be thought of as index
    * @param option of which bool to toggle 
    * opiton == 1: Permission for the NFT to be tranfered
    * opiton == 2: Criteria if addresses must be unqiue to become a StarSibling
    * opiton == 3: Allows Avatars to be burned and become a StarSibling
    * opiton == 4: Unlocks chapter to overwrite entire chapter (Not recommended)
    */
    function toggleOption(uint256 _tokenId, uint256 option) external onlyOwner {
        Chapter storage chapter = chapters[_tokenId];
        if (option == 1) 
        {
            chapter.transferable = !chapter.transferable;
        }
        else if (option == 2) 
        {
            chapter.unique = !chapter.unique;
        } 
        else if (option == 3) 
        {
            chapter.active = !chapter.active;
        } 
        else if (option == 4) 
        {
            chapter.locked = !chapter.locked;
        }
    }

    function updateCurrentChapter(uint256 _tokenId) external onlyOwner { currChapter = _tokenId; }

    function updateThresholds(uint256 _tokenId, uint256 _burnThreshold, uint256 _entryLimit) 
        external 
        onlyOwner 
    {
        Chapter storage chapter = chapters[_tokenId];
        chapter.burnThreshold = _burnThreshold;
        chapter.entryLimit = _entryLimit;
    }

    function updateBurnContract(address _burnContractERC721) external onlyOwner { 
        burnContractERC721 = _burnContractERC721; 
    }

    function updateURI(uint256 _tokenId, string memory _uri) external onlyOwner {
        Chapter storage chapter = chapters[_tokenId];
        chapter.uri = _uri;
    }

    function uri(uint256 _tokenId) public view virtual override returns (string memory) {
        return chapters[_tokenId].uri;
    }

    function getStars(uint256 _tokenId) public view returns(address[] memory, uint256) {
        Chapter memory chapter = chapters[_tokenId];
        return(chapter.starSiblings, chapter.starSiblings.length);
    }

    /** 
    * @dev Returns an array of random addresses and associating indices from starSiblings
    * @param quantity is the amount of addresses to be pulled from siblingStar 
    * @param seed the chainlink randomly generated number on the polygon network
    */
    function getRandomStars(uint256 _tokenId, uint256 quantity, uint256 seed) 
        public 
        view 
        returns (
            address[] memory addresses,
            uint256[] memory indices 
        ) 
    {   
        Chapter memory chapter = chapters[_tokenId];
        indices = new uint256[](quantity);
        addresses = new address[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 index = uint256(keccak256(abi.encode(seed, i))) % chapter.starSiblings.length;
            addresses[i] = chapter.starSiblings[index];
            indices[i] = index;
        }
        return (addresses, indices);
    }

     /**
    * @dev See {IERC1155-safeTransferFrom}.
    * If transferable == false then no token can be transfered or sold
    */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        // Locks NFT from being transfered or sold
        require(chapters[id].transferable, "Transfers locked by contract");
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
    * @dev See {IERC1155-safeTransferFrom}.
    * If transferable == false then no token can be transfered or sold
    */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        // Locks NFT(s) from being transfered or sold
        for (uint256 i; i < ids.length; i++) {
            require(chapters[ids[i]].transferable, "Transfers locked by contract");
        }
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function burn(
        uint256[] calldata tokenIds, 
        address _account, 
        bool ovenHungee
    ) internal {
        uint256[] memory ids = new uint256[](tokenIds.length);
        for (uint256 j; j < tokenIds.length; j++) {
            ids[j] = tokenIds[j];
        }

        for (uint256 i; i < ids.length; i++) {
            require(
                _account == IERC721(burnContractERC721).ownerOf(tokenIds[i]), 
                "Must be token owner and tokens must be unique"
            );
            if (ovenHungee) {
                try IERC721(burnContractERC721).safeTransferFrom(_account, address(0xdEaD), tokenIds[i]) {
                } catch (bytes memory) {
                    revert("Burn failure, check if setApprovalForAll is true");
                }
            }
        }
    }

    function mint(
        address[] memory accounts, 
        uint256 amount, 
        uint256 _tokenId
    ) internal {
        for (uint256 i; i < accounts.length; i++) {
            _mint(accounts[i], _tokenId, amount, "");
            
            entries[accounts[i]][_tokenId] += amount;

            for (uint256 j; j < amount; j++) {
                chapters[_tokenId].starSiblings.push(accounts[i]);
            }
        }
    }
}