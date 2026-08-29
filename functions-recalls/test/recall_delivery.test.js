import assert from "node:assert/strict";
import test from "node:test";

import {
  buildRecallMessage,
  chunks,
  isInvalidMessagingToken,
  normalizeInstallation,
} from "../recall_delivery.js";

test("normalizes a recall installation registration", () => {
  const result = normalizeInstallation({
    installationId: "ABCDEF0123456789ABCDEF0123456789",
    token: "a-valid-firebase-registration-token",
    platform: "ios",
    retailerIds: ["tesco", "asda", "tesco", "unknown"],
  });

  assert.deepEqual(result, {
    installationId: "abcdef0123456789abcdef0123456789",
    token: "a-valid-firebase-registration-token",
    platform: "ios",
    retailerIds: ["asda", "tesco"],
  });
});

test("rejects invalid installation registrations", () => {
  assert.throws(() => normalizeInstallation({
    installationId: "short",
    token: "a-valid-firebase-registration-token",
    retailerIds: ["tesco"],
  }));
  assert.throws(() => normalizeInstallation({
    installationId: "abcdef0123456789abcdef0123456789",
    token: "short",
    retailerIds: ["tesco"],
  }));
});

test("builds a direct recall notification with unread metadata", () => {
  const message = buildRecallMessage(["token-one", "token-two"], {
    id: "FSA-PRIN-1-2026",
    alertType: "PRIN",
    shortTitle: "Tesco recalls a product",
    consumerAdvice: "Do not eat this product.",
    summary: "Recall summary",
    sourceUrl: "https://alerts.food.gov.uk/example",
  });

  assert.deepEqual(message.tokens, ["token-one", "token-two"]);
  assert.equal(message.data.alertId, "FSA-PRIN-1-2026");
  assert.equal(message.data.route, "alerts");
  assert.equal(message.apns.payload.aps.badge, 1);
});

test("identifies expired Firebase messaging tokens", () => {
  assert.equal(isInvalidMessagingToken({
    code: "messaging/registration-token-not-registered",
  }), true);
  assert.equal(isInvalidMessagingToken({code: "messaging/internal-error"}), false);
});

test("splits delivery targets into Firebase-sized batches", () => {
  assert.deepEqual(chunks([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
});
