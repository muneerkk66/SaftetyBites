import assert from "node:assert/strict";
import test from "node:test";

import {
  firstPlacePhoto,
  photoUri,
  validateVenuePhotoInput,
} from "../venue_photo.js";

test("validates and trims venue photo input", () => {
  const [venue] = validateVenuePhotoInput({
    venues: [{
      id: 42,
      name: "  Green Kitchen  ",
      address: "1 High Street",
      postcode: "SW1A 1AA",
      latitude: 51.501,
      longitude: -0.142,
    }],
  });

  assert.equal(venue.name, "Green Kitchen");
  assert.equal(venue.latitude, 51.501);
});

test("extracts the first photo and attribution", () => {
  const photo = firstPlacePhoto({
    places: [{
      photos: [{
        name: "places/abc/photos/123",
        authorAttributions: [{displayName: "Venue owner"}],
      }],
    }],
  });

  assert.deepEqual(photo, {
    name: "places/abc/photos/123",
    attribution: "Venue owner",
  });
});

test("accepts only secure photo media URLs", () => {
  assert.equal(photoUri({photoUri: "https://example.com/photo.jpg"}),
    "https://example.com/photo.jpg");
  assert.equal(photoUri({photoUri: "http://example.com/photo.jpg"}), null);
});
