const allergenIds = new Set([
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
]);

const findingLevels = new Set(["info", "positive", "warning"]);
const imageTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

export function validateAssistantInput(data) {
  if (!data || typeof data !== "object") {
    throw new Error("Assistant request data is required.");
  }

  const imageBase64 = cleanBase64(data.imageBase64);
  const mimeType = cleanText(data.mimeType, 40).toLowerCase();
  const context = normalizeContext(data.context);
  if (!imageBase64 && !context) {
    throw new Error("Add a product image before asking the assistant.");
  }
  if (imageBase64 && !imageTypes.has(mimeType)) {
    throw new Error("Use a JPEG, PNG or WebP product image.");
  }

  return {
    imageBase64,
    mimeType,
    message: cleanText(data.message, 600) ||
      "Identify this food product and explain what the image can verify.",
    context,
    history: normalizeHistory(data.history),
  };
}

export function extractAssistantResult(response) {
  const text = response?.output_text ?? response?.output
    ?.flatMap((item) => item?.content ?? [])
    .find((content) => content?.type === "output_text")?.text;
  if (typeof text !== "string") return null;

  const parsed = JSON.parse(text);
  const product = parsed?.product && typeof parsed.product === "object" ?
    parsed.product : {};
  const completeLabel = product.hasCompleteIngredientLabel === true;
  const listed = stringArray(product.listedAllergenIds, 13)
    .filter((item) => allergenIds.has(item));
  const traces = stringArray(product.traceAllergenIds, 13)
    .filter((item) => allergenIds.has(item));

  return {
    reply: cleanText(parsed?.reply, 900),
    product: {
      name: cleanText(product.name, 140) || "Product not confirmed",
      brand: cleanText(product.brand, 120),
      barcode: cleanText(product.barcode, 32),
      ingredients: cleanText(product.ingredients, 5000),
      listedAllergenIds: listed,
      traceAllergenIds: traces,
      hasCompleteIngredientLabel: completeLabel,
      confidence: boundedNumber(product.confidence, 0, 1),
    },
    findings: (Array.isArray(parsed?.findings) ? parsed.findings : [])
      .slice(0, 8)
      .map((finding) => ({
        level: findingLevels.has(finding?.level) ? finding.level : "info",
        text: cleanText(finding?.text, 180),
      }))
      .filter((finding) => finding.text),
    needsAnotherImage: parsed?.needsAnotherImage === true,
    nextImagePrompt: cleanText(parsed?.nextImagePrompt, 180),
    suggestedQuestions: stringArray(parsed?.suggestedQuestions, 4)
      .map((item) => cleanText(item, 80))
      .filter(Boolean),
  };
}

function normalizeContext(value) {
  if (!value || typeof value !== "object") return null;
  const serialized = JSON.stringify(value);
  if (serialized.length > 16000) {
    throw new Error("The assistant conversation is too large. Start again.");
  }
  return JSON.parse(serialized);
}

function normalizeHistory(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(-8).map((item) => ({
    role: item?.role === "assistant" ? "assistant" : "user",
    text: cleanText(item?.text, 600),
  })).filter((item) => item.text);
}

function cleanBase64(value) {
  if (typeof value !== "string") return "";
  const cleaned = value.replace(/\s/g, "");
  if (!cleaned) return "";
  if (cleaned.length > 8000000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(cleaned)) {
    throw new Error("The product image is too large or invalid.");
  }
  return cleaned;
}

function stringArray(value, limit) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, limit).map((item) => cleanText(item, 120))
    .filter(Boolean);
}

function cleanText(value, maxLength) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function boundedNumber(value, minimum, maximum) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 0;
  return Math.min(maximum, Math.max(minimum, number));
}
