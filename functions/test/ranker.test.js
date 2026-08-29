import assert from "node:assert/strict";
import test from "node:test";

import {
  extractRankings,
  fallbackRankings,
  validateRankingInput,
} from "../ranker.js";

const source = {
  barcode: "11111111",
  name: "Milk chocolate",
  brand: "Example",
  categories: ["en:chocolates"],
  allergens: ["milk"],
  traces: [],
};

test("normalizes valid product candidates", () => {
  const result = validateRankingInput({
    source,
    candidates: [
      {...source, barcode: "22222222", name: "Another", allergens: []},
      {...source, barcode: "", name: "Missing barcode", traces: []},
    ],
  });

  assert.deepEqual(result.candidates.map((item) => item.barcode), ["22222222"]);
});

test("accepts only known unique barcodes from model output", () => {
  const candidates = validateRankingInput({
    source,
    candidates: [
      {...source, barcode: "22222222", name: "First", allergens: []},
      {...source, barcode: "33333333", name: "Second", allergens: []},
    ],
  }).candidates;
  const rankings = extractRankings(
    {
      output_text: JSON.stringify({
        rankings: [
          {barcode: "33333333", reason: "Closest category match."},
          {barcode: "99999999", reason: "Invented."},
          {barcode: "33333333", reason: "Duplicate."},
        ],
      }),
    },
    candidates,
  );

  assert.deepEqual(rankings, [
    {barcode: "33333333", reason: "Closest category match."},
  ]);
});

test("fallback returns every candidate", () => {
  const candidates = validateRankingInput({
    source,
    candidates: [
      {...source, barcode: "22222222", name: "First", allergens: []},
      {...source, barcode: "33333333", name: "Second", allergens: []},
    ],
  }).candidates;

  assert.equal(fallbackRankings(candidates).length, 2);
});
