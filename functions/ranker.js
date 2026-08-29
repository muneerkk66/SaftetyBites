export function validateRankingInput(data) {
  if (!data || typeof data !== "object") {
    throw new Error("Recommendation data is required.");
  }
  const source = normalizeProduct(data.source);
  const candidates = Array.isArray(data.candidates)
    ? data.candidates.slice(0, 12).map(normalizeProduct)
    : [];
  if (!source.barcode || !source.name) {
    throw new Error("A source product is required.");
  }
  const eligible = candidates.filter((candidate) => {
    return candidate.barcode && candidate.name;
  });
  return {source, candidates: eligible};
}

export function extractRankings(response, candidates) {
  const text = response?.output_text ?? response?.output
    ?.flatMap((item) => item?.content ?? [])
    .find((content) => content?.type === "output_text")?.text;
  if (typeof text !== "string") return [];
  const parsed = JSON.parse(text);
  const allowed = new Set(candidates.map((candidate) => candidate.barcode));
  const seen = new Set();
  return (Array.isArray(parsed.rankings) ? parsed.rankings : [])
    .filter((ranking) => {
      const barcode = cleanText(ranking?.barcode, 32);
      if (!allowed.has(barcode) || seen.has(barcode)) return false;
      seen.add(barcode);
      return true;
    })
    .map((ranking) => ({
      barcode: cleanText(ranking.barcode, 32),
      reason: cleanText(ranking.reason, 140),
    }));
}

export function fallbackRankings(candidates) {
  return [...candidates]
    .sort((first, second) => score(second) - score(first))
    .map((candidate) => ({
      barcode: candidate.barcode,
      reason: "A similar option with no listed household allergen conflict.",
    }));
}

function normalizeProduct(value) {
  const product = value && typeof value === "object" ? value : {};
  return {
    barcode: cleanText(product.barcode, 32),
    name: cleanText(product.name, 120),
    brand: cleanText(product.brand, 100),
    categories: stringArray(product.categories, 24),
    allergens: stringArray(product.allergens, 20),
    traces: stringArray(product.traces, 20),
    completeness: finiteNumber(product.completeness),
    popularity: finiteNumber(product.popularity),
  };
}

function stringArray(value, limit) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, limit).map((item) => cleanText(item, 100))
    .filter(Boolean);
}

function cleanText(value, maxLength) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function finiteNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function score(candidate) {
  return candidate.categories.length * 1000 +
    candidate.completeness * 100 + candidate.popularity;
}
