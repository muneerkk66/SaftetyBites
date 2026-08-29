import {createHash} from "node:crypto";

import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  extractRankings,
  validateRankingInput,
} from "./ranker.js";

const openAIKey = defineSecret("OPENAI_API_KEY");
const openAIModel = defineString("OPENAI_MODEL", {default: "gpt-5.6-luna"});

export const rankAlternatives = onCall(
  {
    region: "europe-west2",
    secrets: [openAIKey],
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to use AI-ranked alternatives.",
      );
    }

    let input;
    try {
      input = validateRankingInput(request.data);
    } catch (error) {
      throw new HttpsError("invalid-argument", error.message);
    }
    if (input.candidates.length === 0) {
      return {rankings: []};
    }

    const candidateBarcodes = input.candidates.map((item) => item.barcode);
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAIKey.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: openAIModel.value(),
        store: false,
        reasoning: {effort: "low"},
        max_output_tokens: 500,
        safety_identifier: createHash("sha256")
          .update(request.auth.uid)
          .digest("hex")
          .slice(0, 32),
        instructions: [
          "Rank already-filtered food alternatives for similarity and usefulness.",
          "Never claim that any product is safe, allergen-free, or medically suitable.",
          "Do not change, add, or remove products.",
          "Return every supplied barcode once. Keep each reason under 18 words.",
        ].join(" "),
        input: JSON.stringify(input),
        text: {
          verbosity: "low",
          format: {
            type: "json_schema",
            name: "alternative_product_ranking",
            strict: true,
            schema: {
              type: "object",
              properties: {
                rankings: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      barcode: {type: "string", enum: candidateBarcodes},
                      reason: {type: "string"},
                    },
                    required: ["barcode", "reason"],
                    additionalProperties: false,
                  },
                },
              },
              required: ["rankings"],
              additionalProperties: false,
            },
          },
        },
      }),
    });

    if (!response.ok) {
      throw new HttpsError(
        "unavailable",
        "AI ranking is temporarily unavailable.",
      );
    }
    try {
      const rankings = extractRankings(await response.json(), input.candidates);
      if (rankings.length === 0) throw new Error("No valid rankings returned.");
      return {rankings};
    } catch {
      throw new HttpsError(
        "unavailable",
        "AI ranking is temporarily unavailable.",
      );
    }
  },
);
