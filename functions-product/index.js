import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const fatSecretClientId = defineSecret("FATSECRET_CLIENT_ID");
const fatSecretClientSecret = defineSecret("FATSECRET_CLIENT_SECRET");

initializeApp();

let fatSecretToken;
let fatSecretTokenExpiresAt = 0;

export const lookupFallbackProduct = onCall(
  {
    region: "europe-west2",
    secrets: [fatSecretClientId, fatSecretClientSecret],
    timeoutSeconds: 25,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to use the extended product lookup.",
      );
    }
    const barcode = normalizeBarcode(request.data?.barcode);
    const verifiedProduct = await getVerifiedProduct(barcode);
    if (verifiedProduct) return {product: verifiedProduct};

    const token = await getFatSecretToken();
    const url = new URL(
      "https://platform.fatsecret.com/rest/food/barcode/find-by-id/v2",
    );
    url.searchParams.set("barcode", barcode.padStart(13, "0"));
    url.searchParams.set("region", "GB");
    url.searchParams.set("language", "en");
    url.searchParams.set("format", "json");
    url.searchParams.set("include_food_attributes", "true");
    url.searchParams.set("include_food_images", "true");
    url.searchParams.set("include_sub_categories", "true");

    const response = await fetch(url, {
      headers: {"Authorization": `Bearer ${token}`},
    });
    const body = await readJson(response);
    if (response.status === 404 || hasFatSecretError(body, 211)) {
      throw new HttpsError("not-found", "Product not found.");
    }
    if (hasFatSecretError(body, 14)) {
      throw new HttpsError(
        "failed-precondition",
        "FatSecret Barcode access is not enabled for this account.",
      );
    }
    if (hasFatSecretError(body, 21)) {
      throw new HttpsError(
        "failed-precondition",
        "FatSecret has not allowed this backend IP address.",
      );
    }
    if (!response.ok) {
      throw new HttpsError(
        "unavailable",
        "The extended product lookup is unavailable.",
      );
    }
    const food = body?.food ?? body;
    const product = normalizeFatSecretProduct(food, barcode);
    if (!product.name) {
      throw new HttpsError("not-found", "Product not found.");
    }
    return {product};
  },
);

export const reportMissingProduct = onCall(
  {
    region: "europe-west2",
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to report a product.");
    }
    const barcode = normalizeBarcode(request.data?.barcode);
    const reason = normalizeMissingReason(request.data?.reason);
    const database = getFirestore();
    const reference = database.collection("missing_products").doc(barcode);
    await database.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const values = {
        barcode,
        status: "pending_review",
        lastReason: reason,
        lastSeenAt: FieldValue.serverTimestamp(),
        scanCount: FieldValue.increment(1),
      };
      if (!snapshot.exists) {
        values.firstSeenAt = FieldValue.serverTimestamp();
      }
      transaction.set(reference, values, {merge: true});
    });
    return {recorded: true};
  },
);

function normalizeBarcode(value) {
  const barcode = typeof value === "string" ? value.replace(/\D/g, "") : "";
  if (barcode.length < 8 || barcode.length > 14) {
    throw new HttpsError("invalid-argument", "A valid barcode is required.");
  }
  return barcode;
}

function normalizeMissingReason(value) {
  const allowed = new Set([
    "notFound",
    "paidProviderUnavailable",
    "incompleteIngredients",
  ]);
  return allowed.has(value) ? value : "notFound";
}

async function getVerifiedProduct(barcode) {
  const snapshot = await getFirestore()
    .collection("verified_products")
    .doc(barcode)
    .get();
  if (!snapshot.exists || snapshot.data()?.active === false) return null;
  const data = snapshot.data();
  const ingredients = cleanText(data?.ingredients, 3000);
  const name = cleanText(data?.name, 160);
  if (!name || !ingredients) return null;
  return {
    barcode,
    name,
    brand: cleanText(data?.brand, 120) || "Brand not listed",
    ingredients,
    allergenIds: stringList(data?.allergenIds),
    traceAllergenIds: stringList(data?.traceAllergenIds),
    imageUrl: cleanText(data?.imageUrl, 500) || null,
    dataSource: "SafeBite verified",
    categoryIds: stringList(data?.categoryIds),
    completeness: 1,
    popularity: 0,
    allergenDataComplete: true,
  };
}

function stringList(value) {
  return Array.isArray(value) ? value.map(String).filter(Boolean) : [];
}

async function getFatSecretToken() {
  if (fatSecretToken && Date.now() < fatSecretTokenExpiresAt) {
    return fatSecretToken;
  }
  const credentials = Buffer.from(
    `${fatSecretClientId.value()}:${fatSecretClientSecret.value()}`,
  ).toString("base64");
  const response = await fetch("https://oauth.fatsecret.com/connect/token", {
    method: "POST",
    headers: {
      "Authorization": `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      scope: "premier barcode localization",
    }),
  });
  const body = await readJson(response);
  if (!response.ok || !body?.access_token) {
    if (body?.error === "invalid_scope") {
      throw new HttpsError(
        "failed-precondition",
        "FatSecret Barcode and UK Localization access are not enabled for this account.",
      );
    }
    throw new HttpsError(
      "failed-precondition",
      "The extended product provider is not configured.",
    );
  }
  fatSecretToken = body.access_token;
  const lifetimeSeconds = Number(body.expires_in) || 3600;
  fatSecretTokenExpiresAt = Date.now() +
    Math.max(60, lifetimeSeconds - 300) * 1000;
  return fatSecretToken;
}

function normalizeFatSecretProduct(food, barcode) {
  const allergens = listValue(food?.food_attributes?.allergens?.allergen);
  const allergenMap = {
    Peanuts: "peanuts",
    Nuts: "tree_nuts",
    Milk: "milk",
    Lactose: "milk",
    Egg: "eggs",
    Gluten: "gluten",
    Soy: "soya",
    Sesame: "sesame",
    Fish: "fish",
    Shellfish: "shellfish",
  };
  const allergenIds = [...new Set(allergens
    .filter((item) => String(item?.value) === "1")
    .map((item) => allergenMap[item?.name])
    .filter(Boolean))];
  const categories = listValue(
    food?.food_sub_categories?.food_sub_category,
  ).map((item) => `fatsecret:${String(item).trim().toLowerCase()}`);
  const images = listValue(food?.food_images?.food_image);
  return {
    barcode,
    name: cleanText(food?.food_name, 160),
    brand: cleanText(food?.brand_name, 120) || "Brand not listed",
    ingredients: "",
    allergenIds,
    traceAllergenIds: [],
    imageUrl: cleanText(images[0]?.image_url, 500) || null,
    dataSource: "FatSecret live lookup",
    categoryIds: categories,
    completeness: 0,
    popularity: 0,
    allergenDataComplete: false,
  };
}

function listValue(value) {
  if (Array.isArray(value)) return value;
  return value == null ? [] : [value];
}

function cleanText(value, maxLength) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function hasFatSecretError(body, code) {
  return Number(body?.error?.code ?? body?.error?.error_code) === code;
}

async function readJson(response) {
  try {
    return await response.json();
  } catch {
    return {};
  }
}
