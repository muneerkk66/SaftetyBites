const retailerPatterns = new Map([
  ["tesco", ["tesco"]],
  ["aldi", ["aldi"]],
  ["asda", ["asda"]],
  ["sainsburys", ["sainsbury"]],
  ["lidl", ["lidl"]],
  ["morrisons", ["morrisons", "wm morrison"]],
  ["waitrose", ["waitrose"]],
  ["iceland", ["iceland"]],
  ["coop", ["co-op", "co op", "coop", "co-operative"]],
  ["marks_spencer", ["marks & spencer", "marks and spencer", "m&s"]],
]);

const allergenAliases = new Map([
  ["peanut", "peanuts"],
  ["peanuts", "peanuts"],
  ["nut", "tree_nuts"],
  ["nuts", "tree_nuts"],
  ["tree-nuts", "tree_nuts"],
  ["almond", "tree_nuts"],
  ["hazelnut", "tree_nuts"],
  ["walnut", "tree_nuts"],
  ["cashew", "tree_nuts"],
  ["pecan", "tree_nuts"],
  ["pistachio", "tree_nuts"],
  ["macadamia", "tree_nuts"],
  ["brazil-nut", "tree_nuts"],
  ["milk", "milk"],
  ["egg", "eggs"],
  ["eggs", "eggs"],
  ["gluten", "gluten"],
  ["wheat", "gluten"],
  ["barley", "gluten"],
  ["rye", "gluten"],
  ["oats", "gluten"],
  ["soya", "soya"],
  ["soy", "soya"],
  ["sesame", "sesame"],
  ["fish", "fish"],
  ["crustaceans", "shellfish"],
  ["crustacean", "shellfish"],
  ["molluscs", "shellfish"],
  ["mollusc", "shellfish"],
  ["mustard", "mustard"],
  ["celery", "celery"],
  ["lupin", "lupin"],
  ["sulphites", "sulphites"],
  ["sulphur-dioxide", "sulphites"],
]);

export function normalizeFsaAlert(item) {
  const id = text(item?.notation) || text(item?.["@id"]).split("/").pop();
  if (!id) throw new Error("FSA alert has no identifier.");

  const problems = asList(item?.problem);
  const products = uniqueBy(
    [
      ...asList(item?.productDetails),
      ...problems.flatMap((problem) => asList(problem?.productDetails)),
    ].map(normalizeProduct).filter((product) => product.name),
    (product) => `${product.name}|${product.packSize}|${product.batchDetails}`,
  );
  const allergenIds = unique(
    problems.flatMap((problem) =>
      asList(problem?.allergen)
        .map((allergen) => normalizeAllergen(text(allergen?.notation) ||
          text(allergen?.label)))
        .filter(Boolean),
    ),
  );
  const alertType = extractAlertType(item?.type);
  const businessNames = unique([
    businessName(item?.reportingBusiness),
    ...asList(item?.otherBusiness).map(businessName),
  ].filter(Boolean));
  const searchableText = [
    item?.title,
    item?.description,
    item?.consumerAdvice,
    item?.actionTaken,
    ...businessNames,
    ...products.map((product) => product.name),
  ].map(text).join(" ").toLowerCase();
  const retailerIds = [...retailerPatterns.entries()]
    .filter(([, patterns]) => patterns.some((pattern) =>
      searchableText.includes(pattern)))
    .map(([retailer]) => retailer);

  return {
    id,
    title: text(item?.title) || "UK food safety alert",
    shortTitle: text(item?.shortTitle) || text(item?.title) ||
      "UK food safety alert",
    summary: text(item?.description),
    consumerAdvice: text(item?.consumerAdvice) || text(item?.actionTaken),
    actionTaken: text(item?.actionTaken),
    alertType,
    status: text(item?.status?.label) || "Published",
    createdAt: validIsoDate(item?.created),
    modifiedAt: validIsoDate(item?.modified || item?.created),
    sourceUrl: secureUrl(item?.alertURL),
    shortUrl: secureUrl(item?.shortURL),
    businessNames,
    retailerIds,
    allergenIds,
    products,
    source: "Food Standards Agency",
    licence: "Open Government Licence 3.0",
  };
}

export function notificationTopics(alert) {
  if (alert.status.toLowerCase() !== "published") return [];
  if (alert.retailerIds.length === 0) return [];
  return alert.retailerIds.map((retailer) => `retailer_${retailer}`);
}

function normalizeProduct(product) {
  const batches = asList(product?.batchDescription).map((batch) => [
    text(batch?.batchCode),
    text(batch?.useByDescription),
    text(batch?.bestBeforeDescription),
  ].filter(Boolean).join(" · ")).filter(Boolean);
  return {
    name: text(product?.productName),
    packSize: text(product?.packSizeDescription),
    batchDetails: batches.join("; "),
  };
}

function extractAlertType(value) {
  const types = asList(value).map(text);
  for (const candidate of ["AA", "PRIN", "FAFA"]) {
    if (types.some((type) => type.endsWith(`/${candidate}`) ||
      type === candidate)) return candidate;
  }
  return "ALERT";
}

function normalizeAllergen(value) {
  const key = value.toLowerCase().trim().replaceAll(/\s+/g, "-");
  return allergenAliases.get(key) || "";
}

function businessName(value) {
  return text(value?.commonName) || text(value?.legalName) || text(value?.name);
}

function validIsoDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? new Date(0).toISOString() :
    date.toISOString();
}

function secureUrl(value) {
  const candidate = text(value);
  return candidate.startsWith("https://") ? candidate : "";
}

function text(value) {
  if (Array.isArray(value)) return value.map(text).find(Boolean) || "";
  return typeof value === "string" ? value.trim() : "";
}

function asList(value) {
  if (Array.isArray(value)) return value;
  return value == null ? [] : [value];
}

function unique(values) {
  return [...new Set(values)];
}

function uniqueBy(values, keyOf) {
  const seen = new Set();
  return values.filter((value) => {
    const key = keyOf(value);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
