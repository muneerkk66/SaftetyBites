import {createHash} from "node:crypto";

import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  extractRankings,
  validateRankingInput,
} from "./ranker.js";
import {
  extractAssistantResult,
  validateAssistantInput,
} from "./assistant.js";

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

export const foodAssistant = onCall(
  {
    region: "europe-west2",
    secrets: [openAIKey],
    timeoutSeconds: 45,
    memory: "512MiB",
    maxInstances: 5,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to use the AI food assistant.",
      );
    }

    let input;
    try {
      input = validateAssistantInput(request.data);
    } catch (error) {
      throw new HttpsError("invalid-argument", error.message);
    }

    const content = [{
      type: "input_text",
      text: JSON.stringify({
        question: input.message,
        recentConversation: input.history,
        previousAnalysis: input.context,
      }),
    }];
    if (input.imageBase64) {
      content.push({
        type: "input_image",
        image_url: `data:${input.mimeType};base64,${input.imageBase64}`,
        detail: "high",
      });
    }

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
        max_output_tokens: 1200,
        safety_identifier: createHash("sha256")
          .update(request.auth.uid)
          .digest("hex")
          .slice(0, 32),
        instructions: [
          "You are SafeBiteAI's food information assistant.",
          "Use only visible image evidence and the supplied previous analysis.",
          "Never claim that food is safe, allergen-free, medically suitable, or safe for a child.",
          "Never infer ingredients or allergens from branding, appearance, or typical recipes.",
          "Treat the ingredient label as complete only when the full ingredients and may-contain wording are clearly readable.",
          "Separate listed allergens from may-contain or trace warnings.",
          "If evidence is missing, say what image is needed next.",
          "Keep the reply practical, calm, and under 90 words.",
        ].join(" "),
        input: [{role: "user", content}],
        text: {
          verbosity: "low",
          format: {
            type: "json_schema",
            name: "food_image_assistant",
            strict: true,
            schema: assistantSchema,
          },
        },
      }),
    });

    if (!response.ok) {
      throw new HttpsError(
        "unavailable",
        "The AI food assistant is temporarily unavailable.",
      );
    }
    try {
      const result = extractAssistantResult(await response.json());
      if (!result || !result.reply) throw new Error("Invalid response.");
      return result;
    } catch {
      throw new HttpsError(
        "unavailable",
        "The AI food assistant could not verify that image. Try a clearer photo.",
      );
    }
  },
);

const allergenEnum = [
  "peanuts",
  "tree_nuts",
  "milk",
  "eggs",
  "gluten",
  "soya",
  "sesame",
  "fish",
  "crustaceans",
  "molluscs",
  "mustard",
  "celery",
  "lupin",
  "sulphites",
];

const assistantSchema = {
  type: "object",
  properties: {
    reply: {type: "string"},
    product: {
      type: "object",
      properties: {
        name: {type: "string"},
        brand: {type: "string"},
        barcode: {type: "string"},
        ingredients: {type: "string"},
        listedAllergenIds: {
          type: "array",
          items: {type: "string", enum: allergenEnum},
        },
        traceAllergenIds: {
          type: "array",
          items: {type: "string", enum: allergenEnum},
        },
        hasCompleteIngredientLabel: {type: "boolean"},
        confidence: {type: "number", minimum: 0, maximum: 1},
      },
      required: [
        "name",
        "brand",
        "barcode",
        "ingredients",
        "listedAllergenIds",
        "traceAllergenIds",
        "hasCompleteIngredientLabel",
        "confidence",
      ],
      additionalProperties: false,
    },
    findings: {
      type: "array",
      items: {
        type: "object",
        properties: {
          level: {
            type: "string",
            enum: ["info", "positive", "warning"],
          },
          text: {type: "string"},
        },
        required: ["level", "text"],
        additionalProperties: false,
      },
    },
    needsAnotherImage: {type: "boolean"},
    nextImagePrompt: {type: "string"},
    suggestedQuestions: {
      type: "array",
      items: {type: "string"},
    },
  },
  required: [
    "reply",
    "product",
    "findings",
    "needsAnotherImage",
    "nextImagePrompt",
    "suggestedQuestions",
  ],
  additionalProperties: false,
};
