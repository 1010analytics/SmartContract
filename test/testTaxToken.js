const TaxToken = artifacts.require("TaxToken");
const PrizeVault = artifacts.require("PrizeVault");
const { time } = require("@openzeppelin/test-helpers");
const assert = require("chai").assert;

contract("TaxToken", (accounts) => {
  let taxToken;
  const admin = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const devWallet = "0xF418D4c3daf5a9A77c072DCe7c1a3f1996D55689";

  before(async () => {
    taxToken = await TaxToken.new(
      "0xD7f86b4b8Cae7D942340FF628F82735b7a20893a",
      "0x514910771AF9Ca656af840dff83E8264EcF986CA",
      "0x8077d1f46A080aF3e4de8300645549ed57236444",
      web3.utils.toWei("2", "ether"),
      devWallet
    );
  });

  describe("Token purchase and tax handling", () => {
    it("should revert when trying to buy tokens with zero value", async () => {
      try {
        await taxToken.buyTokens({ from: user1, value: 0 });
        assert.fail("Expected transaction to revert.");
      } catch (error) {
        assert.include(
          error.message,
          "Minimum token purchase price not met",
          "Expected revert error for zero value purchase."
        );
      }
    });

    it("should revert when trying to sell zero tokens", async () => {
      try {
        await taxToken.sellTokens(0, { from: user1 });
        assert.fail("Transaction should have reverted.");
      } catch (error) {
        assert.include(
          error.message,
          "Cannot sell zero tokens",
          "Expected revert error for selling zero tokens."
        );
      }
    });

    it("should revert when trying to sell more tokens than owned", async () => {
      const invalidAmount = web3.utils.toWei("100", "ether");
      try {
        await taxToken.sellTokens(invalidAmount, { from: user1 });
        assert.fail("Transaction should have reverted.");
      } catch (error) {
        assert.include(
          error.message,
          "Insufficient balance to sell tokens",
          "Expected revert error for selling more tokens than owned."
        );
      }
    });
  });

  describe("Emergency Withdraw Functionality", () => {
    it("should revert emergencyWithdraw if called by non-owner", async () => {
      const withdrawalAmount = web3.utils.toWei("0.5", "ether");
      const prizeVaultAddress = await taxToken.prizeVault();
      const prizeVault = await PrizeVault.at(prizeVaultAddress);

      try {
        await prizeVault.emergencyWithdraw(user2, withdrawalAmount, {
          from: user1,
        });
        assert.fail(
          "Expected revert due to non-owner calling emergencyWithdraw"
        );
      } catch (error) {
        assert.include(
          error.message,
          "Not authorized",
          "Only owner can call emergencyWithdraw"
        );
      }
    });
  });

  describe("PrizeVault Functionality", () => {
    it("should only allow the TaxToken contract to call releasePrize", async () => {
      const prizeAmount = web3.utils.toWei("1", "ether");
      const prizeVaultAddress = await taxToken.prizeVault();
      const prizeVault = await PrizeVault.at(prizeVaultAddress);

      try {
        await prizeVault.releasePrize(user1, prizeAmount, { from: user1 });
        assert.fail("Expected revert due to non-owner calling releasePrize");
      } catch (error) {
        assert.include(
          error.message,
          "Not authorized",
          "Only the TaxToken contract should be able to call releasePrize"
        );
      }
    });
  });
});
