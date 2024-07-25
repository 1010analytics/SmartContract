const TaxToken = artifacts.require("TaxToken");
const { time } = require("@openzeppelin/test-helpers");
const assert = require("chai").assert;

contract("TaxToken", (accounts) => {
  let taxToken;
  const admin = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const devWallet = "0xF418D4c3daf5a9A77c072DCe7c1a3f1996D55689";
  const prizeWallet = "0x7fBF5506546b299f6D85C9360E4F103b6C97E5C2";

  before(async () => {
    taxToken = await TaxToken.new(
      "0xD7f86b4b8Cae7D942340FF628F82735b7a20893a",
      "0x514910771AF9Ca656af840dff83E8264EcF986CA",
      "0x8077d1f46A080aF3e4de8300645549ed57236444",
      web3.utils.toWei("2", "ether"),
      devWallet,
      prizeWallet
    );
  });

  describe("Token purchase and tax handling", () => {
    it("should allow users to buy tokens and deduct the correct tax and dev fee", async () => {
      const purchaseValue = web3.utils.toWei("1", "ether");
      await taxToken.buyTokens({ from: user1, value: purchaseValue });
      const userBalance = await taxToken.tokenBalances(user1);
      const expectedTokens = purchaseValue - (purchaseValue * 20) / 100;

      assert.closeTo(
        parseFloat(web3.utils.fromWei(userBalance.toString(), "ether")),
        parseFloat(web3.utils.fromWei(expectedTokens.toString(), "ether")),
        0.01,
        "User should have correct amount of tokens after taxes"
      );
    });

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

  describe("Automated Tax Distribution", () => {
    it("should automatically distribute tax when upkeep is needed", async () => {
      const purchaseAmount = web3.utils.toWei("5", "ether");
      await taxToken.buyTokens({ from: user1, value: purchaseAmount });

      await time.increase(time.duration.weeks(1) + time.duration.seconds(1));

      const performData = web3.utils.randomHex(0);
      const upkeepNeeded = await taxToken.checkUpkeep("0x");
      assert.isTrue(upkeepNeeded[0], "Upkeep should be needed");

      await taxToken.performUpkeep(performData);

      const taxDistributedEvent = await taxToken.getPastEvents(
        "TokensDistributed"
      );
      assert.isNotEmpty(
        taxDistributedEvent,
        "Tax distribution event should be emitted"
      );
      assert.isAbove(
        parseInt(taxDistributedEvent[0].returnValues.amount),
        0,
        "Distribution amount should be greater than zero"
      );
    });

    it("should test the random selection based on token holdings", async () => {});
  });
});
