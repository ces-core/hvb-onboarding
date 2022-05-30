// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Copyright (C) 2021-2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.6.12;

import "./CESFork_GoerliRwaSpell.t.base.sol";

interface WardsLike {
    function wards(address) external view returns (uint256);
}

interface RwaLiquidationLike {
    function wards(address) external returns (uint256);

    function ilks(bytes32)
        external
        returns (
            string memory,
            address,
            uint48,
            uint48
        );

    function rely(address) external;

    function deny(address) external;

    function init(
        bytes32,
        uint256,
        string calldata,
        uint48
    ) external;

    function bump(bytes32 ilk, uint256 val) external;

    function tell(bytes32) external;

    function cure(bytes32) external;

    function cull(bytes32, address) external;

    function good(bytes32) external view returns (bool);
}

interface RwaUrnLike {
    function hope(address) external;

    function can(address) external view returns (uint256);

    function lock(uint256) external;

    function draw(uint256) external;

    function wipe(uint256) external;

    function free(uint256) external;
}

interface RwaOutputConduitLike {
    function wards(address) external returns (uint256);

    function can(address) external returns (uint256);

    function rely(address) external;

    function deny(address) external;

    function hope(address) external;

    function mate(address) external;

    function nope(address) external;

    function bud(address) external returns (uint256);

    function pick(address) external;

    function push() external;
}

contract DssSpellTest is GoerliDssSpellTestBase {
    // GOERLI ADDRESSES
    bytes32 constant ilk = "RWA009AT1-A";
    DSTokenAbstract rwagem = DSTokenAbstract(addr.addr("RWA009AT1"));
    GemJoinAbstract rwajoin = GemJoinAbstract(addr.addr("MCD_JOIN_RWA009AT1_A"));
    RwaLiquidationLike oracle = RwaLiquidationLike(addr.addr("MIP21_LIQUIDATION_ORACLE"));
    RwaUrnLike rwaurn = RwaUrnLike(addr.addr("RWA009AT1_A_URN"));
    RwaOutputConduitLike rwaconduitout = RwaOutputConduitLike(addr.addr("RWA009AT1_A_OUTPUT_CONDUIT"));

    address makerDeployer06 = 0xda0fab060e6cc7b1C0AA105d29Bd50D71f036711;

    BumpSpell bumpSpell;
    TellSpell tellSpell;
    CureSpell cureSpell;
    CullSpell cullSpell;
    EndSpell endSpell;

    event Debug(uint256 index, uint256 val);
    event Debug(uint256 index, address addr);
    event Debug(uint256 index, bytes32 what);

    function testSpellIsCast_GENERAL() public {
        string memory description = new DssSpell().description();
        assertTrue(bytes(description).length > 0, "TestError/spell-description-length");
        // DS-Test can't handle strings directly, so cast to a bytes32.
        assertEq(stringToBytes32(spell.description()), stringToBytes32(description), "TestError/spell-description");

        if (address(spell) != address(spellValues.deployed_spell)) {
            assertEq(
                spell.expiration(),
                block.timestamp + spellValues.expiration_threshold,
                "TestError/spell-expiration"
            );
        } else {
            assertEq(
                spell.expiration(),
                spellValues.deployed_spell_created + spellValues.expiration_threshold,
                "TestError/spell-expiration"
            );

            // If the spell is deployed compare the on-chain bytecode size with the generated bytecode size.
            // extcodehash doesn't match, potentially because it's address-specific, avenue for further research.
            address depl_spell = spellValues.deployed_spell;
            address code_spell = address(new DssSpell());
            assertEq(getExtcodesize(depl_spell), getExtcodesize(code_spell), "TestError/spell-codesize");
        }

        assertTrue(spell.officeHours() == spellValues.office_hours_enabled, "TestError/spell-office-hours");

        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        checkSystemValues(afterSpell);

        checkCollateralValues(afterSpell);
    }

    function testRemoveChainlogValues() private {
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        try chainLog.getAddress("XXX") {
            assertTrue(false);
        } catch Error(string memory errmsg) {
            assertTrue(cmpStr(errmsg, "dss-chain-log/invalid-key"));
        } catch {
            assertTrue(false);
        }
    }

    // function testAAVEDirectBarChange() public {
    //     DirectDepositLike join = DirectDepositLike(addr.addr("MCD_JOIN_DIRECT_AAVEV2_DAI"));
    //     assertEq(join.bar(), 3.5 * 10**27 / 100);
    //
    //     vote(address(spell));
    //     scheduleWaitAndCast(address(spell));
    //     assertTrue(spell.done());
    //
    //     assertEq(join.bar(), 2.85 * 10**27 / 100);
    // }

    function testCollateralIntegrations() private {
        // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Insert new collateral tests here
        checkIlkIntegration(
            "RWA009AT1-A",
            GemJoinAbstract(addr.addr("MCD_JOIN_RWA009AT1_A")),
            ClipAbstract(addr.addr("MCD_CLIP_RWA009AT1_A")),
            addr.addr("PIP_RWA009AT1"),
            false,
            false,
            false
        );
    }

    function testLerpSurplusBuffer() private {
        // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Insert new SB lerp tests here

        LerpAbstract lerp = LerpAbstract(lerpFactory.lerps("NAME"));

        uint256 duration = 210 days;
        hevm.warp(block.timestamp + duration / 2);
        assertEq(vow.hump(), 60 * MILLION * RAD);
        lerp.tick();
        assertEq(vow.hump(), 75 * MILLION * RAD);
        hevm.warp(block.timestamp + duration / 2);
        lerp.tick();
        assertEq(vow.hump(), 90 * MILLION * RAD);
        assertTrue(lerp.done());
    }

    function testNewChainlogValues() public {
        // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Insert new chainlog values tests here
        assertEq(chainLog.getAddress("RWA009AT1"), addr.addr("RWA009AT1"));
        assertEq(chainLog.getAddress("MCD_JOIN_RWA009AT1_A"), addr.addr("MCD_JOIN_RWA009AT1_A"));
        assertEq(chainLog.getAddress("RWA009AT1_A_URN"), addr.addr("RWA009AT1_A_URN"));
        assertEq(chainLog.getAddress("RWA009AT1_A_OUTPUT_CONDUIT"), addr.addr("RWA009AT1_A_OUTPUT_CONDUIT"));
        assertEq(chainLog.getAddress("RWA_URN_PROXY_VIEW"), addr.addr("RWA_URN_PROXY_VIEW"));

        assertEq(chainLog.version(), "0.3.0");
    }

    function testNewIlkRegistryValues() public {
        // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Insert new ilk registry values tests here
        assertEq(reg.pos("RWA009AT1-A"), 3);
        assertEq(reg.join("RWA009AT1-A"), addr.addr("MCD_JOIN_RWA009AT1_A"));
        assertEq(reg.gem("RWA009AT1-A"), addr.addr("RWA009AT1"));
        assertEq(reg.dec("RWA009AT1-A"), DSTokenAbstract(addr.addr("RWA009AT1")).decimals());
        assertEq(reg.class("RWA009AT1-A"), 3); // Class 3 = Rwa Token
        // assertEq(reg.pip("RWA009AT1-A"),    addr.addr("PIP_RWA009AT1"));
        // We don't have auctions for this collateral
        // assertEq(reg.xlip("RWA009AT1-A"),   addr.addr("MCD_CLIP_RWA009AT1_A"));
        assertEq(reg.name("RWA009AT1-A"), "RWA-009AT1-A");
        assertEq(reg.symbol("RWA009AT1-A"), "RWA009AT1");
    }

    function testNewPermissions() private {
        address MCD_JOIN_RWA009_A = 0x95191eB3Ab5bEB48a3C0b1cd0E6d918931448a1E;

        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        assertEq(WardsLike(addr.addr("MCD_VAT")).wards(MCD_JOIN_RWA009_A), 1);
    }

    function testSpellIsCast_RWA009_INTEGRATION_BUMP() public {
        if (!spell.done()) {
            vote(address(spell));
            scheduleWaitAndCast(address(spell));
            assertTrue(spell.done());
        }

        bumpSpell = new BumpSpell();
        vote(address(bumpSpell));

        bumpSpell.schedule();

        uint256 castTime = block.timestamp + pause.delay();
        hevm.warp(castTime);
        (, address pip, , ) = oracle.ilks("RWA009AT1-A");

        assertEq(DSValueAbstract(pip).read(), bytes32(52 * MILLION * WAD));
        bumpSpell.cast();
        assertEq(DSValueAbstract(pip).read(), bytes32(60 * MILLION * WAD));
    }

    function testSpellIsCast_RWA009_INTEGRATION_TELL() public {
        if (!spell.done()) {
            vote(address(spell));
            scheduleWaitAndCast(address(spell));
            assertTrue(spell.done());
        }

        tellSpell = new TellSpell();
        vote(address(tellSpell));

        tellSpell.schedule();

        uint256 castTime = block.timestamp + pause.delay();
        hevm.warp(castTime);
        (, , , uint48 tocPre) = oracle.ilks("RWA009AT1-A");
        assertTrue(tocPre == 0);
        assertTrue(oracle.good("RWA009AT1-A"));
        tellSpell.cast();
        (, , , uint48 tocPost) = oracle.ilks("RWA009AT1-A");
        assertTrue(tocPost > 0);
        assertTrue(oracle.good("RWA009AT1-A"));
        hevm.warp(block.timestamp + 2 weeks);
        assertTrue(!oracle.good("RWA009AT1-A"));
    }

    function testSpellIsCast_RWA009AT1_INTEGRATION_TELL_CURE_GOOD() public {
        if (!spell.done()) {
            vote(address(spell));
            scheduleWaitAndCast(address(spell));
            assertTrue(spell.done());
        }

        tellSpell = new TellSpell();
        vote(address(tellSpell));

        tellSpell.schedule();

        uint256 castTime = block.timestamp + pause.delay();
        hevm.warp(castTime);
        tellSpell.cast();
        assertTrue(oracle.good(ilk));
        hevm.warp(block.timestamp + 2 weeks);
        assertTrue(!oracle.good(ilk));

        cureSpell = new CureSpell();
        vote(address(cureSpell));

        cureSpell.schedule();
        castTime = block.timestamp + pause.delay();
        hevm.warp(castTime);
        cureSpell.cast();
        assertTrue(oracle.good(ilk));
        (, , , uint48 toc) = oracle.ilks(ilk);
        assertEq(uint256(toc), 0);
    }

    function testFailSpellIsCast_RWA009AT1_INTEGRATION_CURE() public {
        if (!spell.done()) {
            vote(address(spell));
            scheduleWaitAndCast(address(spell));
            assertTrue(spell.done());
        }

        cureSpell = new CureSpell();
        vote(address(cureSpell));

        cureSpell.schedule();
        uint256 castTime = block.timestamp + pause.delay();
        hevm.warp(castTime);
        cureSpell.cast();
    }

    function testSpellIsCast_RWA009AT1_INTEGRATION_TELL_CULL() public {
        if (!spell.done()) {
            vote(address(spell));
            scheduleWaitAndCast(address(spell));
            assertTrue(spell.done());
        }
        assertTrue(oracle.good("RWA009AT1-A"));

        tellSpell = new TellSpell();
        vote(address(tellSpell));

        tellSpell.schedule();

        uint256 castTime = block.timestamp + pause.delay();
        hevm.warp(castTime);
        tellSpell.cast();
        assertTrue(oracle.good("RWA009AT1-A"));
        hevm.warp(block.timestamp + 2 weeks);
        assertTrue(!oracle.good("RWA009AT1-A"));

        cullSpell = new CullSpell();
        vote(address(cullSpell));

        cullSpell.schedule();
        castTime = block.timestamp + pause.delay();
        hevm.warp(castTime);
        cullSpell.cast();
        assertTrue(!oracle.good("RWA009AT1-A"));
        (, address pip, , ) = oracle.ilks("RWA009AT1-A");
        assertEq(DSValueAbstract(pip).read(), bytes32(0));
    }

    function testSpellIsCast_RWA009AT1_OPERATOR_LOCK_DRAW_CONDUITS_WIPE_FREE() public {
        if (!spell.done()) {
            vote(address(spell));
            scheduleWaitAndCast(address(spell));
            assertTrue(spell.done());
        }

        hevm.warp(now + 10 days); // Let rate be > 1

        uint256 totalSupplyBeforeCheat = rwagem.totalSupply();
        // set the balance of this contract
        hevm.store(address(rwagem), keccak256(abi.encode(address(this), uint256(3))), bytes32(uint256(2 * WAD)));
        // increase the total supply
        hevm.store(address(rwagem), bytes32(uint256(2)), bytes32(uint256(rwagem.totalSupply() + 2 * WAD)));
        // setting address(this) as operator
        hevm.store(address(rwaurn), keccak256(abi.encode(address(this), uint256(1))), bytes32(uint256(1)));

        (uint256 preInk, uint256 preArt) = vat.urns(ilk, address(rwaurn));

        assertEq(rwagem.totalSupply(), totalSupplyBeforeCheat + 2 * WAD);
        assertEq(rwagem.balanceOf(address(this)), 2 * WAD);
        assertEq(rwaurn.can(address(this)), 1);

        rwagem.approve(address(rwaurn), 1 * WAD);
        rwaurn.lock(1 * WAD);
        assertEq(dai.balanceOf(address(rwaconduitout)), 0);
        rwaurn.draw(1 * WAD);

        (, uint256 rate, , , ) = vat.ilks("RWA009AT1-A");

        uint256 dustInVat = vat.dai(address(rwaurn));

        (uint256 ink, uint256 art) = vat.urns(ilk, address(rwaurn));
        assertEq(ink, 1 * WAD + preInk);
        uint256 currArt = ((1 * RAD + dustInVat) / rate) + preArt;
        assertTrue(art >= currArt - 2 && art <= currArt + 2); // approximation for vat rounding
        assertEq(dai.balanceOf(address(rwaconduitout)), 1 * WAD);

        // wards
        hevm.store(address(rwaconduitout), keccak256(abi.encode(address(this), uint256(1))), bytes32(uint256(1)));
        // can
        hevm.store(address(rwaconduitout), keccak256(abi.encode(address(this), uint256(2))), bytes32(uint256(1)));
        // may
        hevm.store(address(rwaconduitout), keccak256(abi.encode(address(this), uint256(3))), bytes32(uint256(1)));

        assertEq(dai.balanceOf(address(rwaconduitout)), 1 * WAD);

        rwaconduitout.pick(address(this));

        rwaconduitout.push();

        assertEq(dai.balanceOf(address(rwaconduitout)), 0);
        assertEq(dai.balanceOf(address(this)), 1 * WAD);

        hevm.warp(now + 10 days);

        (ink, art) = vat.urns(ilk, address(rwaurn));
        assertEq(ink, 1 * WAD + preInk);
        currArt = ((1 * RAD + dustInVat) / rate) + preArt;
        assertTrue(art >= currArt - 2 && art <= currArt + 2); // approximation for vat rounding

        (ink, ) = vat.urns(ilk, address(this));
        assertEq(ink, 0);

        jug.drip("RWA009AT1-A");

        (, rate, , , ) = vat.ilks("RWA009AT1-A");

        uint256 daiToPay = (art * rate - dustInVat) / RAY + 1; // extra wei rounding
        uint256 vatDai = daiToPay * RAY;

        uint256 currentDaiSupply = dai.totalSupply();

        hevm.store(
            address(vat),
            keccak256(abi.encode(address(addr.addr("MCD_JOIN_DAI")), uint256(5))),
            bytes32(vatDai)
        ); // Forcing extra dai balance for MCD_JOIN_DAI on the Vat
        hevm.store(address(dai), bytes32(uint256(1)), bytes32(currentDaiSupply + (daiToPay - art))); // Forcing extra DAI total supply to accomodate the accumulated fee
        hevm.store(address(dai), keccak256(abi.encode(address(this), uint256(2))), bytes32(daiToPay)); // Forcing extra DAI balance to pay accumulated fee

        dai.transfer(address(rwaurn), daiToPay);

        assertEq(dai.balanceOf(address(rwaurn)), daiToPay);

        assertEq(vat.dai(address(addr.addr("MCD_JOIN_DAI"))), vatDai);

        rwaurn.wipe(daiToPay);
        rwaurn.free(1 * WAD);
        (ink, art) = vat.urns(ilk, address(rwaurn));
        assertEq(ink, preInk);
        assertTrue(art < 4); // wad -> rad conversion in wipe leaves some dust
        (ink, ) = vat.urns(ilk, address(this));
        assertEq(ink, 0);
    }

    function testFailWrongDay() public {
        require(spell.officeHours() == spellValues.office_hours_enabled);
        if (spell.officeHours()) {
            vote(address(spell));
            scheduleWaitAndCastFailDay();
        } else {
            revert("Office Hours Disabled");
        }
    }

    function testFailTooEarly() public {
        require(spell.officeHours() == spellValues.office_hours_enabled);
        if (spell.officeHours()) {
            vote(address(spell));
            scheduleWaitAndCastFailEarly();
        } else {
            revert("Office Hours Disabled");
        }
    }

    function testFailTooLate() public {
        require(spell.officeHours() == spellValues.office_hours_enabled);
        if (spell.officeHours()) {
            vote(address(spell));
            scheduleWaitAndCastFailLate();
        } else {
            revert("Office Hours Disabled");
        }
    }

    function testOnTime() public {
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
    }

    function testCastCost() public {
        vote(address(spell));
        spell.schedule();

        castPreviousSpell();
        hevm.warp(spell.nextCastTime());
        uint256 startGas = gasleft();
        spell.cast();
        uint256 endGas = gasleft();
        uint256 totalGas = startGas - endGas;

        assertTrue(spell.done());
        // Fail if cast is too expensive
        assertTrue(totalGas <= 10 * MILLION);
    }

    // The specific date doesn't matter that much since function is checking for difference between warps
    function test_nextCastTime() public {
        hevm.warp(1606161600); // Nov 23, 20 UTC (could be cast Nov 26)

        vote(address(spell));
        spell.schedule();

        uint256 monday_1400_UTC = 1606744800; // Nov 30, 2020
        uint256 monday_2100_UTC = 1606770000; // Nov 30, 2020

        // Day tests
        hevm.warp(monday_1400_UTC); // Monday,   14:00 UTC
        assertEq(spell.nextCastTime(), monday_1400_UTC); // Monday,   14:00 UTC

        if (spell.officeHours()) {
            hevm.warp(monday_1400_UTC - 1 days); // Sunday,   14:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC); // Monday,   14:00 UTC

            hevm.warp(monday_1400_UTC - 2 days); // Saturday, 14:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC); // Monday,   14:00 UTC

            hevm.warp(monday_1400_UTC - 3 days); // Friday,   14:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC - 3 days); // Able to cast

            hevm.warp(monday_2100_UTC); // Monday,   21:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC + 1 days); // Tuesday,  14:00 UTC

            hevm.warp(monday_2100_UTC - 1 days); // Sunday,   21:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC); // Monday,   14:00 UTC

            hevm.warp(monday_2100_UTC - 2 days); // Saturday, 21:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC); // Monday,   14:00 UTC

            hevm.warp(monday_2100_UTC - 3 days); // Friday,   21:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC); // Monday,   14:00 UTC

            // Time tests
            uint256 castTime;

            for (uint256 i = 0; i < 5; i++) {
                castTime = monday_1400_UTC + i * 1 days; // Next day at 14:00 UTC
                hevm.warp(castTime - 1 seconds); // 13:59:59 UTC
                assertEq(spell.nextCastTime(), castTime);

                hevm.warp(castTime + 7 hours + 1 seconds); // 21:00:01 UTC
                if (i < 4) {
                    assertEq(spell.nextCastTime(), monday_1400_UTC + (i + 1) * 1 days); // Next day at 14:00 UTC
                } else {
                    assertEq(spell.nextCastTime(), monday_1400_UTC + 7 days); // Next monday at 14:00 UTC (friday case)
                }
            }
        }
    }

    function testFail_notScheduled() public view {
        spell.nextCastTime();
    }

    function test_use_eta() public {
        hevm.warp(1606161600); // Nov 23, 20 UTC (could be cast Nov 26)

        vote(address(spell));
        spell.schedule();

        uint256 castTime = spell.nextCastTime();
        assertEq(castTime, spell.eta());
    }

    function test_OSMs() private {
        // make public to use
        address READER_ADDR = address(0);

        // Track OSM authorizations here
        assertEq(OsmAbstract(addr.addr("PIP_TOKEN")).bud(READER_ADDR), 0);

        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        assertEq(OsmAbstract(addr.addr("PIP_TOKEN")).bud(READER_ADDR), 1);
    }

    function test_Medianizers() private {
        // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Track Median authorizations here
        address SET_TOKEN = address(0);
        address TOKENUSD_MED = OsmAbstract(addr.addr("PIP_TOKEN")).src();
        assertEq(MedianAbstract(TOKENUSD_MED).bud(SET_TOKEN), 1);
    }

    function test_auth() private {
        // make public to use
        checkAuth(false);
    }

    function test_auth_in_sources() private {
        // make public to use
        checkAuth(true);
    }

    // Verifies that the bytecode of the action of the spell used for testing
    // matches what we'd expect.
    //
    // Not a complete replacement for Etherscan verification, unfortunately.
    // This is because the DssSpell bytecode is non-deterministic because it
    // deploys the action in its constructor and incorporates the action
    // address as an immutable variable--but the action address depends on the
    // address of the DssSpell which depends on the address+nonce of the
    // deploying address. If we had a way to simulate a contract creation by
    // an arbitrary address+nonce, we could verify the bytecode of the DssSpell
    // instead.
    //
    // Vacuous until the deployed_spell value is non-zero.
    function test_bytecode_matches() public {
        address expectedAction = (new DssSpell()).action();
        address actualAction = spell.action();
        uint256 expectedBytecodeSize;
        uint256 actualBytecodeSize;
        assembly {
            expectedBytecodeSize := extcodesize(expectedAction)
            actualBytecodeSize := extcodesize(actualAction)
        }

        uint256 metadataLength = getBytecodeMetadataLength(expectedAction);
        assertTrue(metadataLength <= expectedBytecodeSize);
        expectedBytecodeSize -= metadataLength;

        metadataLength = getBytecodeMetadataLength(actualAction);
        assertTrue(metadataLength <= actualBytecodeSize);
        actualBytecodeSize -= metadataLength;

        assertEq(actualBytecodeSize, expectedBytecodeSize);
        uint256 size = actualBytecodeSize;
        uint256 expectedHash;
        uint256 actualHash;
        assembly {
            let ptr := mload(0x40)

            extcodecopy(expectedAction, ptr, 0, size)
            expectedHash := keccak256(ptr, size)

            extcodecopy(actualAction, ptr, 0, size)
            actualHash := keccak256(ptr, size)
        }
        assertEq(expectedHash, actualHash);
    }
}

contract EndSpellAction {
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0x7EafEEa64bF6F79A79853F4A660e0960c821BA50);

    function execute() public {
        EndAbstract(CHANGELOG.getAddress("MCD_END")).cage();
    }
}

contract TestSpell {
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0x7EafEEa64bF6F79A79853F4A660e0960c821BA50);
    DSPauseAbstract public pause = DSPauseAbstract(CHANGELOG.getAddress("MCD_PAUSE"));
    address public action;
    bytes32 public tag;
    uint256 public eta;
    bytes public sig;
    uint256 public expiration;
    bool public done;

    constructor() public {
        sig = abi.encodeWithSignature("execute()");
    }

    function setTag() internal {
        bytes32 _tag;
        address _action = action;
        assembly {
            _tag := extcodehash(_action)
        }
        tag = _tag;
    }

    function schedule() public {
        require(eta == 0, "This spell has already been scheduled");
        eta = block.timestamp + DSPauseAbstract(pause).delay();
        pause.plot(action, tag, sig, eta);
    }

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        pause.exec(action, tag, sig, eta);
    }
}

contract EndSpell is TestSpell {
    constructor() public {
        action = address(new EndSpellAction());
        setTag();
    }
}

contract CullSpellAction {
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0x7EafEEa64bF6F79A79853F4A660e0960c821BA50);
    bytes32 constant ilk = "RWA009AT1-A";

    function execute() public {
        RwaLiquidationLike(CHANGELOG.getAddress("MIP21_LIQUIDATION_ORACLE")).cull(
            ilk,
            CHANGELOG.getAddress("RWA009AT1_A_URN")
        );
    }
}

contract CullSpell is TestSpell {
    constructor() public {
        action = address(new CullSpellAction());
        setTag();
    }
}

contract CureSpellAction {
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0x7EafEEa64bF6F79A79853F4A660e0960c821BA50);
    bytes32 constant ilk = "RWA009AT1-A";

    function execute() public {
        RwaLiquidationLike(CHANGELOG.getAddress("MIP21_LIQUIDATION_ORACLE")).cure(ilk);
    }
}

contract CureSpell is TestSpell {
    constructor() public {
        action = address(new CureSpellAction());
        setTag();
    }
}

contract TellSpellAction {
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0x7EafEEa64bF6F79A79853F4A660e0960c821BA50);
    bytes32 constant ilk = "RWA009AT1-A";

    function execute() public {
        VatAbstract(CHANGELOG.getAddress("MCD_VAT")).file(ilk, "line", 0);
        RwaLiquidationLike(CHANGELOG.getAddress("MIP21_LIQUIDATION_ORACLE")).tell(ilk);
    }
}

contract TellSpell is TestSpell {
    constructor() public {
        action = address(new TellSpellAction());
        setTag();
    }
}

contract BumpSpellAction {
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0x7EafEEa64bF6F79A79853F4A660e0960c821BA50);
    bytes32 constant ilk = "RWA009AT1-A";
    uint256 constant WAD = 10**18;
    uint256 constant MILLION = 10**6;

    function execute() public {
        RwaLiquidationLike(CHANGELOG.getAddress("MIP21_LIQUIDATION_ORACLE")).bump(ilk, 60 * MILLION * WAD);
    }
}

contract BumpSpell is TestSpell {
    constructor() public {
        action = address(new BumpSpellAction());
        setTag();
    }
}
