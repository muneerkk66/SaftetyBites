import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  firstPlacePhoto,
  photoUri,
  validateVenuePhotoInput,
} from "./venue_photo.js";

const googlePlacesKey = defineSecret("GOOGLE_PLACES_API_KEY");

export const getVenuePhotos = onCall(
  {
    region: "europe-west2",
    secrets: [googlePlacesKey],
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to load food business photos.",
      );
    }

    let venues;
    try {
      venues = validateVenuePhotoInput(request.data);
    } catch (error) {
      throw new HttpsError("invalid-argument", error.message);
    }

    const photos = await Promise.all(
      venues.map((venue) => lookupVenuePhoto(venue, googlePlacesKey.value())),
    );
    return {photos: photos.filter(Boolean)};
  },
);

async function lookupVenuePhoto(venue, apiKey) {
  try {
    const searchResponse = await fetch(
      "https://places.googleapis.com/v1/places:searchText",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": "places.photos",
        },
        body: JSON.stringify({
          textQuery: [venue.name, venue.address, venue.postcode]
            .filter(Boolean)
            .join(", "),
          maxResultCount: 1,
          ...(venue.latitude !== null && venue.longitude !== null ? {
            locationBias: {
              circle: {
                center: {
                  latitude: venue.latitude,
                  longitude: venue.longitude,
                },
                radius: 500,
              },
            },
          } : {}),
        }),
      },
    );
    if (!searchResponse.ok) return null;

    const photo = firstPlacePhoto(await searchResponse.json());
    if (photo === null) return null;

    const mediaUrl = new URL(
      `https://places.googleapis.com/v1/${photo.name}/media`,
    );
    mediaUrl.searchParams.set("maxWidthPx", "1000");
    mediaUrl.searchParams.set("skipHttpRedirect", "true");

    const mediaResponse = await fetch(mediaUrl, {
      headers: {"X-Goog-Api-Key": apiKey},
    });
    if (!mediaResponse.ok) return null;

    const url = photoUri(await mediaResponse.json());
    return url === null ? null : {
      id: venue.id,
      url,
      attribution: photo.attribution,
    };
  } catch {
    return null;
  }
}
