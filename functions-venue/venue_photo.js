const maxVenues = 20;

export function validateVenuePhotoInput(data) {
  const venues = Array.isArray(data?.venues) ? data.venues : [];
  if (venues.length === 0 || venues.length > maxVenues) {
    throw new Error(`Provide between 1 and ${maxVenues} venues.`);
  }

  return venues.map((venue) => {
    const id = Number(venue?.id);
    const name = cleanText(venue?.name, 160);
    const address = cleanText(venue?.address, 240);
    const postcode = cleanText(venue?.postcode, 16);
    const latitude = finiteNumber(venue?.latitude);
    const longitude = finiteNumber(venue?.longitude);

    if (!Number.isSafeInteger(id) || id <= 0 || name.length === 0) {
      throw new Error("Each venue needs a valid id and name.");
    }

    return {id, name, address, postcode, latitude, longitude};
  });
}

export function firstPlacePhoto(searchResult) {
  const photo = searchResult?.places?.[0]?.photos?.[0];
  if (typeof photo?.name !== "string" || photo.name.length === 0) {
    return null;
  }

  const attribution = Array.isArray(photo.authorAttributions) ?
    photo.authorAttributions[0] : null;
  return {
    name: photo.name,
    attribution: typeof attribution?.displayName === "string" ?
      attribution.displayName : "",
  };
}

export function photoUri(mediaResult) {
  const uri = mediaResult?.photoUri;
  return typeof uri === "string" && uri.startsWith("https://") ? uri : null;
}

function cleanText(value, maxLength) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function finiteNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
