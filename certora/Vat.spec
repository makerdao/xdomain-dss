// Vat.spec

methods {
    Art(bytes32) returns (uint256) envfree
    art(bytes32, address) returns (uint256) envfree
    can(address, address) returns (uint256) envfree
    dai(address) returns (uint256) envfree
    debt() returns (uint256) envfree
    dust(bytes32) returns (uint256) envfree
    gem(bytes32, address) returns (uint256) envfree
    ilks(bytes32) returns (uint256, uint256, uint256, uint256, uint256) envfree
    ink(bytes32, address) returns (uint256) envfree
    Line() returns (uint256) envfree
    line(bytes32) returns (uint256) envfree
    live() returns (uint256) envfree
    rate(bytes32) returns (uint256) envfree
    sin(address) returns (uint256) envfree
    spot(bytes32) returns (uint256) envfree
    urns(bytes32, address) returns (uint256, uint256) envfree
    vice() returns (uint256) envfree
    wards(address) returns (uint256) envfree
}

// definition WAD() returns uint256 = 10^18;
definition RAY() returns uint256 = 10^27;

definition min_int256() returns mathint = -1 * 2^255;
// definition max_int256() returns mathint = 2^255 - 1;

// Verify fallback always reverts
// In this case is pretty important as we are filtering it out from some invariants/rules
rule fallback_revert(method f) filtered { f -> f.isFallback } {
    env e;

    calldataarg arg;
    f@withrevert(e, arg);

    assert(lastReverted, "Fallback did not revert");
}

// Verify that wards behaves correctly on rely
rule rely(address usr) {
    env e;

    address other;
    require(other != usr);
    uint256 wardOtherBefore = wards(other);

    rely(e, usr);

    uint256 wardAfter = wards(usr);
    uint256 wardOtherAfter = wards(other);

    assert(wardAfter == 1, "rely did not set wards as expected");
    assert(wardOtherAfter == wardOtherBefore, "rely affected other wards which was not expected");
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    uint256 ward = wards(e.msg.sender);
    uint256 live = live();

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = live != 1;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");

    assert(lastReverted => revert1 || revert2 || revert3, "Revert rules are not covering all the cases");
}

// Verify that wards behaves correctly on deny
rule deny(address usr) {
    env e;

    address other;
    require(other != usr);
    uint256 wardOtherBefore = wards(other);

    deny(e, usr);

    uint256 wardAfter = wards(usr);
    uint256 wardOtherAfter = wards(other);

    assert(wardAfter == 0, "deny did not set wards as expected");
    assert(wardOtherAfter == wardOtherBefore, "deny affected other wards which was not expected");
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    uint256 ward = wards(e.msg.sender);
    uint256 live = live();

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = live != 1;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");

    assert(lastReverted => revert1 || revert2 || revert3, "Revert rules are not covering all the cases");
}

// Verify that rate behaves correctly on init
rule init(bytes32 ilk) {
    env e;

    uint256 ArtBefore; uint256 rateBefore; uint256 spotBefore; uint256 lineBefore; uint256 dustBefore;
    ArtBefore, rateBefore, spotBefore, lineBefore, dustBefore = ilks(ilk);

    init(e, ilk);

    uint256 ArtAfter; uint256 rateAfter; uint256 spotAfter; uint256 lineAfter; uint256 dustAfter;
    ArtAfter, rateAfter, spotAfter, lineAfter, dustAfter = ilks(ilk);

    assert(rateAfter == RAY(), "init did not set rate as expected");
    assert(ArtAfter == ArtBefore, "init did not keep Art as expected");
    assert(spotAfter == spotBefore, "init did not keep spot as expected");
    assert(lineAfter == lineBefore, "init did not keep line as expected");
    assert(dustAfter == dustBefore, "init did not keep dust as expected");
}

// Verify revert rules on init
rule init_revert(bytes32 ilk) {
    env e;

    uint256 Art; uint256 rate; uint256 spot; uint256 line; uint256 dust;
    Art, rate, spot, line, dust = ilks(ilk);

    uint256 ward = wards(e.msg.sender);

    init@withrevert(e, ilk);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = rate != 0;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");

    assert(lastReverted => revert1 || revert2 || revert3, "Revert rules are not covering all the cases");
}

// Verify that Line behaves correctly on file
rule file(bytes32 what, uint256 data) {
    env e;

    file(e, what, data);

    assert(Line() == data, "file did not set Line as expected");
}

// Verify revert rules on file
rule file_revert(bytes32 what, uint256 data) {
    env e;

    uint256 ward = wards(e.msg.sender);
    uint256 live = live();

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = live != 1;
    bool revert4 = what != 0x4c696e6500000000000000000000000000000000000000000000000000000000; // what is not "Line"

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4, "Revert rules are not covering all the cases");
}

// Verify that spot/line/dust behave correctly on file
rule file_ilk(bytes32 ilk, bytes32 what, uint256 data) {
    env e;

    uint256 ArtBefore; uint256 rateBefore; uint256 spotBefore; uint256 lineBefore; uint256 dustBefore;
    ArtBefore, rateBefore, spotBefore, lineBefore, dustBefore = ilks(ilk);

    file(e, ilk, what, data);

    uint256 ArtAfter; uint256 rateAfter; uint256 spotAfter; uint256 lineAfter; uint256 dustAfter;
    ArtAfter, rateAfter, spotAfter, lineAfter, dustAfter = ilks(ilk);

    assert(what == 0x73706f7400000000000000000000000000000000000000000000000000000000 => spotAfter == data, "file did not set spot as expected");
    assert(what != 0x73706f7400000000000000000000000000000000000000000000000000000000 => spotAfter == spotBefore, "file did not keep spot as expected");
    assert(what == 0x6c696e6500000000000000000000000000000000000000000000000000000000 => lineAfter == data, "file did not set line as expected");
    assert(what != 0x6c696e6500000000000000000000000000000000000000000000000000000000 => lineAfter == lineBefore, "file did not keep spot as expected");
    assert(what == 0x6475737400000000000000000000000000000000000000000000000000000000 => dustAfter == data, "file did not set dust as expected");
    assert(what != 0x6475737400000000000000000000000000000000000000000000000000000000 => dustAfter == dustBefore, "file did not keep dust as expected");
    assert(ArtAfter == ArtBefore, "file did not keep Art as expected");
    assert(rateAfter == rateBefore, "file did not keep rate as expected");
}

// Verify revert rules on file
rule file_ilk_revert(bytes32 ilk, bytes32 what, uint256 data) {
    env e;

    uint256 ward = wards(e.msg.sender);
    uint256 live = live();

    file@withrevert(e, ilk, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = live != 1;
    bool revert4 = what != 0x73706f7400000000000000000000000000000000000000000000000000000000 &&
                   what != 0x6c696e6500000000000000000000000000000000000000000000000000000000 &&
                   what != 0x6475737400000000000000000000000000000000000000000000000000000000;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4, "Revert rules are not covering all the cases");
}

// Verify that live behaves correctly on cage
rule cage() {
    env e;

    cage(e);

    assert(live() == 0, "cage did not set live to 0");
}

// Verify revert rules on file
rule cage_revert() {
    env e;

    uint256 ward = wards(e.msg.sender);

    cage@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");

    assert(lastReverted => revert1 || revert2, "Revert rules are not covering all the cases");
}

rule ilk_getters() {
    bytes32 ilk;
    uint256 Art; uint256 rate; uint256 spot; uint256 line; uint256 dust;
    Art, rate, spot, line, dust = ilks(ilk);

    assert(Art == Art(ilk), "Art getter did not return ilk.Art");
    assert(rate == rate(ilk), "rate getter did not return ilk.rate");
    assert(spot == spot(ilk), "spot getter did not return ilk.spot");
    assert(line == line(ilk), "line getter did not return ilk.line");
    assert(dust == dust(ilk), "dust getter did not return ilk.dust");
}

rule urn_getters() {
    bytes32 ilk; address urn;
    uint256 ink; uint256 art;
    ink, art = urns(ilk, urn);

    assert(ink == ink(ilk, urn), "ink getter did not return urns.ink");
    assert(art == art(ilk, urn), "art getter did not return urns.art");
}

// Verify that can behaves correctly on hope
rule hope(address usr) {
    env e;

    address otherFrom;
    address otherTo;
    require(otherFrom != e.msg.sender || otherTo != usr);
    uint256 canOtherBefore = can(otherFrom, otherTo);

    hope(e, usr);

    uint256 canAfter = can(e.msg.sender, usr);
    uint256 canOtherAfter = can(otherFrom, otherTo);

    assert(canAfter == 1, "hope did not set can as expected");
    assert(canOtherAfter == canOtherBefore, "hope affected other can which was not expected");
}

// Verify revert rules on hope
rule hope_revert(address usr) {
    env e;

    hope@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;

    assert(revert1 => lastReverted, "revert1 failed");

    assert(lastReverted => revert1, "Revert rules are not covering all the cases");
}

// Verify that can behaves correctly on nope
rule nope(address usr) {
    env e;

    address otherFrom;
    address otherTo;
    require(otherFrom != e.msg.sender || otherTo != usr);
    uint256 canOtherBefore = can(otherFrom, otherTo);

    nope(e, usr);

    uint256 canAfter = can(e.msg.sender, usr);
    uint256 canOtherAfter = can(otherFrom, otherTo);

    assert(canAfter == 0, "nope did not set can as expected");
    assert(canOtherAfter == canOtherBefore, "nope affected other can which was not expected");
}

// Verify revert rules on nope
rule nope_revert(address usr) {
    env e;

    nope@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;

    assert(revert1 => lastReverted, "revert1 failed");

    assert(lastReverted => revert1, "Revert rules are not covering all the cases");
}

// Verify that gem behaves correctly on slip
rule slip(bytes32 ilk, address usr, int256 wad) {
    env e;

    bytes32 otherIlk;
    address otherUsr;
    require(otherIlk != ilk || otherUsr != usr);
    uint256 gemBefore = gem(ilk, usr);
    uint256 gemOtherBefore = gem(otherIlk, otherUsr);

    slip(e, ilk, usr, wad);

    uint256 gemAfter = gem(ilk, usr);
    uint256 gemOtherAfter = gem(otherIlk, otherUsr);

    assert(to_mathint(gemAfter) == to_mathint(gemBefore) + to_mathint(wad), "slip did not set gem as expected");
    assert(gemOtherAfter == gemOtherBefore, "slip affected other gem which was not expected");
}

// Verify revert rules on slip
rule slip_revert(bytes32 ilk, address usr, int256 wad) {
    env e;

    uint256 ward = wards(e.msg.sender);
    uint256 gem = gem(ilk, usr);

    slip@withrevert(e, ilk, usr, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = to_mathint(wad) == min_int256();
    bool revert4 = wad > 0 && to_mathint(gem) + to_mathint(wad) > max_uint256;
    bool revert5 = wad < 0 && to_mathint(gem) < to_mathint(wad);

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");
    assert(revert5 => lastReverted, "revert5 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5, "Revert rules are not covering all the cases");
}

// Verify that gems behave correctly on flux
rule flux(bytes32 ilk, address src, address dst, uint256 wad) {
    env e;

    bytes32 otherIlk;
    address otherUsr;
    require(otherIlk != ilk || (otherUsr != src && otherUsr != dst));
    uint256 gemSrcBefore = gem(ilk, src);
    uint256 gemDstBefore = gem(ilk, dst);
    uint256 gemOtherBefore = gem(otherIlk, otherUsr);

    flux(e, ilk, src, dst, wad);

    uint256 gemSrcAfter = gem(ilk, src);
    uint256 gemDstAfter = gem(ilk, dst);
    uint256 gemOtherAfter = gem(otherIlk, otherUsr);

    assert(src != dst => gemSrcAfter == gemSrcBefore - wad, "flux did not set src gem as expected");
    assert(src != dst => gemDstAfter == gemDstBefore + wad, "flux did not set dst gem as expected");
    assert(src == dst => gemSrcAfter == gemDstBefore, "flux did not keep gem as expected");
    assert(gemOtherAfter == gemOtherBefore, "flux affected other gem which was not expected");
}

// Verify revert rules on flux
rule flux_revert(bytes32 ilk, address src, address dst, uint256 wad) {
    env e;

    bool wish = src == e.msg.sender || can(src, e.msg.sender) == 1;
    uint256 gemSrc = gem(ilk, src);
    uint256 gemDst = gem(ilk, dst);

    flux@withrevert(e, ilk, src, dst, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !wish;
    bool revert3 = gemSrc < wad;
    bool revert4 = src != dst && gemDst + wad > max_uint256;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4, "Revert rules are not covering all the cases");
}

// Verify that dais behave correctly on move
rule move(address src, address dst, uint256 rad) {
    env e;

    address otherUsr;
    require(otherUsr != src && otherUsr != dst);
    uint256 daiSrcBefore = dai(src);
    uint256 daiDstBefore = dai(dst);
    uint256 daiOtherBefore = dai(otherUsr);

    move(e, src, dst, rad);

    uint256 daiSrcAfter = dai(src);
    uint256 daiDstAfter = dai(dst);
    uint256 daiOtherAfter = dai(otherUsr);

    assert(src != dst => daiSrcAfter == daiSrcBefore - rad, "move did not set src dai as expected");
    assert(src != dst => daiDstAfter == daiDstBefore + rad, "move did not set dst dai as expected");
    assert(src == dst => daiSrcAfter == daiDstBefore, "move did not keep dai as expected");
    assert(daiOtherAfter == daiOtherBefore, "move affected other dai which was not expected");
}

// Verify revert rules on move
rule move_revert(address src, address dst, uint256 rad) {
    env e;

    bool wish = src == e.msg.sender || can(src, e.msg.sender) == 1;
    uint256 daiSrc = dai(src);
    uint256 daiDst = dai(dst);

    move@withrevert(e, src, dst, rad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !wish;
    bool revert3 = daiSrc < rad;
    bool revert4 = src != dst && daiDst + rad > max_uint256;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4, "Revert rules are not covering all the cases");
}

// TODO: frob

// TODO: fork

// TODO: grab

// Verify that variables behave correctly on heal
rule heal(uint256 rad) {
    env e;

    address otherUsr;
    require(otherUsr != e.msg.sender);
    uint256 daiSenderBefore = dai(e.msg.sender);
    uint256 sinSenderBefore = sin(e.msg.sender);
    uint256 viceBefore = vice();
    uint256 debtBefore = debt();
    uint256 daiOtherBefore = dai(otherUsr);
    uint256 sinOtherBefore = sin(otherUsr);

    heal(e, rad);

    uint256 daiSenderAfter = dai(e.msg.sender);
    uint256 sinSenderAfter = sin(e.msg.sender);
    uint256 viceAfter = vice();
    uint256 debtAfter = debt();
    uint256 daiOtherAfter = dai(otherUsr);
    uint256 sinOtherAfter = sin(otherUsr);

    assert(daiSenderAfter == daiSenderBefore - rad, "heal did not set sender dai as expected");
    assert(sinSenderAfter == sinSenderBefore - rad, "heal did not set sender sin as expected");
    assert(viceAfter == viceBefore - rad, "heal did not set vice as expected");
    assert(debtAfter == debtBefore - rad, "heal did not set debt as expected");
    assert(daiOtherAfter == daiOtherBefore, "heal did not keep other dai as expected");
    assert(sinOtherAfter == sinOtherBefore, "heal did not keep other sin as expected");
}

// Verify revert rules on heal
rule heal_revert(uint256 rad) {
    env e;

    uint256 dai = dai(e.msg.sender);
    uint256 sin = sin(e.msg.sender);
    uint256 vice = vice();
    uint256 debt = debt();

    heal@withrevert(e, rad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = dai < rad;
    bool revert3 = sin < rad;
    bool revert4 = vice < rad;
    bool revert5 = debt < rad;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");
    assert(revert5 => lastReverted, "revert5 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5, "Revert rules are not covering all the cases");
}

// Verify that variables behave correctly on suck
rule suck(address u, address v, uint256 rad) {
    env e;

    address otherUsrU;
    address otherUsrV;
    require(otherUsrU != u && otherUsrV != v);
    uint256 sinUBefore = sin(u);
    uint256 daiVBefore = dai(v);
    uint256 viceBefore = vice();
    uint256 debtBefore = debt();
    uint256 sinOtherBefore = sin(otherUsrU);
    uint256 daiOtherBefore = dai(otherUsrV);

    suck(e, u, v, rad);

    uint256 sinUAfter = sin(u);
    uint256 daiVAfter = dai(v);
    uint256 viceAfter = vice();
    uint256 debtAfter = debt();
    uint256 sinOtherAfter = sin(otherUsrU);
    uint256 daiOtherAfter = dai(otherUsrV);

    assert(sinUAfter == sinUBefore + rad, "suck did not set u sin as expected");
    assert(daiVAfter == daiVBefore + rad, "suck did not set v dai as expected");
    assert(viceAfter == viceBefore + rad, "suck did not set vice as expected");
    assert(debtAfter == debtBefore + rad, "suck did not set debt as expected");
    assert(sinOtherAfter == sinOtherBefore, "suck did not keep other sin as expected");
    assert(daiOtherAfter == daiOtherBefore, "suck did not keep other dai as expected");
}

// Verify revert rules on suck
rule suck_revert(address u, address v, uint256 rad) {
    env e;

    uint256 ward = wards(e.msg.sender);
    uint256 sin = sin(u);
    uint256 dai = dai(v);
    uint256 vice = vice();
    uint256 debt = debt();

    suck@withrevert(e, u, v, rad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = sin + rad > max_uint256;
    bool revert4 = dai + rad > max_uint256;
    bool revert5 = vice + rad > max_uint256;
    bool revert6 = debt + rad > max_uint256;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");
    assert(revert5 => lastReverted, "revert5 failed");
    assert(revert6 => lastReverted, "revert6 failed");


    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5 || revert6, "Revert rules are not covering all the cases");
}

// TODO: fold
