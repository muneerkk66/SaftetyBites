#!/usr/bin/env python3
import argparse
import csv
import gzip
import hashlib
import json
import sys
from pathlib import Path
from urllib.request import Request, urlopen


csv.field_size_limit(sys.maxsize)

ATTRIBUTION = """SafeBiteAI UK offline food catalogue

Contains information from Open Food Facts, which is made available under the
Open Database Licence (ODbL) 1.0:
https://opendatacommons.org/licenses/odbl/1-0/

Individual database contents are available under DbCL 1.0 and Open Food Facts
product images are available under CC BY-SA 3.0. SafeBiteAI filters and
reformats the source export. Full notices: https://safebiteai.co.uk/data-licences
"""


ALLERGEN_MAP = {
    "peanuts": "peanuts",
    "peanut": "peanuts",
    "nuts": "tree_nuts",
    "almonds": "tree_nuts",
    "hazelnuts": "tree_nuts",
    "walnuts": "tree_nuts",
    "cashew-nuts": "tree_nuts",
    "pecan-nuts": "tree_nuts",
    "pistachio-nuts": "tree_nuts",
    "macadamia-nuts": "tree_nuts",
    "brazil-nuts": "tree_nuts",
    "milk": "milk",
    "egg": "eggs",
    "eggs": "eggs",
    "gluten": "gluten",
    "wheat": "gluten",
    "barley": "gluten",
    "rye": "gluten",
    "oats": "gluten",
    "spelt": "gluten",
    "soya": "soya",
    "soybeans": "soya",
    "sesame": "sesame",
    "sesame-seeds": "sesame",
    "fish": "fish",
    "crustacean": "shellfish",
    "crustaceans": "shellfish",
    "mollusc": "shellfish",
    "molluscs": "shellfish",
    "mustard": "mustard",
    "celery": "celery",
    "lupin": "lupin",
    "sulphur-dioxide-and-sulphites": "sulphites",
}


def arguments():
    parser = argparse.ArgumentParser(
        description="Build SafeBiteAI's UK Open Food Facts offline pack."
    )
    parser.add_argument("--input", required=True, help="CSV .gz file or URL")
    parser.add_argument("--output-dir", default="dist/catalog")
    parser.add_argument("--version", required=True)
    parser.add_argument(
        "--base-url",
        default=".",
        help="Public URL containing the generated pack",
    )
    return parser.parse_args()


def open_input(source):
    if source.startswith(("https://", "http://")):
        request = Request(source, headers={"User-Agent": "SafeBiteAI catalog builder"})
        return gzip.GzipFile(fileobj=urlopen(request))
    return gzip.open(source, "rb")


def tags(value):
    return [item.strip() for item in (value or "").split(",") if item.strip()]


def allergen_ids(value):
    result = set()
    for tag in tags(value):
        key = tag.split(":")[-1].lower()
        mapped = ALLERGEN_MAP.get(key)
        if mapped:
            result.add(mapped)
    return sorted(result)


def numeric(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0


def primary_category(row):
    main_category = (row.get("main_category") or "").strip()
    if main_category:
        return main_category
    categories = tags(row.get("categories_tags"))
    return categories[-1] if categories else None


def product(row):
    ingredients = (
        row.get("ingredients_text_en") or row.get("ingredients_text") or ""
    ).strip()
    allergens = allergen_ids(row.get("allergens_tags") or row.get("allergens"))
    traces = allergen_ids(row.get("traces_tags") or row.get("traces"))
    category = primary_category(row)
    image_url = (
        row.get("image_front_small_url")
        or row.get("image_small_url")
        or row.get("image_url")
        or ""
    ).strip()
    item = {
        "barcode": (row.get("code") or "").strip(),
        "name": (row.get("product_name_en") or row.get("product_name") or "Unknown product").strip(),
        "brand": (row.get("brands") or "Brand not listed").strip(),
        "ingredients": ingredients,
        "allergenIds": allergens,
        "traceAllergenIds": traces,
        "completeness": numeric(row.get("completeness")),
        "popularity": numeric(row.get("popularity_key")),
    }
    if image_url:
        item["imageUrl"] = image_url
    if category:
        item["categoryIds"] = [category]
    return item


def main():
    args = arguments()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    filename = f"uk-products-{args.version}.jsonl.gz"
    output_path = output_dir / filename
    count = 0

    with open_input(args.input) as compressed_input:
        text_input = (line.decode("utf-8", errors="replace") for line in compressed_input)
        reader = csv.DictReader(text_input, delimiter="\t")
        with gzip.open(output_path, "wt", encoding="utf-8", compresslevel=9) as output:
            for row in reader:
                countries = set(tags(row.get("countries_tags")))
                if "en:united-kingdom" not in countries:
                    continue
                item = product(row)
                if len(item["barcode"]) < 8:
                    continue
                if not (
                    item["ingredients"]
                    or item["allergenIds"]
                    or item["traceAllergenIds"]
                ):
                    continue
                output.write(json.dumps(item, separators=(",", ":"), ensure_ascii=False))
                output.write("\n")
                count += 1

    digest = hashlib.sha256(output_path.read_bytes()).hexdigest()
    download_url = f"{args.base_url.rstrip('/')}/{filename}"
    manifest = {
        "version": args.version,
        "downloadUrl": download_url,
        "attributionUrl": f"{args.base_url.rstrip('/')}/ATTRIBUTION.txt",
        "sourceUrl": "https://world.openfoodfacts.org/data",
        "databaseLicense": "ODbL-1.0",
        "contentsLicense": "DbCL-1.0",
        "imageLicense": "CC-BY-SA-3.0",
        "sha256": digest,
        "productCount": count,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    (output_dir / "ATTRIBUTION.txt").write_text(ATTRIBUTION, encoding="utf-8")
    print(f"Built {count:,} UK products: {output_path}")


if __name__ == "__main__":
    main()
