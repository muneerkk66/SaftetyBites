import assert from "node:assert/strict";
import test from "node:test";

import {normalizeFsaAlert, notificationTopics} from "../recall_parser.js";

test("normalizes an FSA Allergy Alert", () => {
  const alert = normalizeFsaAlert({
    notation: "FSA-AA-40-2026",
    title: "Business recalls crisps because of undeclared allergens",
    description: "Sold in Home Bargains stores.",
    created: "2026-07-31",
    modified: "2026-07-31T16:30:41.554Z",
    type: ["http://data.food.gov.uk/food-alerts/def/AA"],
    reportingBusiness: {commonName: "Example Foods"},
    alertURL: "https://alerts.food.gov.uk/example",
    problem: [{
      allergen: [
        {notation: "milk"},
        {notation: "wheat"},
      ],
    }],
    productDetails: [{
      productName: "Sour Cream Crisps",
      packSizeDescription: "125g",
      batchDescription: [{bestBeforeDescription: "31 October 2026"}],
    }],
    status: {label: "Published"},
  });

  assert.equal(alert.id, "FSA-AA-40-2026");
  assert.equal(alert.alertType, "AA");
  assert.deepEqual(alert.allergenIds, ["milk", "gluten"]);
  assert.equal(alert.products[0].batchDetails, "31 October 2026");
  assert.deepEqual(notificationTopics(alert), []);
});

test("targets a retailer topic for a product recall", () => {
  const alert = normalizeFsaAlert({
    notation: "FSA-PRIN-41-2026",
    title: "Tesco recalls a salad",
    created: "2026-08-25",
    modified: "2026-08-25T17:30:42.667Z",
    type: ["http://data.food.gov.uk/food-alerts/def/PRIN"],
    reportingBusiness: {commonName: "Tesco"},
    problem: [{
      productDetails: [{productName: "Tesco salad"}],
    }],
    status: {label: "Published"},
  });

  assert.deepEqual(alert.retailerIds, ["tesco"]);
  assert.deepEqual(notificationTopics(alert), ["retailer_tesco"]);
});

test("does not notify when a recall has no selected retailer topic", () => {
  const alert = normalizeFsaAlert({
    notation: "FSA-PRIN-1-2026",
    title: "Manufacturer recalls a product",
    created: "2026-01-01",
    modified: "2026-01-01",
    type: ["http://data.food.gov.uk/food-alerts/def/PRIN"],
    status: {label: "Published"},
  });

  assert.deepEqual(notificationTopics(alert), []);
});
