import assert from "node:assert/strict";
import test from "node:test";

import {
  extractAssistantResult,
  validateAssistantInput,
} from "../assistant.js";

test("requires an image or previous analysis", () => {
  assert.throws(
    () => validateAssistantInput({message: "What is this?"}),
    /Add a product image/,
  );
});

test("accepts a compact image request", () => {
  const input = validateAssistantInput({
    imageBase64: "YWJjZA==",
    mimeType: "image/jpeg",
    message: "Check this label",
  });

  assert.equal(input.message, "Check this label");
  assert.equal(input.mimeType, "image/jpeg");
});

test("normalizes assistant output without creating allergen ids", () => {
  const result = extractAssistantResult({
    output_text: JSON.stringify({
      reply: "The full ingredients list is visible.",
      product: {
        name: "Example bar",
        brand: "Example",
        barcode: "12345678",
        ingredients: "Oats, milk",
        listedAllergenIds: ["milk", "invented"],
        traceAllergenIds: ["peanuts"],
        hasCompleteIngredientLabel: true,
        confidence: 1.4,
      },
      findings: [{level: "warning", text: "Milk is listed."}],
      needsAnotherImage: false,
      nextImagePrompt: "",
      suggestedQuestions: ["Explain the ingredients"],
    }),
  });

  assert.deepEqual(result.product.listedAllergenIds, ["milk"]);
  assert.equal(result.product.confidence, 1);
  assert.equal(result.findings[0].level, "warning");
});
