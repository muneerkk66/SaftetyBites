#!/usr/bin/env python3
import argparse
import csv
import gzip
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen


ALLERGEN_MAP = {
    "peanuts": "peanuts",
    "nuts": "tree_nuts",
    "milk": "milk",
    "eggs": "eggs",
    "gluten": "gluten",
    "soybeans": "soya",
    "sesame-seeds": "sesame",
    "fish": "fish",
    "crustaceans": "shellfish",
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


def product(row):
    return {
        "barcode": (row.get("code") or "").strip(),
        "name": (row.get("product_name_en") or row.get("product_name") or "Unknown product").strip(),
        "brand": (row.get("brands") or "Brand not listed").strip(),
        "ingredients": (row.get("ingredients_text_en") or row.get("ingredients_text") or "").strip(),
        "allergenIds": allergen_ids(row.get("allergens_tags")),
        "traceAllergenIds": allergen_ids(row.get("traces_tags")),
        "imageUrl": (row.get("image_front_small_url") or "").strip() or None,
        "dataSource": "Open Food Facts",
        "categoryIds": tags(row.get("categories_tags")),
        "completeness": numeric(row.get("completeness")),
        "popularity": numeric(row.get("popularity_key")),
        "allergenDataComplete": True,
    }


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
                output.write(json.dumps(item, separators=(",", ":"), ensure_ascii=False))
                output.write("\n")
                count += 1

    digest = hashlib.sha256(output_path.read_bytes()).hexdigest()
    download_url = f"{args.base_url.rstrip('/')}/{filename}"
    manifest = {
        "version": args.version,
        "downloadUrl": download_url,
        "sha256": digest,
        "productCount": count,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Built {count:,} UK products: {output_path}")


if __name__ == "__main__":
    main()
