const TaxToken = artifacts.require("TaxToken");
const { time } = require("@openzeppelin/test-helpers");
const assert = require("chai").assert;

contract("TaxToken", (accounts) => {
  let taxToken;
  const admin = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  before(async () => {
    taxToken = await TaxToken.new(
      "0xD7f86b4b8Cae7D942340FF628F82735b7a20893a",
      "0x514910771AF9Ca656af840dff83E8264EcF986CA",
      "0x8077d1f46A080aF3e4de8300645549ed57236444",
      web3.utils.toWei("2", "ether"),
      admin
    );
  });

  describe("Token purchase and tax handling", () => {
    it("should allow users to buy tokens and deduct the correct tax and dev fee", async () => {
      const purchaseValue = web3.utils.toWei("1", "ether");
      await taxToken.buyTokens({ from: user1, value: purchaseValue });
      const userBalance = await taxToken.tokenBalances(user1);
      const expectedTokens = purchaseValue * (1 - (19 + 1) / 100);

      assert.equal(
        web3.utils.fromWei(userBalance.toString(), "ether"),
        web3.utils.fromWei(expectedTokens.toString(), "ether"),
        "User should have correct amount of tokens after taxes"
      );
    });

    it("should revert when trying to buy tokens with zero value", async () => {
      try {
        await taxToken.buyTokens({ from: user1, value: 0 });
        assert.fail("The transaction should have reverted");
      } catch (error) {
        assert.include(
          error.message,
          "Cannot buy with zero value",
          "Expected revert error"
        );
      }
    });

    it("should revert when trying to sell zero tokens", async () => {
      try {
        await taxToken.sellTokens(0, { from: user1 });
        assert.fail("The transaction should have reverted");
      } catch (error) {
        assert.include(
          error.message,
          "Cannot sell zero tokens",
          "Expected revert error"
        );
      }
    });

    it("should revert when trying to sell more tokens than owned", async () => {
      const invalidAmount = web3.utils.toWei("100", "ether");
      try {
        await taxToken.sellTokens(invalidAmount, { from: user1 });
        assert.fail("The transaction should have reverted");
      } catch (error) {
        assert.include(
          error.message,
          "Insufficient balance to sell tokens",
          "Expected revert error"
        );
      }
    });
  });

  describe("Automated Tax Distribution", () => {
    it("should automatically distribute tax when upkeep is needed", async () => {
      await taxToken.buyTokens({
        from: user1,
        value: web3.utils.toWei("5", "ether"),
      });

      await time.increase(time.duration.weeks(1) + time.duration.seconds(1));

      const performData = web3.utils.randomHex(0);
      const upkeepNeeded = await taxToken.checkUpkeep("0x");
      assert.isTrue(upkeepNeeded[0], "Upkeep should be needed");

      await taxToken.performUpkeep(performData);

      const taxDistributedEvent = await taxToken.getPastEvents(
        "TokensDistributed"
      );
      assert.equal(
        taxDistributedEvent.length,
        1,
        "Tax distribution event should be emitted"
      );
      const distributionAmount = taxDistributedEvent[0].returnValues.amount;
      assert.isAbove(
        parseInt(distributionAmount),
        0,
        "Distribution amount should be greater than zero"
      );
    });

    it("should test the random selection based on token holdings", async () => {});
  });
});
