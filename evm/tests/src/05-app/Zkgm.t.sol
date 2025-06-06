pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import "solady/utils/LibBytes.sol";
import "solady/utils/LibString.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import
    "@openzeppelin-upgradeable/contracts/access/manager/AccessManagedUpgradeable.sol";

import "../../../contracts/core/Types.sol";
import "../../../contracts/core/25-handler/IBCHandler.sol";
import "../../../contracts/core/04-channel/IBCPacket.sol";
import "../../../contracts/core/05-port/IIBCModule.sol";
import "../../../contracts/apps/ucs/03-zkgm/IWETH.sol";
import "../../../contracts/apps/ucs/03-zkgm/Zkgm.sol";
import "../../../contracts/apps/Base.sol";

contract TestZkgm is UCS03Zkgm {
    constructor(
        IIBCModulePacket _ibcHandler,
        IWETH _weth,
        ZkgmERC20 _erc20Impl
    )
        UCS03Zkgm(
            _ibcHandler,
            new UCS03ZkgmSendImpl(
                _ibcHandler, _weth, _erc20Impl, "Ether", "ETH", 18
            ),
            new UCS03ZkgmStakeImpl(_ibcHandler),
            new UCS03ZkgmFungibleAssetOrderImpl(_weth, _erc20Impl, true)
        )
    {}

    function doExecuteForward(
        IBCPacket calldata ibcPacket,
        address relayer,
        bytes calldata relayerMsg,
        bytes32 salt,
        uint256 path,
        Forward calldata forward
    ) public returns (bytes memory) {
        return _executeForward(
            ibcPacket,
            relayer,
            relayerMsg,
            salt,
            path,
            ZkgmLib.INSTR_VERSION_0,
            forward,
            false
        );
    }

    function doExecuteMultiplex(
        address caller,
        IBCPacket calldata ibcPacket,
        address relayer,
        bytes calldata relayerMsg,
        uint256 path,
        bytes32 salt,
        Multiplex calldata multiplex
    ) public returns (bytes memory) {
        return _executeMultiplex(
            caller, ibcPacket, relayer, relayerMsg, path, salt, multiplex, false
        );
    }

    function doIncreaseOutstanding(
        uint32 sourceChannelId,
        uint256 path,
        address token,
        uint256 amount
    ) public {
        _increaseOutstanding(sourceChannelId, path, token, amount);
    }

    function doIncreaseOutstandingV2(
        uint32 sourceChannelId,
        uint256 path,
        address token,
        bytes32 metadataImage,
        uint256 amount
    ) public {
        _increaseOutstandingV2(
            sourceChannelId, path, token, metadataImage, amount
        );
    }

    function doDecreaseOutstanding(
        uint32 sourceChannelId,
        uint256 path,
        address token,
        uint256 amount
    ) public {
        _decreaseOutstanding(sourceChannelId, path, token, amount);
    }

    function doDecreaseOutstandingV2(
        uint32 sourceChannelId,
        uint256 path,
        address token,
        bytes32 metadataImage,
        uint256 amount
    ) public {
        _decreaseOutstandingV2(
            sourceChannelId, path, token, metadataImage, amount
        );
    }

    function doSetBucketConfig(
        address token,
        uint256 capacity,
        uint256 refillRate,
        bool reset
    ) public {
        _setBucketConfig(token, capacity, refillRate, reset);
    }
}

contract TestIBCHandler is IIBCModulePacket {
    event OnSendPacket(IBCPacket packet);

    using LibBytes for *;

    error ErrInvalidChannel();
    error ErrUnknownPacket();

    mapping(uint32 => uint32) public channels;
    mapping(bytes32 => bytes) public acks;

    function setChannel(uint32 src, uint32 dst) public {
        channels[src] = dst;
    }

    function sendPacket(
        uint32 sourceChannel,
        uint64 timeoutHeight,
        uint64 timeoutTimestamp,
        bytes calldata data
    ) external override returns (IBCPacket memory) {
        uint32 destinationChannelId = channels[sourceChannel];
        if (destinationChannelId == 0) {
            revert ErrInvalidChannel();
        }
        IBCPacket memory packet = IBCPacket({
            sourceChannelId: sourceChannel,
            destinationChannelId: destinationChannelId,
            data: data,
            timeoutHeight: timeoutHeight,
            timeoutTimestamp: timeoutTimestamp
        });
        acks[IBCPacketLib.commitPacket(packet)] = hex"01";
        emit OnSendPacket(packet);
        return packet;
    }

    function writeAcknowledgement(
        IBCPacket calldata packet,
        bytes memory acknowledgement
    ) external override {
        bytes32 commitmentKey = IBCPacketLib.commitPacket(packet);
        if (!acks[commitmentKey].eq(hex"01")) {
            revert ErrUnknownPacket();
        }
        acks[commitmentKey] = acknowledgement;
    }
}

contract TestERC20 is ERC20 {
    uint8 _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 d
    ) ERC20(name, symbol) {
        _decimals = d;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TestWETH is IWETH, TestERC20 {
    error ETHTransferFailed();

    constructor() TestERC20("Wrapped Ether", "WETH", 18) {}

    function deposit() public payable virtual {
        _mint(msg.sender, msg.value);
    }

    function withdraw(
        uint256 amount
    ) public virtual {
        _burn(msg.sender, amount);
        assembly {
            if iszero(
                call(
                    gas(), caller(), amount, codesize(), 0x00, codesize(), 0x00
                )
            ) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    receive() external payable virtual {
        deposit();
    }
}

contract TestMultiplexTarget is IZkgmable, IIBCModuleRecv {
    error ErrNotZkgm();

    event OnZkgm(
        uint256 path,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        bytes sender,
        bytes message
    );
    event OnIntentZkgm(
        uint256 path,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        bytes sender,
        bytes message
    );
    event OnRecvPacket(IBCPacket packet, address relayer, bytes relayerMsg);
    event OnRecvIntentPacket(
        IBCPacket packet, address relayer, bytes relayerMsg
    );

    address zkgm;

    constructor(
        address _zkgm
    ) {
        zkgm = _zkgm;
    }

    modifier onlyZkgm() {
        _checkZkgm();
        _;
    }

    function _checkZkgm() internal view {
        if (zkgm != msg.sender) {
            revert ErrNotZkgm();
        }
    }

    function onZkgm(
        address caller,
        uint256 path,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        bytes calldata sender,
        bytes calldata message,
        address relayer,
        bytes calldata relayerMsg
    ) public onlyZkgm {
        emit OnZkgm(
            path, sourceChannelId, destinationChannelId, sender, message
        );
    }

    function onIntentZkgm(
        address caller,
        uint256 path,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        bytes calldata sender,
        bytes calldata message,
        address relayer,
        bytes calldata relayerMsg
    ) public onlyZkgm {
        emit OnIntentZkgm(
            path, sourceChannelId, destinationChannelId, sender, message
        );
    }

    function onRecvPacket(
        address caller,
        IBCPacket calldata packet,
        address relayer,
        bytes calldata relayerMsg
    ) public onlyZkgm returns (bytes memory) {
        emit OnRecvPacket(packet, relayer, relayerMsg);
        return hex"01";
    }

    function onRecvIntentPacket(
        address caller,
        IBCPacket calldata packet,
        address relayer,
        bytes calldata relayerMsg
    ) public onlyZkgm returns (bytes memory) {
        emit OnRecvIntentPacket(packet, relayer, relayerMsg);
        return hex"01";
    }
}

contract ZkgmTests is Test {
    using LibString for *;

    TestMultiplexTarget multiplexTarget;
    TestIBCHandler handler;
    TestERC20 erc20;
    ZkgmERC20 erc20Impl;
    TestWETH weth;
    TestZkgm zkgm;

    Instruction dummyMultiplex = Instruction({
        version: ZkgmLib.INSTR_VERSION_0,
        opcode: ZkgmLib.OP_MULTIPLEX,
        operand: ZkgmLib.encodeMultiplex(
            Multiplex({
                sender: abi.encodePacked(address(0)),
                eureka: false,
                contractAddress: abi.encodePacked(address(0)),
                contractCalldata: hex""
            })
        )
    });

    function setUp() public {
        weth = new TestWETH();
        erc20 = new TestERC20("Test", "T", 18);
        handler = new TestIBCHandler();
        erc20Impl = new ZkgmERC20();
        TestZkgm implementation = new TestZkgm(handler, weth, erc20Impl);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(UCS03Zkgm.initialize, (address(this)))
        );
        zkgm = TestZkgm(payable(address(proxy)));
        multiplexTarget = new TestMultiplexTarget(address(zkgm));
    }

    receive() external payable {}

    function test_proxyInitialization_ok(
        address wethAddress,
        address handlerAddress,
        address erc20ImplAddress,
        address authorityAddress
    ) public {
        vm.assume(handlerAddress != address(0));
        vm.assume(authorityAddress != address(0));
        TestZkgm implementation = new TestZkgm(
            IIBCModulePacket(handlerAddress),
            IWETH(wethAddress),
            ZkgmERC20(erc20ImplAddress)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(UCS03Zkgm.initialize, (authorityAddress))
        );
        TestZkgm _zkgm = TestZkgm(payable(address(proxy)));
        assertEq(address(_zkgm.IBC_HANDLER()), handlerAddress);
        assertEq(_zkgm.authority(), authorityAddress);
    }

    function test_channelPath_ok(
        uint32 a,
        uint32 b,
        uint32 c,
        uint32 d,
        uint32 e,
        uint32 f,
        uint32 g,
        uint32 h
    ) public {
        // channel ids are non-zero
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(c > 0);
        vm.assume(d > 0);
        vm.assume(e > 0);
        vm.assume(f > 0);
        vm.assume(g > 0);
        vm.assume(h > 0);
        assertEq(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                ZkgmLib.updateChannelPath(
                                    ZkgmLib.updateChannelPath(
                                        ZkgmLib.updateChannelPath(0, a), b
                                    ),
                                    c
                                ),
                                d
                            ),
                            e
                        ),
                        f
                    ),
                    g
                ),
                h
            ),
            uint256(a) | uint256(b) << 32 | uint256(c) << 64 | uint256(d) << 96
                | uint256(e) << 128 | uint256(f) << 160 | uint256(g) << 192
                | uint256(h) << 224
        );
    }

    function test_reverseChannelPath_2_ok(uint32 a, uint32 b) public {
        // channel ids are non-zero
        vm.assume(a > 0);
        vm.assume(b > 0);
        uint256 channelPath =
            ZkgmLib.updateChannelPath(ZkgmLib.updateChannelPath(0, a), b);
        assertEq(
            ZkgmLib.reverseChannelPath(channelPath),
            uint256(b) | uint256(a) << 32
        );
    }

    function test_reverseChannelPath_ok(
        uint32 a,
        uint32 b,
        uint32 c,
        uint32 d,
        uint32 e,
        uint32 f,
        uint32 g,
        uint32 h
    ) public {
        // channel ids are non-zero
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(c > 0);
        vm.assume(d > 0);
        vm.assume(e > 0);
        vm.assume(f > 0);
        vm.assume(g > 0);
        vm.assume(h > 0);
        uint256 channelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                ZkgmLib.updateChannelPath(
                                    ZkgmLib.updateChannelPath(0, a), b
                                ),
                                c
                            ),
                            d
                        ),
                        e
                    ),
                    f
                ),
                g
            ),
            h
        );
        assertEq(
            ZkgmLib.reverseChannelPath(channelPath),
            uint256(h) | uint256(g) << 32 | uint256(f) << 64 | uint256(e) << 96
                | uint256(d) << 128 | uint256(c) << 160 | uint256(b) << 192
                | uint256(a) << 224
        );
    }

    function test_popChannelFromPath_ok(
        uint32 a,
        uint32 b,
        uint32 c,
        uint32 d,
        uint32 e,
        uint32 f,
        uint32 g,
        uint32 h
    ) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(c > 0);
        vm.assume(d > 0);
        vm.assume(e > 0);
        vm.assume(f > 0);
        vm.assume(g > 0);
        vm.assume(h > 0);
        uint256 channelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                ZkgmLib.updateChannelPath(
                                    ZkgmLib.updateChannelPath(0, a), b
                                ),
                                c
                            ),
                            d
                        ),
                        e
                    ),
                    f
                ),
                g
            ),
            h
        );
        uint256 expectedBaseChannelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                ZkgmLib.updateChannelPath(0, a), b
                            ),
                            c
                        ),
                        d
                    ),
                    e
                ),
                f
            ),
            g
        );
        (uint256 baseChannelPath, uint32 finalChannelId) =
            ZkgmLib.popChannelFromPath(channelPath);
        assertEq(baseChannelPath, expectedBaseChannelPath);
        assertEq(finalChannelId, h);
    }

    function test_popChannelFromPath_ok_2(
        uint32 a,
        uint32 b,
        uint32 c,
        uint32 d,
        uint32 e,
        uint32 f,
        uint32 g,
        uint32 h
    ) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(c > 0);
        vm.assume(d > 0);
        vm.assume(e > 0);
        vm.assume(f > 0);
        vm.assume(g > 0);
        vm.assume(h > 0);
        uint256 expectedBaseChannelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(0, a), b
                        ),
                        c
                    ),
                    d
                ),
                e
            ),
            f
        );
        uint256 channelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(expectedBaseChannelPath, g), h
        );
        (uint256 baseChannelPath, uint32 finalChannelId) =
            ZkgmLib.popChannelFromPath(channelPath);
        (uint256 baseChannelPath2, uint32 finalChannelId2) =
            ZkgmLib.popChannelFromPath(baseChannelPath);
        assertEq(bytes32(baseChannelPath2), bytes32(expectedBaseChannelPath));
        assertEq(finalChannelId, h);
        assertEq(finalChannelId2, g);
    }

    function test_dequeueChannelFromPath_ok(
        uint32 a,
        uint32 b,
        uint32 c,
        uint32 d,
        uint32 e,
        uint32 f,
        uint32 g,
        uint32 h
    ) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(c > 0);
        vm.assume(d > 0);
        vm.assume(e > 0);
        vm.assume(f > 0);
        vm.assume(g > 0);
        vm.assume(h > 0);
        uint256 channelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                ZkgmLib.updateChannelPath(
                                    ZkgmLib.updateChannelPath(0, a), b
                                ),
                                c
                            ),
                            d
                        ),
                        e
                    ),
                    f
                ),
                g
            ),
            h
        );
        uint256 expectedBaseChannelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                ZkgmLib.updateChannelPath(0, b), c
                            ),
                            d
                        ),
                        e
                    ),
                    f
                ),
                g
            ),
            h
        );
        (uint256 tailChannelPath, uint32 firstChannelId) =
            ZkgmLib.dequeueChannelFromPath(channelPath);
        assertEq(tailChannelPath, expectedBaseChannelPath);
        assertEq(firstChannelId, a);
    }

    function test_dequeueChannelFromPath_ok_2(
        uint32 a,
        uint32 b,
        uint32 c,
        uint32 d,
        uint32 e,
        uint32 f,
        uint32 g,
        uint32 h
    ) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(c > 0);
        vm.assume(d > 0);
        vm.assume(e > 0);
        vm.assume(f > 0);
        vm.assume(g > 0);
        vm.assume(h > 0);
        uint256 channelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                ZkgmLib.updateChannelPath(
                                    ZkgmLib.updateChannelPath(0, a), b
                                ),
                                c
                            ),
                            d
                        ),
                        e
                    ),
                    f
                ),
                g
            ),
            h
        );
        uint256 expectedBaseChannelPath = ZkgmLib.updateChannelPath(
            ZkgmLib.updateChannelPath(
                ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(0, c), d
                        ),
                        e
                    ),
                    f
                ),
                g
            ),
            h
        );
        (uint256 tailChannelPath, uint32 firstChannelId) =
            ZkgmLib.dequeueChannelFromPath(channelPath);
        (uint256 tailChannelPath2, uint32 secondChannelId) =
            ZkgmLib.dequeueChannelFromPath(tailChannelPath);
        assertEq(tailChannelPath2, expectedBaseChannelPath);
        assertEq(firstChannelId, a);
        assertEq(secondChannelId, b);
    }

    function test_onChanOpenInit_onlyIBC(
        address caller,
        uint32 connectionId,
        uint32 channelId,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.expectRevert(IBCAppLib.ErrNotIBC.selector);
        zkgm.onChanOpenInit(
            caller, connectionId, channelId, ZkgmLib.IBC_VERSION_STR, relayer
        );
    }

    function test_tintForwardSalt_ok(
        bytes32 salt
    ) public {
        salt = bytes32(salt >> 8);
        assertFalse(ZkgmLib.isForwardedPacket(salt));
        assertTrue(ZkgmLib.isForwardedPacket(ZkgmLib.tintForwardSalt(salt)));
    }

    function test_tintForwardSalt_ok_2() public {
        test_tintForwardSalt_ok(
            0xdefe464db3fcf737aba09147ad0258e1f0913e3633c065053e744057b42dfefe
        );
    }

    function test_onChanOpenInit_ok(
        address caller,
        uint32 connectionId,
        uint32 channelId,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.prank(address(handler));
        zkgm.onChanOpenInit(
            caller, connectionId, channelId, ZkgmLib.IBC_VERSION_STR, relayer
        );
    }

    function test_onChanOpenInit_invalidVersion(
        address caller,
        uint32 connectionId,
        uint32 channelId,
        address relayer,
        string memory version
    ) public {
        vm.assume(channelId != 0);
        vm.prank(address(handler));
        vm.expectRevert(ZkgmLib.ErrInvalidIBCVersion.selector);
        zkgm.onChanOpenInit(caller, connectionId, channelId, version, relayer);
    }

    function test_onChanOpenTry_onlyIBC(
        address caller,
        uint32 connectionId,
        uint32 channelId,
        uint32 counterpartyChannelId,
        address relayer
    ) public {
        vm.assume(channelId > 0);
        vm.expectRevert(IBCAppLib.ErrNotIBC.selector);
        zkgm.onChanOpenTry(
            caller,
            connectionId,
            channelId,
            counterpartyChannelId,
            ZkgmLib.IBC_VERSION_STR,
            ZkgmLib.IBC_VERSION_STR,
            relayer
        );
    }

    function test_onChanOpenTry_ok(
        address caller,
        uint32 connectionId,
        uint32 channelId,
        uint32 counterpartyChannelId,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.prank(address(handler));
        zkgm.onChanOpenTry(
            caller,
            connectionId,
            channelId,
            counterpartyChannelId,
            ZkgmLib.IBC_VERSION_STR,
            ZkgmLib.IBC_VERSION_STR,
            relayer
        );
    }

    function test_onChanOpenTry_invalidVersion(
        address caller,
        uint32 connectionId,
        uint32 channelId,
        uint32 counterpartyChannelId,
        string memory version,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.prank(address(handler));
        vm.expectRevert(ZkgmLib.ErrInvalidIBCVersion.selector);
        zkgm.onChanOpenTry(
            caller,
            connectionId,
            channelId,
            counterpartyChannelId,
            version,
            ZkgmLib.IBC_VERSION_STR,
            relayer
        );
    }

    function test_onChanOpenTry_invalidCounterpartyVersion(
        address caller,
        uint32 connectionId,
        uint32 channelId,
        uint32 counterpartyChannelId,
        string memory counterpartyVersion,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.prank(address(handler));
        vm.expectRevert(ZkgmLib.ErrInvalidIBCVersion.selector);
        zkgm.onChanOpenTry(
            caller,
            connectionId,
            channelId,
            counterpartyChannelId,
            ZkgmLib.IBC_VERSION_STR,
            counterpartyVersion,
            relayer
        );
    }

    function test_onChanCloseInit_onlyIBC(
        address caller,
        uint32 channelId,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.expectRevert(IBCAppLib.ErrNotIBC.selector);
        zkgm.onChanCloseInit(caller, channelId, relayer);
    }

    function test_onChanCloseInit_impossible(
        address caller,
        uint32 channelId,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.prank(address(handler));
        vm.expectRevert(ZkgmLib.ErrInfiniteGame.selector);
        zkgm.onChanCloseInit(caller, channelId, relayer);
    }

    function test_onChanCloseConfirm_onlyIBC(
        address caller,
        uint32 channelId,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.expectRevert(IBCAppLib.ErrNotIBC.selector);
        zkgm.onChanCloseConfirm(caller, channelId, relayer);
    }

    function test_onChanCloseConfirm_impossible(
        address caller,
        uint32 channelId,
        address relayer
    ) public {
        vm.assume(channelId != 0);
        vm.prank(address(handler));
        vm.expectRevert(ZkgmLib.ErrInfiniteGame.selector);
        zkgm.onChanCloseConfirm(caller, channelId, relayer);
    }

    function test_onRecvPacket_onlyIBC(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes calldata relayerMsg
    ) public {
        vm.assume(sourceChannelId != 0);
        vm.assume(destinationChannelId != 0);
        vm.expectRevert(IBCAppLib.ErrNotIBC.selector);
        zkgm.onRecvPacket(
            caller,
            IBCPacket({
                sourceChannelId: sourceChannelId,
                destinationChannelId: destinationChannelId,
                data: hex"",
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg
        );
    }

    function test_execute_onlySelf(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes calldata relayerMsg,
        bool intent
    ) public {
        vm.assume(sourceChannelId != 0);
        vm.assume(destinationChannelId != 0);
        vm.expectRevert(ZkgmLib.ErrUnauthorized.selector);
        zkgm.execute(
            caller,
            IBCPacket({
                sourceChannelId: sourceChannelId,
                destinationChannelId: destinationChannelId,
                data: hex"",
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            intent
        );
    }

    function test_verify_forward_ok() public {
        handler.setChannel(1, 10);
        zkgm.send(
            1,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_0,
                opcode: ZkgmLib.OP_FORWARD,
                operand: ZkgmLib.encodeForward(
                    Forward({
                        path: ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(0, 10), 1
                        ),
                        timeoutHeight: type(uint64).max,
                        timeoutTimestamp: 0,
                        instruction: Instruction({
                            version: ZkgmLib.INSTR_VERSION_0,
                            opcode: ZkgmLib.OP_MULTIPLEX,
                            operand: ZkgmLib.encodeMultiplex(
                                Multiplex({
                                    sender: abi.encodePacked(this),
                                    eureka: false,
                                    contractAddress: abi.encodePacked(this),
                                    contractCalldata: hex""
                                })
                            )
                        })
                    })
                )
            })
        );
    }

    function test_verify_forward_invalidInstruction(
        uint32 channelId
    ) public {
        vm.expectRevert(ZkgmLib.ErrInvalidForwardInstruction.selector);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_0,
                opcode: ZkgmLib.OP_FORWARD,
                operand: ZkgmLib.encodeForward(
                    Forward({
                        path: ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(0, 10), 1
                        ),
                        timeoutHeight: type(uint64).max,
                        timeoutTimestamp: 0,
                        instruction: Instruction({
                            version: ZkgmLib.INSTR_VERSION_0,
                            opcode: ZkgmLib.OP_FORWARD,
                            operand: hex""
                        })
                    })
                )
            })
        );
    }

    function test_verify_multiplex_ok(
        uint32 channelId,
        uint32 counterpartyChannelId,
        bytes memory contractAddress,
        bytes memory contractCalldata
    ) public {
        vm.assume(channelId > 0);
        vm.assume(counterpartyChannelId > 0);
        handler.setChannel(channelId, counterpartyChannelId);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_0,
                opcode: ZkgmLib.OP_MULTIPLEX,
                operand: ZkgmLib.encodeMultiplex(
                    Multiplex({
                        sender: abi.encodePacked(address(this)),
                        eureka: false,
                        contractAddress: contractAddress,
                        contractCalldata: contractCalldata
                    })
                )
            })
        );
    }

    function test_verify_multiplex_invalidSender(
        uint32 channelId,
        address sender,
        bytes memory contractAddress,
        bytes memory contractCalldata
    ) public {
        vm.assume(sender != address(this));
        vm.expectRevert(ZkgmLib.ErrInvalidMultiplexSender.selector);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_0,
                opcode: ZkgmLib.OP_MULTIPLEX,
                operand: ZkgmLib.encodeMultiplex(
                    Multiplex({
                        sender: abi.encodePacked(sender),
                        eureka: false,
                        contractAddress: contractAddress,
                        contractCalldata: contractCalldata
                    })
                )
            })
        );
    }

    function test_verify_batch_ok(
        uint32 channelId,
        uint32 counterpartyChannelId,
        bytes memory contractAddress,
        bytes memory contractCalldata
    ) public {
        vm.assume(channelId > 0);
        vm.assume(counterpartyChannelId > 0);
        Instruction[] memory instructions = new Instruction[](1);
        instructions[0] = Instruction({
            version: ZkgmLib.INSTR_VERSION_0,
            opcode: ZkgmLib.OP_MULTIPLEX,
            operand: ZkgmLib.encodeMultiplex(
                Multiplex({
                    sender: abi.encodePacked(address(this)),
                    eureka: false,
                    contractAddress: contractAddress,
                    contractCalldata: contractCalldata
                })
            )
        });
        handler.setChannel(channelId, counterpartyChannelId);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_0,
                opcode: ZkgmLib.OP_BATCH,
                operand: ZkgmLib.encodeBatch(Batch({instructions: instructions}))
            })
        );
    }

    function test_verify_batch_invalidInstruction(
        uint32 channelId
    ) public {
        Instruction[] memory instructions = new Instruction[](1);
        instructions[0] = Instruction({
            version: ZkgmLib.INSTR_VERSION_0,
            opcode: ZkgmLib.OP_BATCH,
            operand: hex""
        });
        vm.expectRevert(ZkgmLib.ErrInvalidBatchInstruction.selector);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_0,
                opcode: ZkgmLib.OP_BATCH,
                operand: ZkgmLib.encodeBatch(Batch({instructions: instructions}))
            })
        );
    }

    function test_verify_order_transfer_wrapped_burn_ok(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        bytes32 salt,
        bytes memory sender,
        address receiver,
        bytes memory baseToken,
        TokenMeta memory baseTokenMeta,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(receiver != address(0));
            vm.assume(quoteAmount <= baseAmount);
        }
        handler.setChannel(destinationChannelId, sourceChannelId);
        address quoteToken = test_onRecvPacket_transferNative_newWrapped(
            caller,
            sourceChannelId,
            destinationChannelId,
            relayer,
            relayerMsg,
            0,
            salt,
            sender,
            receiver,
            baseToken,
            baseTokenMeta,
            baseAmount
        );
        vm.expectEmit();
        emit IERC20.Transfer(receiver, address(0), quoteAmount);
        vm.prank(receiver);
        zkgm.send(
            destinationChannelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_1,
                opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                operand: ZkgmLib.encodeFungibleAssetOrder(
                    FungibleAssetOrder({
                        sender: abi.encodePacked(receiver),
                        receiver: sender,
                        baseToken: abi.encodePacked(quoteToken),
                        baseTokenPath: ZkgmLib.updateChannelPath(
                            0, destinationChannelId
                        ),
                        baseTokenSymbol: baseTokenMeta.symbol,
                        baseTokenName: baseTokenMeta.name,
                        baseTokenDecimals: baseTokenMeta.decimals,
                        baseAmount: quoteAmount,
                        quoteToken: abi.encodePacked(baseToken),
                        quoteAmount: baseAmount
                    })
                )
            })
        );
    }

    function _metadataImage(
        TokenMeta memory baseTokenMeta
    ) internal returns (bytes32) {
        FungibleAssetMetadata memory metadata = FungibleAssetMetadata({
            implementation: abi.encodePacked(erc20Impl),
            initializer: abi.encodeCall(
                ZkgmERC20.initialize,
                (
                    zkgm.authority(),
                    address(zkgm),
                    baseTokenMeta.name,
                    baseTokenMeta.symbol,
                    baseTokenMeta.decimals
                )
            )
        });
        return
            EfficientHashLib.hash(ZkgmLib.encodeFungibleAssetMetadata(metadata));
    }

    function test_verify_order_v2_transfer_wrapped_burn_ok(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        bytes32 salt,
        bytes memory sender,
        address receiver,
        bytes memory baseToken,
        TokenMeta memory baseTokenMeta,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(receiver != address(0));
            vm.assume(0 < quoteAmount && quoteAmount <= baseAmount);
        }
        handler.setChannel(destinationChannelId, sourceChannelId);
        address quoteToken = test_onRecvPacket_transferNative_newWrapped_v2(
            caller,
            sourceChannelId,
            destinationChannelId,
            relayer,
            relayerMsg,
            0,
            salt,
            sender,
            receiver,
            baseToken,
            baseTokenMeta,
            baseAmount
        );
        vm.expectEmit();
        emit IERC20.Transfer(receiver, address(0), quoteAmount);
        bytes32 metadataImage = _metadataImage(baseTokenMeta);
        vm.prank(receiver);
        zkgm.send(
            destinationChannelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_2,
                opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                operand: ZkgmLib.encodeFungibleAssetOrderV2(
                    FungibleAssetOrderV2({
                        sender: abi.encodePacked(receiver),
                        receiver: sender,
                        baseToken: abi.encodePacked(quoteToken),
                        metadataType: ZkgmLib.FUNGIBLE_ASSET_METADATA_TYPE_IMAGE_UNWRAP,
                        metadata: abi.encodePacked(metadataImage),
                        baseAmount: quoteAmount,
                        quoteToken: abi.encodePacked(baseToken),
                        quoteAmount: quoteAmount
                    })
                )
            })
        );
    }

    function test_verify_order_transfer_native_escrow_increaseOutstanding_ok(
        uint32 channelId,
        uint32 counterpartyChannelId,
        address caller,
        bytes memory sender,
        bytes memory receiver,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount
    ) public {
        vm.assume(channelId > 0);
        vm.assume(counterpartyChannelId > 0);
        vm.assume(caller != address(0));
        handler.setChannel(channelId, counterpartyChannelId);
        address baseToken = address(erc20);
        if (baseAmount > 0) {
            erc20.mint(caller, baseAmount);
            vm.prank(caller);
            erc20.approve(address(zkgm), baseAmount);
        }
        string memory symbol = erc20.symbol();
        string memory name = erc20.name();
        uint8 decimals = erc20.decimals();
        vm.expectEmit();
        emit IERC20.Transfer(caller, address(zkgm), baseAmount);
        assertEq(zkgm.channelBalance(channelId, 0, baseToken), 0);
        vm.prank(caller);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_1,
                opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                operand: ZkgmLib.encodeFungibleAssetOrder(
                    FungibleAssetOrder({
                        sender: sender,
                        receiver: receiver,
                        baseToken: abi.encodePacked(baseToken),
                        baseTokenPath: 0,
                        baseTokenSymbol: symbol,
                        baseTokenName: name,
                        baseTokenDecimals: decimals,
                        baseAmount: baseAmount,
                        quoteToken: abi.encodePacked(quoteToken),
                        quoteAmount: baseAmount
                    })
                )
            })
        );
        assertEq(zkgm.channelBalance(channelId, 0, baseToken), baseAmount);
    }

    function test_verify_order_transfer_native_noAllowance(
        uint32 channelId,
        address caller,
        bytes memory sender,
        bytes memory receiver,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(baseAmount > 0);
            vm.assume(caller != address(0));
        }
        address baseToken = address(erc20);
        string memory symbol = erc20.symbol();
        string memory name = erc20.name();
        uint8 decimals = erc20.decimals();
        vm.expectRevert();
        vm.prank(caller);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_1,
                opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                operand: ZkgmLib.encodeFungibleAssetOrder(
                    FungibleAssetOrder({
                        sender: sender,
                        receiver: receiver,
                        baseToken: abi.encodePacked(baseToken),
                        baseTokenPath: 0,
                        baseTokenSymbol: symbol,
                        baseTokenName: name,
                        baseTokenDecimals: decimals,
                        baseAmount: baseAmount,
                        quoteToken: abi.encodePacked(quoteToken),
                        quoteAmount: baseAmount
                    })
                )
            })
        );
    }

    function test_verify_order_transfer_invalidSymbol(
        uint32 channelId,
        address caller,
        bytes memory sender,
        bytes memory receiver,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount,
        string memory symbol
    ) public {
        {
            vm.assume(!symbol.eq(erc20.symbol()));
            vm.assume(caller != address(0));
        }
        address baseToken = address(erc20);
        if (baseAmount > 0) {
            erc20.mint(caller, baseAmount);
            vm.prank(caller);
            erc20.approve(address(zkgm), baseAmount);
        }
        string memory name = erc20.name();
        uint8 decimals = erc20.decimals();
        vm.expectRevert(ZkgmLib.ErrInvalidAssetSymbol.selector);
        vm.prank(caller);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_1,
                opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                operand: ZkgmLib.encodeFungibleAssetOrder(
                    FungibleAssetOrder({
                        sender: sender,
                        receiver: receiver,
                        baseToken: abi.encodePacked(baseToken),
                        baseTokenPath: 0,
                        baseTokenSymbol: symbol,
                        baseTokenName: name,
                        baseTokenDecimals: decimals,
                        baseAmount: baseAmount,
                        quoteToken: abi.encodePacked(quoteToken),
                        quoteAmount: baseAmount
                    })
                )
            })
        );
    }

    function test_verify_order_transfer_invalidName(
        uint32 channelId,
        address caller,
        bytes memory sender,
        bytes memory receiver,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount,
        string memory name
    ) public {
        {
            vm.assume(!name.eq(erc20.name()));
            vm.assume(caller != address(0));
        }
        address baseToken = address(erc20);
        if (baseAmount > 0) {
            erc20.mint(caller, baseAmount);
            vm.prank(caller);
            erc20.approve(address(zkgm), baseAmount);
        }
        string memory symbol = erc20.symbol();
        uint8 decimals = erc20.decimals();
        vm.expectRevert(ZkgmLib.ErrInvalidAssetName.selector);
        vm.prank(caller);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_1,
                opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                operand: ZkgmLib.encodeFungibleAssetOrder(
                    FungibleAssetOrder({
                        sender: sender,
                        receiver: receiver,
                        baseToken: abi.encodePacked(baseToken),
                        baseTokenPath: 0,
                        baseTokenSymbol: symbol,
                        baseTokenName: name,
                        baseTokenDecimals: decimals,
                        baseAmount: baseAmount,
                        quoteToken: abi.encodePacked(quoteToken),
                        quoteAmount: baseAmount
                    })
                )
            })
        );
    }

    function test_verify_order_transfer_invalidDecimals(
        uint32 channelId,
        address caller,
        bytes memory sender,
        bytes memory receiver,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount,
        uint8 decimals
    ) public {
        {
            vm.assume(decimals != erc20.decimals());
            vm.assume(caller != address(0));
        }
        address baseToken = address(erc20);
        if (baseAmount > 0) {
            erc20.mint(caller, baseAmount);
            vm.prank(caller);
            erc20.approve(address(zkgm), baseAmount);
        }
        string memory symbol = erc20.symbol();
        string memory name = erc20.name();
        vm.expectRevert(ZkgmLib.ErrInvalidAssetDecimals.selector);
        vm.prank(caller);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_1,
                opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                operand: ZkgmLib.encodeFungibleAssetOrder(
                    FungibleAssetOrder({
                        sender: sender,
                        receiver: receiver,
                        baseToken: abi.encodePacked(baseToken),
                        baseTokenPath: 0,
                        baseTokenSymbol: symbol,
                        baseTokenName: name,
                        baseTokenDecimals: decimals,
                        baseAmount: baseAmount,
                        quoteToken: abi.encodePacked(quoteToken),
                        quoteAmount: baseAmount
                    })
                )
            })
        );
    }

    function test_verify_order_transfer_native_invalidOrigin(
        uint32 channelId,
        address caller,
        bytes memory sender,
        bytes memory receiver,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount,
        uint256 baseTokenPath
    ) public {
        {
            vm.assume(baseTokenPath != 0);
            vm.assume(caller != address(0));
        }
        address baseToken = address(erc20);
        if (baseAmount > 0) {
            erc20.mint(caller, baseAmount);
            vm.prank(caller);
            erc20.approve(address(zkgm), baseAmount);
        }
        string memory symbol = erc20.symbol();
        string memory name = erc20.name();
        uint8 decimals = erc20.decimals();
        vm.expectRevert(ZkgmLib.ErrInvalidAssetOrigin.selector);
        vm.prank(caller);
        zkgm.send(
            channelId,
            0,
            type(uint64).max,
            bytes32(0),
            Instruction({
                version: ZkgmLib.INSTR_VERSION_1,
                opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                operand: ZkgmLib.encodeFungibleAssetOrder(
                    FungibleAssetOrder({
                        sender: sender,
                        receiver: receiver,
                        baseToken: abi.encodePacked(baseToken),
                        baseTokenPath: baseTokenPath,
                        baseTokenSymbol: symbol,
                        baseTokenName: name,
                        baseTokenDecimals: decimals,
                        baseAmount: baseAmount,
                        quoteToken: abi.encodePacked(quoteToken),
                        quoteAmount: baseAmount
                    })
                )
            })
        );
    }

    function test_executeForward_ok(
        uint32 previousSourceChannelId,
        uint32 previousDestinationChannelId,
        uint32 nextSourceChannelId,
        uint32 nextDestinationChannelId,
        bytes32 salt,
        uint128 path,
        address relayer,
        bytes memory relayerMsg
    ) public {
        {
            vm.assume(previousSourceChannelId != 0);
            vm.assume(previousDestinationChannelId != 0);
            vm.assume(nextSourceChannelId != 0);
            vm.assume(nextDestinationChannelId != 0);
        }
        handler.setChannel(nextSourceChannelId, nextDestinationChannelId);
        // We expect the protocol to re-emit a packet with the updated path and the sub-instruction
        vm.expectEmit();
        emit TestIBCHandler.OnSendPacket(
            IBCPacket({
                sourceChannelId: nextSourceChannelId,
                destinationChannelId: nextDestinationChannelId,
                data: ZkgmLib.encode(
                    ZkgmPacket({
                        salt: ZkgmLib.deriveForwardSalt(salt),
                        path: ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                path, previousDestinationChannelId
                            ),
                            nextSourceChannelId
                        ),
                        instruction: dummyMultiplex
                    })
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            })
        );
        bytes memory ack = zkgm.doExecuteForward(
            IBCPacket({
                sourceChannelId: previousSourceChannelId,
                destinationChannelId: previousDestinationChannelId,
                data: hex"",
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            salt,
            uint256(path),
            Forward({
                path: ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(0, previousDestinationChannelId),
                    nextSourceChannelId
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0,
                instruction: dummyMultiplex
            })
        );
        assertEq(ZkgmLib.ACK_EMPTY, ack);
    }

    function test_executeForward_double_ok(
        uint32 previousSourceChannelId,
        uint32 previousDestinationChannelId,
        uint32 nextSourceChannelId,
        uint32 nextDestinationChannelId,
        uint32 previousDestinationChannelId2,
        uint32 nextSourceChannelId2,
        bytes32 salt,
        uint128 path,
        address relayer,
        bytes memory relayerMsg
    ) public {
        {
            vm.assume(previousSourceChannelId != 0);
            vm.assume(previousDestinationChannelId != 0);
            vm.assume(nextSourceChannelId != 0);
            vm.assume(nextDestinationChannelId != 0);
            vm.assume(previousDestinationChannelId2 != 0);
            vm.assume(nextSourceChannelId2 != 0);
        }
        handler.setChannel(nextSourceChannelId, nextDestinationChannelId);
        // We expect the protocol to re-emit a forward
        vm.expectEmit();
        emit TestIBCHandler.OnSendPacket(
            IBCPacket({
                sourceChannelId: nextSourceChannelId,
                destinationChannelId: nextDestinationChannelId,
                data: ZkgmLib.encode(
                    ZkgmPacket({
                        salt: ZkgmLib.deriveForwardSalt(salt),
                        path: ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                path, previousDestinationChannelId
                            ),
                            nextSourceChannelId
                        ),
                        instruction: Instruction({
                            version: ZkgmLib.INSTR_VERSION_0,
                            opcode: ZkgmLib.OP_FORWARD,
                            operand: ZkgmLib.encodeForward(
                                Forward({
                                    path: ZkgmLib.updateChannelPath(
                                        ZkgmLib.updateChannelPath(
                                            0, previousDestinationChannelId2
                                        ),
                                        nextSourceChannelId2
                                    ),
                                    timeoutHeight: type(uint64).max,
                                    timeoutTimestamp: 0,
                                    instruction: dummyMultiplex
                                })
                            )
                        })
                    })
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            })
        );
        bytes memory ack = zkgm.doExecuteForward(
            IBCPacket({
                sourceChannelId: previousSourceChannelId,
                destinationChannelId: previousDestinationChannelId,
                data: hex"",
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            salt,
            uint256(path),
            Forward({
                path: ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(
                        ZkgmLib.updateChannelPath(
                            ZkgmLib.updateChannelPath(
                                0, previousDestinationChannelId
                            ),
                            nextSourceChannelId
                        ),
                        previousDestinationChannelId2
                    ),
                    nextSourceChannelId2
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0,
                instruction: dummyMultiplex
            })
        );
        assertEq(ZkgmLib.ACK_EMPTY, ack);
    }

    function test_executeForward_invalidPrecomputedChannel(
        uint32 previousSourceChannelId,
        uint32 previousDestinationChannelId,
        uint32 fakeDestinationChannelId,
        uint32 nextSourceChannelId,
        uint32 nextDestinationChannelId,
        bytes32 salt,
        uint128 path,
        address relayer,
        bytes memory relayerMsg
    ) public {
        {
            vm.assume(previousSourceChannelId != 0);
            vm.assume(previousDestinationChannelId != 0);
            vm.assume(fakeDestinationChannelId != 0);
            vm.assume(fakeDestinationChannelId != previousDestinationChannelId);
            vm.assume(nextSourceChannelId != 0);
            vm.assume(nextDestinationChannelId != 0);
        }
        handler.setChannel(nextSourceChannelId, nextDestinationChannelId);
        vm.expectRevert(ZkgmLib.ErrInvalidForwardDestinationChannelId.selector);
        zkgm.doExecuteForward(
            IBCPacket({
                sourceChannelId: previousSourceChannelId,
                destinationChannelId: previousDestinationChannelId,
                data: hex"",
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            salt,
            uint256(path),
            Forward({
                path: ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(0, fakeDestinationChannelId),
                    nextSourceChannelId
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0,
                instruction: dummyMultiplex
            })
        );
    }

    function test_executeForward_invalidNextSourceChannelId(
        uint32 previousSourceChannelId,
        uint32 previousDestinationChannelId,
        uint32 nextSourceChannelId,
        uint32 wrongNextSourceChannelId,
        uint32 nextDestinationChannelId,
        bytes32 salt,
        uint128 path,
        address relayer,
        bytes memory relayerMsg
    ) public {
        {
            vm.assume(previousSourceChannelId != 0);
            vm.assume(previousDestinationChannelId != 0);
            vm.assume(nextSourceChannelId != 0);
            vm.assume(wrongNextSourceChannelId != 0);
            vm.assume(wrongNextSourceChannelId != nextSourceChannelId);
            vm.assume(nextDestinationChannelId != 0);
        }
        handler.setChannel(nextSourceChannelId, nextDestinationChannelId);
        vm.expectRevert(TestIBCHandler.ErrInvalidChannel.selector);
        zkgm.doExecuteForward(
            IBCPacket({
                sourceChannelId: previousSourceChannelId,
                destinationChannelId: previousDestinationChannelId,
                data: hex"",
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            salt,
            uint256(path),
            Forward({
                path: ZkgmLib.updateChannelPath(
                    ZkgmLib.updateChannelPath(0, previousDestinationChannelId),
                    wrongNextSourceChannelId
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0,
                instruction: dummyMultiplex
            })
        );
    }

    function test_multiplex_eureka_ok(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint256 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory contractCalldata
    ) public {
        {
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        vm.expectEmit();
        emit TestMultiplexTarget.OnZkgm(
            path,
            sourceChannelId,
            destinationChannelId,
            sender,
            contractCalldata
        );
        bytes memory ack = zkgm.doExecuteMultiplex(
            caller,
            IBCPacket({
                sourceChannelId: sourceChannelId,
                destinationChannelId: destinationChannelId,
                data: hex"",
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            path,
            salt,
            Multiplex({
                sender: sender,
                eureka: false,
                contractAddress: abi.encodePacked(address(multiplexTarget)),
                contractCalldata: contractCalldata
            })
        );
        assertEq(ack, abi.encode(ZkgmLib.ACK_SUCCESS));
    }

    function test_multiplex_ok(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint256 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory contractCalldata
    ) public {
        {
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        vm.expectEmit();
        emit TestMultiplexTarget.OnRecvPacket(
            IBCPacket({
                sourceChannelId: sourceChannelId,
                destinationChannelId: destinationChannelId,
                data: ZkgmLib.encodeMultiplexCalldataMemory(
                    path, sender, contractCalldata
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg
        );
        bytes memory ack = zkgm.doExecuteMultiplex(
            caller,
            IBCPacket({
                sourceChannelId: sourceChannelId,
                destinationChannelId: destinationChannelId,
                data: hex"",
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            path,
            salt,
            Multiplex({
                sender: sender,
                eureka: true,
                contractAddress: abi.encodePacked(address(multiplexTarget)),
                contractCalldata: contractCalldata
            })
        );
        assertEq(ack, hex"01");
    }

    function expectAckFailure(
        address caller,
        IBCPacket memory packet,
        address relayer,
        bytes memory relayerMsg,
        bool onlyMaker,
        bool intent
    ) internal {
        if (onlyMaker) {
            vm.expectRevert(ZkgmLib.ErrOnlyMaker.selector);
        }
        bytes memory ack;
        if (intent) {
            ack = zkgm.onRecvIntentPacket(caller, packet, relayer, relayerMsg);
        } else {
            ack = zkgm.onRecvPacket(caller, packet, relayer, relayerMsg);
        }
        if (!onlyMaker) {
            assertEq(
                ack,
                ZkgmLib.encodeAck(
                    Ack({tag: ZkgmLib.ACK_FAILURE, innerAck: ZkgmLib.ACK_EMPTY})
                )
            );
        }
    }

    function expectAckSuccess(
        address caller,
        IBCPacket memory packet,
        address relayer,
        bytes memory relayerMsg,
        bytes memory expectedAck,
        bool intent
    ) internal {
        vm.prank(address(handler));
        bytes memory ack;
        if (intent) {
            ack = zkgm.onRecvIntentPacket(caller, packet, relayer, relayerMsg);
        } else {
            ack = zkgm.onRecvPacket(caller, packet, relayer, relayerMsg);
        }
        assertEq(
            ack,
            ZkgmLib.encodeAck(
                Ack({tag: ZkgmLib.ACK_SUCCESS, innerAck: expectedAck})
            )
        );
    }

    function test_multiplex_eureka_invalidContract(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        bytes32 salt,
        uint256 path,
        bytes memory sender,
        bytes memory contractCalldata,
        bool intent
    ) public {
        {
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        vm.prank(address(handler));
        expectAckFailure(
            caller,
            IBCPacket({
                sourceChannelId: sourceChannelId,
                destinationChannelId: destinationChannelId,
                data: ZkgmLib.encode(
                    ZkgmPacket({
                        salt: salt,
                        path: path,
                        instruction: Instruction({
                            version: ZkgmLib.INSTR_VERSION_0,
                            opcode: ZkgmLib.OP_MULTIPLEX,
                            operand: ZkgmLib.encodeMultiplex(
                                Multiplex({
                                    sender: sender,
                                    eureka: false,
                                    contractAddress: abi.encodePacked(address(0)),
                                    contractCalldata: contractCalldata
                                })
                            )
                        })
                    })
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            false,
            intent
        );
    }

    function expectOnRecvOrderFailure(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        address relayer,
        bytes memory relayerMsg,
        FungibleAssetOrder memory order,
        bool onlyMaker,
        bool intent
    ) internal {
        vm.prank(address(handler));
        expectAckFailure(
            caller,
            IBCPacket({
                sourceChannelId: sourceChannelId,
                destinationChannelId: destinationChannelId,
                data: ZkgmLib.encode(
                    ZkgmPacket({
                        salt: salt,
                        path: path,
                        instruction: Instruction({
                            version: ZkgmLib.INSTR_VERSION_1,
                            opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                            operand: ZkgmLib.encodeFungibleAssetOrder(order)
                        })
                    })
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            relayer,
            relayerMsg,
            onlyMaker,
            intent
        );
    }

    function expectOnRecvOrderProtocolFillSuccess(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        address relayer,
        bytes memory relayerMsg,
        FungibleAssetOrder memory order
    ) internal {
        expectOnRecvTransferSuccessCustomAck(
            caller,
            sourceChannelId,
            destinationChannelId,
            path,
            salt,
            relayer,
            relayerMsg,
            order,
            FungibleAssetOrderAck({
                fillType: ZkgmLib.FILL_TYPE_PROTOCOL,
                marketMaker: ZkgmLib.ACK_EMPTY
            }),
            false
        );
    }

    function expectOnRecvOrderProtocolFillSuccessV2(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        address relayer,
        bytes memory relayerMsg,
        FungibleAssetOrderV2 memory order
    ) internal {
        expectOnRecvTransferSuccessCustomAckV2(
            caller,
            sourceChannelId,
            destinationChannelId,
            path,
            salt,
            relayer,
            relayerMsg,
            order,
            FungibleAssetOrderAck({
                fillType: ZkgmLib.FILL_TYPE_PROTOCOL,
                marketMaker: ZkgmLib.ACK_EMPTY
            }),
            false
        );
    }

    function expectOnRecvOrderMarketMakerFillSuccess(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        address relayer,
        bytes memory relayerMsg,
        FungibleAssetOrder memory order
    ) internal {
        expectOnRecvTransferSuccessCustomAck(
            caller,
            sourceChannelId,
            destinationChannelId,
            path,
            salt,
            relayer,
            relayerMsg,
            order,
            FungibleAssetOrderAck({
                fillType: ZkgmLib.FILL_TYPE_MARKETMAKER,
                marketMaker: relayerMsg
            }),
            false
        );
    }

    function expectOnIntentRecvOrderMarketMakerFillSuccess(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        address relayer,
        bytes memory relayerMsg,
        FungibleAssetOrder memory order
    ) internal {
        expectOnRecvTransferSuccessCustomAck(
            caller,
            sourceChannelId,
            destinationChannelId,
            path,
            salt,
            relayer,
            relayerMsg,
            order,
            FungibleAssetOrderAck({
                fillType: ZkgmLib.FILL_TYPE_MARKETMAKER,
                marketMaker: relayerMsg
            }),
            true
        );
    }

    function buildOrderPacketV2(
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        FungibleAssetOrder memory order
    ) internal returns (IBCPacket memory) {
        return IBCPacket({
            sourceChannelId: sourceChannelId,
            destinationChannelId: destinationChannelId,
            data: ZkgmLib.encode(
                ZkgmPacket({
                    salt: salt,
                    path: path,
                    instruction: Instruction({
                        version: ZkgmLib.INSTR_VERSION_1,
                        opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                        operand: ZkgmLib.encodeFungibleAssetOrder(order)
                    })
                })
            ),
            timeoutHeight: 0,
            timeoutTimestamp: type(uint64).max
        });
    }

    function buildOrderPacketV2(
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        FungibleAssetOrderV2 memory order
    ) internal returns (IBCPacket memory) {
        return IBCPacket({
            sourceChannelId: sourceChannelId,
            destinationChannelId: destinationChannelId,
            data: ZkgmLib.encode(
                ZkgmPacket({
                    salt: salt,
                    path: path,
                    instruction: Instruction({
                        version: ZkgmLib.INSTR_VERSION_2,
                        opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                        operand: ZkgmLib.encodeFungibleAssetOrderV2(order)
                    })
                })
            ),
            timeoutHeight: 0,
            timeoutTimestamp: type(uint64).max
        });
    }

    function expectOnRecvTransferSuccessCustomAck(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        address relayer,
        bytes memory relayerMsg,
        FungibleAssetOrder memory order,
        FungibleAssetOrderAck memory expectedAck,
        bool intent
    ) internal {
        expectAckSuccess(
            caller,
            buildOrderPacketV2(
                sourceChannelId, destinationChannelId, path, salt, order
            ),
            relayer,
            relayerMsg,
            ZkgmLib.encodeFungibleAssetOrderAck(expectedAck),
            intent
        );
    }

    function expectOnRecvTransferSuccessCustomAckV2(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        address relayer,
        bytes memory relayerMsg,
        FungibleAssetOrderV2 memory order,
        FungibleAssetOrderAck memory expectedAck,
        bool intent
    ) internal {
        expectAckSuccess(
            caller,
            buildOrderPacketV2(
                sourceChannelId, destinationChannelId, path, salt, order
            ),
            relayer,
            relayerMsg,
            ZkgmLib.encodeFungibleAssetOrderAck(expectedAck),
            intent
        );
    }

    function test_onRecvPacket_transferNative_wrap_ok(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        // NOTE: we use u192 to avoid having the channel path being full (max u256)
        // as we need to append the destination channel in the test (leave a u32
        // slot in the u256).
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount
    ) public {
        {
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        (address quoteToken,) =
            zkgm.predictWrappedToken(path, destinationChannelId, baseToken);
        {
            if (baseAmount > 0) {
                zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
            }
        }
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccess(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
    }

    function _metadata(
        TokenMeta memory tokenMeta
    ) internal returns (FungibleAssetMetadata memory) {
        return FungibleAssetMetadata({
            implementation: abi.encodePacked(erc20Impl),
            initializer: abi.encodeCall(
                ZkgmERC20.initialize,
                (
                    zkgm.authority(),
                    address(zkgm),
                    tokenMeta.name,
                    tokenMeta.symbol,
                    tokenMeta.decimals
                )
            )
        });
    }

    struct TokenMeta {
        string symbol;
        string name;
        uint8 decimals;
    }

    function test_onRecvPacket_transferNative_v2_wrap_ok(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        // NOTE: we use u192 to avoid having the channel path being full (max u256)
        // as we need to append the destination channel in the test (leave a u32
        // slot in the u256).
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        TokenMeta memory baseTokenMeta,
        uint256 baseAmount
    ) public {
        {
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        FungibleAssetMetadata memory metadata = _metadata(baseTokenMeta);
        (address quoteToken,) = zkgm.predictWrappedTokenV2(
            path, destinationChannelId, baseToken, metadata
        );
        {
            if (baseAmount > 0) {
                zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
            }
        }
        {
            FungibleAssetOrderV2 memory order = FungibleAssetOrderV2({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseAmount: baseAmount,
                metadataType: ZkgmLib.FUNGIBLE_ASSET_METADATA_TYPE_PREIMAGE,
                metadata: ZkgmLib.encodeFungibleAssetMetadata(metadata),
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccessV2(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
    }

    function test_onRecvPacket_transferNative_newWrapped(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        address receiver,
        bytes memory baseToken,
        TokenMeta memory baseTokenMeta,
        uint256 baseAmount
    ) public returns (address) {
        {
            vm.assume(receiver != address(0));
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        (address quoteToken,) =
            zkgm.predictWrappedToken(path, destinationChannelId, baseToken);
        assertFalse(ZkgmLib.isDeployed(quoteToken));
        if (baseAmount > 0) {
            zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
        }
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(receiver),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenMeta.symbol,
                baseTokenName: baseTokenMeta.name,
                baseTokenDecimals: baseTokenMeta.decimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccess(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
        assertTrue(ZkgmLib.isDeployed(quoteToken));
        assertEq(
            AccessManagedUpgradeable(quoteToken).authority(), address(this)
        );
        return quoteToken;
    }

    function test_onRecvPacket_transferNative_newWrapped_v2(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        address receiver,
        bytes memory baseToken,
        TokenMeta memory baseTokenMeta,
        uint256 baseAmount
    ) public returns (address) {
        {
            vm.assume(receiver != address(0));
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        FungibleAssetMetadata memory metadata = _metadata(baseTokenMeta);
        (address quoteToken,) = zkgm.predictWrappedTokenV2(
            path, destinationChannelId, baseToken, metadata
        );
        assertFalse(ZkgmLib.isDeployed(quoteToken));
        if (baseAmount > 0) {
            zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
        }
        {
            FungibleAssetOrderV2 memory order = FungibleAssetOrderV2({
                sender: sender,
                receiver: abi.encodePacked(receiver),
                baseToken: baseToken,
                baseAmount: baseAmount,
                metadataType: ZkgmLib.FUNGIBLE_ASSET_METADATA_TYPE_PREIMAGE,
                metadata: ZkgmLib.encodeFungibleAssetMetadata(metadata),
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccessV2(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
        assertTrue(ZkgmLib.isDeployed(quoteToken));
        assertEq(
            AccessManagedUpgradeable(quoteToken).authority(), address(this)
        );
        return quoteToken;
    }

    function test_onRecvPacket_transferNative_newWrapped_originSet(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount
    ) public {
        {
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        (address quoteToken,) =
            zkgm.predictWrappedToken(path, destinationChannelId, baseToken);
        assertEq(zkgm.tokenOrigin(quoteToken), 0);
        if (baseAmount > 0) {
            zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
        }
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccess(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
        assertEq(
            zkgm.tokenOrigin(quoteToken),
            ZkgmLib.updateChannelPath(path, destinationChannelId)
        );
    }

    function test_onRecvPacket_transferNative_wrap_relativeSupplyChange(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount
    ) public {
        {
            vm.assume(baseAmount > 0);
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        (address quoteToken,) =
            zkgm.predictWrappedToken(path, destinationChannelId, baseToken);
        if (baseAmount > 0) {
            zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
        }
        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(this), baseAmount);
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccess(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
        assertEq(IERC20(quoteToken).totalSupply(), baseAmount);
    }

    function test_onRecvPacket_transferNative_wrap_splitFee(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(relayer != address(0));
            vm.assume(quoteAmount < baseAmount);
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        (address quoteToken,) =
            zkgm.predictWrappedToken(path, destinationChannelId, baseToken);
        if (quoteAmount > 0) {
            zkgm.doSetBucketConfig(quoteToken, quoteAmount, 1, false);
            vm.expectEmit();
            emit IERC20.Transfer(address(0), address(this), quoteAmount);
        }
        uint256 fee = baseAmount - quoteAmount;
        if (fee > 0) {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), relayer, fee);
        }
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            });
            expectOnRecvOrderProtocolFillSuccess(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
    }

    function test_increaseOutstanding_decreaseOutstanding_iso(
        uint32 sourceChannelId,
        uint256 path,
        address token,
        uint256 amount
    ) public {
        assertEq(zkgm.channelBalance(sourceChannelId, path, token), 0);
        zkgm.doIncreaseOutstanding(sourceChannelId, path, token, amount);
        assertEq(zkgm.channelBalance(sourceChannelId, path, token), amount);
        zkgm.doDecreaseOutstanding(sourceChannelId, path, token, amount);
        assertEq(zkgm.channelBalance(sourceChannelId, path, token), 0);
    }

    function test_increaseOutstanding_decreaseOutstanding_v2_iso(
        uint32 sourceChannelId,
        uint256 path,
        address token,
        bytes32 metadataImage,
        uint256 amount
    ) public {
        assertEq(
            zkgm.channelBalanceV2(sourceChannelId, path, token, metadataImage),
            0
        );
        zkgm.doIncreaseOutstandingV2(
            sourceChannelId, path, token, metadataImage, amount
        );
        assertEq(
            zkgm.channelBalanceV2(sourceChannelId, path, token, metadataImage),
            amount
        );
        zkgm.doDecreaseOutstandingV2(
            sourceChannelId, path, token, metadataImage, amount
        );
        assertEq(
            zkgm.channelBalanceV2(sourceChannelId, path, token, metadataImage),
            0
        );
    }

    function test_onRecvPacket_transferNative_unwrap_ok(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount
    ) public {
        {
            vm.assume(path != 0);
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        // Fake an increase of outstanding balance as if we transferred out.
        erc20.mint(address(zkgm), baseAmount);
        address quoteToken = address(erc20);
        zkgm.doIncreaseOutstanding(
            destinationChannelId,
            ZkgmLib.reverseChannelPath(path),
            quoteToken,
            baseAmount
        );
        if (baseAmount > 0) {
            zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
        }
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: ZkgmLib.reverseChannelPath(path),
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccess(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
    }

    function test_onRecvPacket_transferNative_unwrap_decreaseOutstanding(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount
    ) public {
        {
            vm.assume(path != 0);
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        // Fake an increase of outstanding balance as if we transferred out.
        erc20.mint(address(zkgm), baseAmount);
        address quoteToken = address(erc20);
        zkgm.doIncreaseOutstanding(
            destinationChannelId,
            ZkgmLib.reverseChannelPath(path),
            quoteToken,
            baseAmount
        );
        if (baseAmount > 0) {
            zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
        }

        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: ZkgmLib.reverseChannelPath(path),
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccess(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
        assertEq(zkgm.channelBalance(destinationChannelId, path, quoteToken), 0);
    }

    function test_onRecvPacket_transferNative_v2_unwrap_decreaseOutstanding(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        TokenMeta memory baseTokenMeta,
        uint256 baseAmount
    ) public {
        {
            vm.assume(path != 0);
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        FungibleAssetMetadata memory metadata = _metadata(baseTokenMeta);
        bytes32 metadataImage =
            EfficientHashLib.hash(ZkgmLib.encodeFungibleAssetMetadata(metadata));
        // Fake an increase of outstanding balance as if we transferred out.
        erc20.mint(address(zkgm), baseAmount);
        address quoteToken = address(erc20);
        zkgm.doIncreaseOutstandingV2(
            destinationChannelId,
            ZkgmLib.reverseChannelPath(path),
            quoteToken,
            metadataImage,
            baseAmount
        );
        if (baseAmount > 0) {
            zkgm.doSetBucketConfig(quoteToken, baseAmount, 1, false);
        }

        {
            FungibleAssetOrderV2 memory order = FungibleAssetOrderV2({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseAmount: baseAmount,
                metadataType: ZkgmLib.FUNGIBLE_ASSET_METADATA_TYPE_IMAGE_UNWRAP,
                metadata: abi.encodePacked(metadataImage),
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            });
            expectOnRecvOrderProtocolFillSuccessV2(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
        assertEq(
            zkgm.channelBalanceV2(
                destinationChannelId, path, quoteToken, metadataImage
            ),
            0
        );
    }

    function test_onRecvPacket_transferNative_unwrap_channel_noOutstanding(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint32 fakeDestinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount
    ) public {
        {
            vm.assume(path > 0);
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(fakeDestinationChannelId > 0);
            vm.assume(destinationChannelId != fakeDestinationChannelId);
            vm.assume(baseAmount > 0);
        }
        // Fake an increase of outstanding balance as if we transferred out.
        erc20.mint(address(zkgm), baseAmount);
        address quoteToken = address(erc20);
        zkgm.doIncreaseOutstanding(
            destinationChannelId,
            ZkgmLib.reverseChannelPath(path),
            quoteToken,
            baseAmount
        );
        expectOnRecvOrderFailure(
            caller,
            sourceChannelId,
            fakeDestinationChannelId,
            path,
            salt,
            relayer,
            relayerMsg,
            FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: ZkgmLib.reverseChannelPath(path),
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            }),
            false,
            false
        );
    }

    function test_onRecvPacket_transferNative_unwrap_path_noOutstanding(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        uint192 differentPath,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount
    ) public {
        {
            vm.assume(path > 0);
            vm.assume(differentPath > 0);
            vm.assume(path != differentPath);
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(baseAmount > 0);
        }
        // Fake an increase of outstanding balance as if we transferred out.
        erc20.mint(address(zkgm), baseAmount);
        address quoteToken = address(erc20);
        zkgm.doIncreaseOutstanding(
            destinationChannelId,
            ZkgmLib.reverseChannelPath(path),
            quoteToken,
            baseAmount
        );
        expectOnRecvOrderFailure(
            caller,
            sourceChannelId,
            destinationChannelId,
            differentPath,
            salt,
            relayer,
            relayerMsg,
            FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: ZkgmLib.reverseChannelPath(path),
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: baseAmount
            }),
            false,
            false
        );
    }

    function test_onRecvPacket_marketMakerFill_ok(
        address marketMaker,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(marketMaker != address(0));
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        address quoteToken = address(erc20);
        {
            if (quoteAmount > 0) {
                erc20.mint(marketMaker, quoteAmount);
                vm.prank(marketMaker);
                erc20.approve(address(zkgm), quoteAmount);
                zkgm.doSetBucketConfig(quoteToken, quoteAmount, 1, false);
                vm.expectEmit();
                emit IERC20.Transfer(marketMaker, address(this), quoteAmount);
            }
        }
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            });
            expectOnRecvOrderMarketMakerFillSuccess(
                marketMaker,
                sourceChannelId,
                destinationChannelId,
                0,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
    }

    function test_onRecvPacket_marketMakerFill_gasStation_ok(
        address marketMaker,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        uint128 quoteAmount
    ) public {
        {
            vm.assume(marketMaker != address(0));
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        {
            if (quoteAmount > 0) {
                vm.deal(marketMaker, quoteAmount);
                vm.startPrank(marketMaker);
                weth.deposit{value: quoteAmount}();
                weth.approve(address(zkgm), quoteAmount);
                vm.stopPrank();
                vm.expectEmit();
                emit IERC20.Transfer(marketMaker, address(zkgm), quoteAmount);
                vm.expectEmit();
                emit IERC20.Transfer(address(zkgm), address(0), quoteAmount);
            }
        }
        assertEq(quoteAmount, weth.balanceOf(marketMaker));
        assertEq(0, address(zkgm).balance);
        uint256 selfBalance = address(this).balance;
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(ZkgmLib.NATIVE_TOKEN_ERC_7528_ADDRESS),
                quoteAmount: quoteAmount
            });
            expectOnRecvOrderMarketMakerFillSuccess(
                marketMaker,
                sourceChannelId,
                destinationChannelId,
                0,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
        assertEq(0, weth.balanceOf(marketMaker));
        assertEq(0, address(zkgm).balance);
        assertEq(selfBalance + quoteAmount, address(this).balance);
    }

    function test_onRecvPacket_marketMakerFill_noAllowance_reverts_onlyMaker(
        address marketMaker,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(quoteAmount > 0);
            vm.assume(marketMaker != address(0));
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        address quoteToken = address(erc20);
        zkgm.doSetBucketConfig(quoteToken, quoteAmount, 1, false);
        expectOnRecvOrderFailure(
            marketMaker,
            sourceChannelId,
            destinationChannelId,
            0,
            salt,
            relayer,
            relayerMsg,
            FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            }),
            true,
            false
        );
    }

    function internalOnAckOrder(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        uint256 path,
        bytes32 salt,
        address relayer,
        FungibleAssetOrder memory order,
        bytes memory ack
    ) internal {
        vm.prank(address(handler));
        zkgm.onAcknowledgementPacket(
            caller,
            IBCPacket({
                sourceChannelId: sourceChannelId,
                destinationChannelId: destinationChannelId,
                data: ZkgmLib.encode(
                    ZkgmPacket({
                        salt: salt,
                        path: path,
                        instruction: Instruction({
                            version: ZkgmLib.INSTR_VERSION_1,
                            opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
                            operand: ZkgmLib.encodeFungibleAssetOrder(order)
                        })
                    })
                ),
                timeoutHeight: type(uint64).max,
                timeoutTimestamp: 0
            }),
            ack,
            relayer
        );
    }

    function test_onAckPacket_onlyIBC(
        address caller,
        IBCPacket memory packet,
        address relayer,
        bytes memory ack
    ) public {
        vm.expectRevert(IBCAppLib.ErrNotIBC.selector);
        zkgm.onAcknowledgementPacket(caller, packet, ack, relayer);
    }

    function test_onAckPacket_transferNative_unwrap_successAck_protocolFill_noop(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(path != 0);
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        internalOnAckOrder(
            caller,
            sourceChannelId,
            destinationChannelId,
            path,
            salt,
            relayer,
            FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: ZkgmLib.reverseChannelPath(path),
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            }),
            ZkgmLib.encodeAck(
                Ack({
                    tag: ZkgmLib.ACK_SUCCESS,
                    innerAck: ZkgmLib.encodeFungibleAssetOrderAck(
                        FungibleAssetOrderAck({
                            fillType: ZkgmLib.FILL_TYPE_PROTOCOL,
                            marketMaker: ZkgmLib.ACK_EMPTY
                        })
                    )
                })
            )
        );
        (, bytes32[] memory writeSlots) = vm.accesses(address(zkgm));
        assertEq(writeSlots.length, 0);
    }

    function test_onAckPacket_transfer_successAck_marketMakerFill_unescrowAndPay(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(relayer != address(0));
            vm.assume(path > 0);
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(baseAmount > 0);
            vm.assume(quoteAmount > 0);
        }
        zkgm.doIncreaseOutstanding(
            sourceChannelId, path, address(erc20), baseAmount
        );
        erc20.mint(address(zkgm), baseAmount);
        vm.expectEmit();
        emit IERC20.Transfer(address(zkgm), relayer, baseAmount);
        internalOnAckOrder(
            caller,
            sourceChannelId,
            destinationChannelId,
            path,
            salt,
            relayer,
            FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: abi.encodePacked(erc20),
                baseTokenPath: 0,
                baseTokenSymbol: erc20.symbol(),
                baseTokenName: erc20.name(),
                baseTokenDecimals: erc20.decimals(),
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            }),
            ZkgmLib.encodeAck(
                Ack({
                    tag: ZkgmLib.ACK_SUCCESS,
                    innerAck: ZkgmLib.encodeFungibleAssetOrderAck(
                        FungibleAssetOrderAck({
                            fillType: ZkgmLib.FILL_TYPE_MARKETMAKER,
                            marketMaker: abi.encodePacked(relayer)
                        })
                    )
                })
            )
        );
    }

    function test_onAckPacket_transfer_successAck_marketMakerFill_mintAndPay(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        bytes memory sender,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(relayer != address(0));
            vm.assume(path > 0);
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(baseAmount > 0);
            vm.assume(quoteAmount > 0);
        }
        vm.expectEmit();
        emit IERC20.Transfer(address(0), relayer, baseAmount);

        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: abi.encodePacked(erc20),
                baseTokenPath: ZkgmLib.reverseChannelPath(path),
                baseTokenSymbol: erc20.symbol(),
                baseTokenName: erc20.name(),
                baseTokenDecimals: erc20.decimals(),
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            });
            internalOnAckOrder(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                order,
                ZkgmLib.encodeAck(
                    Ack({
                        tag: ZkgmLib.ACK_SUCCESS,
                        innerAck: ZkgmLib.encodeFungibleAssetOrderAck(
                            FungibleAssetOrderAck({
                                fillType: ZkgmLib.FILL_TYPE_MARKETMAKER,
                                marketMaker: abi.encodePacked(relayer)
                            })
                        )
                    })
                )
            );
        }
    }

    function test_onAckPacket_transfer_failureAck_unescrowRefund(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        address sender,
        bytes memory receiver,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(sender != address(0));
            vm.assume(relayer != address(0));
            vm.assume(path > 0);
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(baseAmount > 0);
            vm.assume(quoteAmount > 0);
        }
        erc20.mint(address(zkgm), baseAmount);
        zkgm.doIncreaseOutstanding(
            sourceChannelId, path, address(erc20), baseAmount
        );
        vm.expectEmit();
        emit IERC20.Transfer(address(zkgm), sender, baseAmount);
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: abi.encodePacked(sender),
                receiver: receiver,
                baseToken: abi.encodePacked(erc20),
                baseTokenPath: 0,
                baseTokenSymbol: erc20.symbol(),
                baseTokenName: erc20.name(),
                baseTokenDecimals: erc20.decimals(),
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            });
            internalOnAckOrder(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                order,
                ZkgmLib.encodeAck(
                    Ack({tag: ZkgmLib.ACK_FAILURE, innerAck: ZkgmLib.ACK_EMPTY})
                )
            );
        }
    }

    function test_onAckPacket_transfer_failureAck_unescrowRefund_decreaseOutstanding(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        address sender,
        bytes memory receiver,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(sender != address(0));
            vm.assume(relayer != address(0));
            vm.assume(path > 0);
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(baseAmount > 0);
            vm.assume(quoteAmount > 0);
        }
        erc20.mint(address(zkgm), baseAmount);
        zkgm.doIncreaseOutstanding(
            sourceChannelId, path, address(erc20), baseAmount
        );
        vm.expectEmit();
        emit IERC20.Transfer(address(zkgm), sender, baseAmount);
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: abi.encodePacked(sender),
                receiver: receiver,
                baseToken: abi.encodePacked(erc20),
                baseTokenPath: 0,
                baseTokenSymbol: erc20.symbol(),
                baseTokenName: erc20.name(),
                baseTokenDecimals: erc20.decimals(),
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            });
            internalOnAckOrder(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                order,
                ZkgmLib.encodeAck(
                    Ack({tag: ZkgmLib.ACK_FAILURE, innerAck: ZkgmLib.ACK_EMPTY})
                )
            );
        }
        assertEq(zkgm.channelBalance(sourceChannelId, path, address(erc20)), 0);
    }

    function test_onAckPacket_transfer_failureAck_mintRefund(
        address caller,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        uint192 path,
        bytes32 salt,
        address sender,
        bytes memory receiver,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        bytes memory quoteToken,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(sender != address(0));
            vm.assume(relayer != address(0));
            vm.assume(path > 0);
            vm.assume(sourceChannelId > 0);
            vm.assume(destinationChannelId > 0);
            vm.assume(baseAmount > 0);
            vm.assume(quoteAmount > 0);
        }
        vm.expectEmit();
        emit IERC20.Transfer(address(0), sender, baseAmount);
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: abi.encodePacked(sender),
                receiver: receiver,
                baseToken: abi.encodePacked(erc20),
                baseTokenPath: path,
                baseTokenSymbol: erc20.symbol(),
                baseTokenName: erc20.name(),
                baseTokenDecimals: erc20.decimals(),
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            });
            internalOnAckOrder(
                caller,
                sourceChannelId,
                destinationChannelId,
                path,
                salt,
                relayer,
                order,
                ZkgmLib.encodeAck(
                    Ack({tag: ZkgmLib.ACK_FAILURE, innerAck: ZkgmLib.ACK_EMPTY})
                )
            );
        }
    }

    function test_onTimeout_onlyIBC(
        address caller,
        IBCPacket memory packet,
        address relayer
    ) public {
        vm.expectRevert(IBCAppLib.ErrNotIBC.selector);
        zkgm.onTimeoutPacket(caller, packet, relayer);
    }

    function test_onRecvIntentPacket_onlyIBC(
        address caller,
        IBCPacket memory packet,
        address relayer,
        bytes memory relayerMsg
    ) public {
        vm.expectRevert(IBCAppLib.ErrNotIBC.selector);
        zkgm.onRecvIntentPacket(caller, packet, relayer, relayerMsg);
    }

    function test_onRecvIntentPacket_marketMakerFill_ok(
        address marketMaker,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(marketMaker != address(0));
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        address quoteToken = address(erc20);
        if (quoteAmount > 0) {
            erc20.mint(marketMaker, quoteAmount);
            vm.prank(marketMaker);
            erc20.approve(address(zkgm), quoteAmount);
            zkgm.doSetBucketConfig(quoteToken, quoteAmount, 1, false);
            vm.expectEmit();
            emit IERC20.Transfer(marketMaker, address(this), quoteAmount);
        }
        {
            FungibleAssetOrder memory order = FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            });
            expectOnIntentRecvOrderMarketMakerFillSuccess(
                marketMaker,
                sourceChannelId,
                destinationChannelId,
                0,
                salt,
                relayer,
                relayerMsg,
                order
            );
        }
    }

    function test_onRecvIntentPacket_marketMakerFill_noAllowance_reverts_onlyMaker(
        address marketMaker,
        uint32 sourceChannelId,
        uint32 destinationChannelId,
        address relayer,
        bytes memory relayerMsg,
        bytes32 salt,
        bytes memory sender,
        bytes memory baseToken,
        string memory baseTokenSymbol,
        string memory baseTokenName,
        uint8 baseTokenDecimals,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public {
        {
            vm.assume(quoteAmount > 0);
            vm.assume(marketMaker != address(0));
            vm.assume(sourceChannelId != 0);
            vm.assume(destinationChannelId != 0);
        }
        address quoteToken = address(erc20);
        zkgm.doSetBucketConfig(quoteToken, quoteAmount, 1, false);
        expectOnRecvOrderFailure(
            marketMaker,
            sourceChannelId,
            destinationChannelId,
            0,
            salt,
            relayer,
            relayerMsg,
            FungibleAssetOrder({
                sender: sender,
                receiver: abi.encodePacked(address(this)),
                baseToken: baseToken,
                baseTokenPath: 0,
                baseTokenSymbol: baseTokenSymbol,
                baseTokenName: baseTokenName,
                baseTokenDecimals: baseTokenDecimals,
                baseAmount: baseAmount,
                quoteToken: abi.encodePacked(quoteToken),
                quoteAmount: quoteAmount
            }),
            true,
            true
        );
    }

    function test_create_foa() public {
        FungibleAssetOrder memory foa = FungibleAssetOrder({
            sender: abi.encodePacked("union1jk9psyhvgkrt2cumz8eytll2244m2nnz4yt2g2"),
            receiver: abi.encodePacked(
                address(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD)
            ),
            baseToken: hex"6d756e6f",
            baseTokenPath: 0,
            baseTokenSymbol: "muno",
            baseTokenName: "muno",
            baseTokenDecimals: 6,
            baseAmount: 100,
            quoteToken: hex"16628cB81ffDA9B8470e16299eFa5F76bF45A579",
            quoteAmount: 100
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_1,
            opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
            operand: ZkgmLib.encodeFungibleAssetOrder(foa)
        });
        console.logBytes(ZkgmLib.encodeInstruction(inst));
    }

    function test_create_foa_v2_preimage_evm() public {
        FungibleAssetMetadata memory metadata = FungibleAssetMetadata({
            implementation: abi.encodePacked(
                0x999709eB04e8A30C7aceD9fd920f7e04EE6B97bA
            ),
            initializer: abi.encodeCall(
                ZkgmERC20.initialize,
                (
                    address(0x6C1D11bE06908656D16EBFf5667F1C45372B7c89),
                    address(0x05FD55C1AbE31D3ED09A76216cA8F0372f4B2eC5),
                    "Uno",
                    "U",
                    6
                )
            )
        });
        FungibleAssetOrderV2 memory foa = FungibleAssetOrderV2({
            sender: abi.encodePacked("union1jk9psyhvgkrt2cumz8eytll2244m2nnz4yt2g2"),
            receiver: abi.encodePacked(
                address(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD)
            ),
            baseToken: hex"6d756e6f",
            metadataType: ZkgmLib.FUNGIBLE_ASSET_METADATA_TYPE_PREIMAGE,
            metadata: ZkgmLib.encodeFungibleAssetMetadata(metadata),
            baseAmount: 100,
            quoteToken: hex"49aCf968c7E8807B39e980b2a924E97C8ead3a22",
            quoteAmount: 100
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_2,
            opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
            operand: ZkgmLib.encodeFungibleAssetOrderV2(foa)
        });
        console.log("Initializer");
        console.logBytes(metadata.initializer);
        console.log("Instruction");
        console.logBytes(ZkgmLib.encodeInstruction(inst));
    }

    function test_create_foa_v2_image_evm() public {
        FungibleAssetMetadata memory metadata = FungibleAssetMetadata({
            implementation: abi.encodePacked(
                0x999709eB04e8A30C7aceD9fd920f7e04EE6B97bA
            ),
            initializer: abi.encodeCall(
                ZkgmERC20.initialize,
                (
                    address(0x6C1D11bE06908656D16EBFf5667F1C45372B7c89),
                    address(0x05FD55C1AbE31D3ED09A76216cA8F0372f4B2eC5),
                    "Uno",
                    "U",
                    6
                )
            )
        });
        bytes32 image = EfficientHashLib.hash(
            abi.encode(metadata.implementation, metadata.initializer)
        );
        FungibleAssetOrderV2 memory foa = FungibleAssetOrderV2({
            sender: abi.encodePacked("union1jk9psyhvgkrt2cumz8eytll2244m2nnz4yt2g2"),
            receiver: abi.encodePacked(
                address(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD)
            ),
            baseToken: hex"6d756e6f",
            metadataType: ZkgmLib.FUNGIBLE_ASSET_METADATA_TYPE_IMAGE,
            metadata: abi.encodePacked(image),
            baseAmount: 100,
            quoteToken: hex"49aCf968c7E8807B39e980b2a924E97C8ead3a22",
            quoteAmount: 100
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_2,
            opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
            operand: ZkgmLib.encodeFungibleAssetOrderV2(foa)
        });
        console.log("Image");
        console.logBytes32(image);
        console.log("Instruction");
        console.logBytes(ZkgmLib.encodeInstruction(inst));
    }

    function test_create_foa_v2_preimage_cosmwasm() public {
        // Admin of the CW20-compatible token
        string memory admin = "union1jk9psyhvgkrt2cumz8eytll2244m2nnz4yt2g2";
        // CW20 code id
        uint64 codeId = 5;
        // Note on cosmwasm the minter must be the zkgm cw20 minter
        string memory initMsg =
            "{\"init\":{\"name\":\"Uno\",\"symbol\":\"UNO\",\"decimals\":6,\"initial_balances\":[],\"mint\":{\"minter\":\"union1sctpgdvs23pxv43zclww5jdzghsfuph9rkstjegx35wjkvzv6wtqpq7xxg\",\"cap\":null},\"marketing\":null}}";
        FungibleAssetMetadata memory metadata = FungibleAssetMetadata({
            implementation: abi.encode(admin, codeId),
            initializer: bytes(initMsg)
        });
        FungibleAssetOrderV2 memory foa = FungibleAssetOrderV2({
            sender: abi.encodePacked(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD),
            receiver: abi.encodePacked(
                "union1jk9psyhvgkrt2cumz8eytll2244m2nnz4yt2g2"
            ),
            baseToken: hex"49aCf968c7E8807B39e980b2a924E97C8ead3a22",
            metadataType: ZkgmLib.FUNGIBLE_ASSET_METADATA_TYPE_PREIMAGE,
            metadata: ZkgmLib.encodeFungibleAssetMetadata(metadata),
            baseAmount: 10,
            quoteToken: bytes(
                "union1uyxeud073ttss4stt92hvt4wgzzyrssqata8058305km6xp7vzgs85kpst"
            ),
            quoteAmount: 10
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_2,
            opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
            operand: ZkgmLib.encodeFungibleAssetOrderV2(foa)
        });
        console.log("Initializer");
        console.logBytes(metadata.initializer);
        console.log("Instruction");
        console.log(inst.version);
        console.log(inst.opcode);
        console.logBytes(inst.operand);
    }

    function test_create_foa_v2_image_cosmwasm() public {
        // Admin of the CW20-compatible token
        string memory admin = "union1jk9psyhvgkrt2cumz8eytll2244m2nnz4yt2g2";
        // CW20 code id
        uint64 codeId = 5;
        // Note on cosmwasm the minter must be the zkgm cw20 minter
        string memory initMsg =
            "{\"init\":{\"name\":\"Uno\",\"symbol\":\"UNO\",\"decimals\":6,\"initial_balances\":[],\"mint\":{\"minter\":\"union1sctpgdvs23pxv43zclww5jdzghsfuph9rkstjegx35wjkvzv6wtqpq7xxg\",\"cap\":null},\"marketing\":null}}";
        FungibleAssetMetadata memory metadata = FungibleAssetMetadata({
            implementation: abi.encode(admin, codeId),
            initializer: bytes(initMsg)
        });
        bytes32 image = EfficientHashLib.hash(
            abi.encode(metadata.implementation, metadata.initializer)
        );
        console.log("Image:");
        console.logBytes32(image);
        FungibleAssetOrderV2 memory foa = FungibleAssetOrderV2({
            sender: abi.encodePacked(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD),
            receiver: abi.encodePacked(
                "union1jk9psyhvgkrt2cumz8eytll2244m2nnz4yt2g2"
            ),
            baseToken: hex"49aCf968c7E8807B39e980b2a924E97C8ead3a22",
            metadataType: ZkgmLib.FUNGIBLE_ASSET_METADATA_TYPE_IMAGE,
            metadata: abi.encodePacked(image),
            baseAmount: 10,
            quoteToken: bytes(
                "union1uyxeud073ttss4stt92hvt4wgzzyrssqata8058305km6xp7vzgs85kpst"
            ),
            quoteAmount: 10
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_2,
            opcode: ZkgmLib.OP_FUNGIBLE_ASSET_ORDER,
            operand: ZkgmLib.encodeFungibleAssetOrderV2(foa)
        });
        console.log("Instruction");
        console.log(inst.version);
        console.log(inst.opcode);
        console.logBytes(inst.operand);
    }

    function test_create_stake() public {
        Stake memory stake = Stake({
            tokenId: 1,
            governanceToken: bytes("muno"),
            governanceTokenMetadataImage: 0x996be231a091877022ccdbf41da6e2f92e097c0ccc9480f8b3c630e5c2b14ff1,
            sender: abi.encodePacked(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD),
            beneficiary: abi.encodePacked(
                0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD
            ),
            validator: hex"756e696f6e76616c6f7065723161737873323935667579376a7068387038657174633272387a78676764633230793776663730",
            amount: 10
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_0,
            opcode: ZkgmLib.OP_STAKE,
            operand: ZkgmLib.encodeStake(stake)
        });
        console.log("Instruction");
        console.log(inst.version);
        console.log(inst.opcode);
        console.logBytes(inst.operand);
    }

    function test_create_unstake() public {
        Unstake memory unstake = Unstake({
            tokenId: 1,
            governanceToken: bytes("muno"),
            governanceTokenMetadataImage: 0x996be231a091877022ccdbf41da6e2f92e097c0ccc9480f8b3c630e5c2b14ff1,
            sender: abi.encodePacked(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD),
            validator: hex"756e696f6e76616c6f7065723161737873323935667579376a7068387038657174633272387a78676764633230793776663730",
            amount: 10
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_0,
            opcode: ZkgmLib.OP_UNSTAKE,
            operand: ZkgmLib.encodeUnstake(unstake)
        });
        console.log("Instruction");
        console.log(inst.version);
        console.log(inst.opcode);
        console.logBytes(inst.operand);
    }

    function test_create_withdraw_stake() public {
        WithdrawStake memory withdrawStake = WithdrawStake({
            tokenId: 1,
            governanceToken: bytes("muno"),
            governanceTokenMetadataImage: 0x996be231a091877022ccdbf41da6e2f92e097c0ccc9480f8b3c630e5c2b14ff1,
            sender: abi.encodePacked(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD),
            beneficiary: abi.encodePacked(
                0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD
            )
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_0,
            opcode: ZkgmLib.OP_WITHDRAW_STAKE,
            operand: ZkgmLib.encodeWithdrawStake(withdrawStake)
        });
        console.log("Instruction");
        console.log(inst.version);
        console.log(inst.opcode);
        console.logBytes(inst.operand);
    }

    function test_create_withdraw_rewards() public {
        WithdrawRewards memory withdrawRewards = WithdrawRewards({
            tokenId: 1,
            governanceToken: bytes("muno"),
            governanceTokenMetadataImage: 0x996be231a091877022ccdbf41da6e2f92e097c0ccc9480f8b3c630e5c2b14ff1,
            validator: hex"756e696f6e76616c6f7065723161737873323935667579376a7068387038657174633272387a78676764633230793776663730",
            sender: abi.encodePacked(0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD),
            beneficiary: abi.encodePacked(
                0xBe68fC2d8249eb60bfCf0e71D5A0d2F2e292c4eD
            )
        });
        Instruction memory inst = Instruction({
            version: ZkgmLib.INSTR_VERSION_0,
            opcode: ZkgmLib.OP_WITHDRAW_REWARDS,
            operand: ZkgmLib.encodeWithdrawRewards(withdrawRewards)
        });
        console.log("Instruction");
        console.log(inst.version);
        console.log(inst.opcode);
        console.logBytes(inst.operand);
    }
}
