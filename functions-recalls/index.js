import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {normalizeFsaAlert} from "./recall_parser.js";
import {
  buildRecallMessage,
  chunks,
  isInvalidMessagingToken,
  normalizeInstallation,
} from "./recall_delivery.js";

initializeApp();

const db = getFirestore();
const alertsCollection = db.collection("food_alerts");
const installationsCollection = db.collection("recall_installations");
const syncState = db.collection("system").doc("food_alert_sync");
const pageSize = 100;

export const pollFoodAlerts = onSchedule(
  {
    region: "europe-west2",
    schedule: "every 15 minutes",
    timeZone: "Europe/London",
    timeoutSeconds: 120,
    memory: "256MiB",
    maxInstances: 1,
    retryCount: 1,
  },
  async () => {
    const result = await syncFoodAlerts({sendNotifications: true});
    logger.info("FSA food-alert poll completed", result);
  },
);

export const listFoodAlerts = onCall(
  {
    region: "europe-west2",
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 20,
  },
  async () => {
    let snapshot = await latestAlerts();
    if (snapshot.empty) {
      await syncFoodAlerts({sendNotifications: false});
      snapshot = await latestAlerts();
    }

    return {
      alerts: snapshot.docs
        .map((document) => document.data())
        .filter((alert) => alert.status?.toLowerCase() === "published")
        .slice(0, 40),
      checkedAt: new Date().toISOString(),
    };
  },
);

export const syncRecallInstallation = onCall(
  {
    region: "europe-west2",
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 40,
  },
  async (request) => {
    let installation;
    try {
      installation = normalizeInstallation(request.data);
    } catch (error) {
      throw new HttpsError("invalid-argument", error.message);
    }
    await installationsCollection.doc(installation.installationId).set({
      token: installation.token,
      retailerIds: installation.retailerIds,
      platform: installation.platform,
      active: installation.retailerIds.length > 0,
      userId: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {
      registered: installation.retailerIds.length > 0,
      retailerCount: installation.retailerIds.length,
    };
  },
);

async function latestAlerts() {
  return alertsCollection.orderBy("modifiedAt", "desc").limit(60).get();
}

async function syncFoodAlerts({sendNotifications}) {
  const stateSnapshot = await syncState.get();
  const initialized = stateSnapshot.exists;
  const lastCheckedAt = stateSnapshot.data()?.lastCheckedAt;
  const since = lastCheckedAt ?
    new Date(new Date(lastCheckedAt).getTime() - 30 * 60 * 1000) :
    new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
  const rawAlerts = await fetchFsaAlerts(since);
  const alerts = rawAlerts.map(normalizeFsaAlert);
  const references = alerts.map((alert) => alertsCollection.doc(alert.id));
  const existingSnapshots = references.length === 0 ? [] :
    await db.getAll(...references);
  const existingById = new Map(existingSnapshots.map((snapshot) => [
    snapshot.id,
    snapshot.exists ? snapshot.data() : null,
  ]));
  const changed = alerts.filter((alert) =>
    existingById.get(alert.id)?.modifiedAt !== alert.modifiedAt);

  for (let offset = 0; offset < changed.length; offset += 450) {
    const batch = db.batch();
    for (const alert of changed.slice(offset, offset + 450)) {
      batch.set(alertsCollection.doc(alert.id), {
        ...alert,
        syncedAt: new Date().toISOString(),
      }, {merge: true});
    }
    await batch.commit();
  }

  await syncState.set({
    initializedAt: stateSnapshot.data()?.initializedAt || new Date().toISOString(),
    lastCheckedAt: new Date().toISOString(),
    lastResultCount: rawAlerts.length,
    lastChangedCount: changed.length,
    source: "FSA Food Alerts API",
  }, {merge: true});

  let notificationsSent = 0;
  if (initialized && sendNotifications) {
    for (const alert of changed) {
      notificationsSent += await notifyAlert(alert);
    }
  }
  return {fetched: rawAlerts.length, changed: changed.length, notificationsSent};
}

async function fetchFsaAlerts(since) {
  const results = [];
  for (let offset = 0; offset < 1000; offset += pageSize) {
    const url = new URL("https://data.food.gov.uk/food-alerts/id");
    url.searchParams.set("since", since.toISOString());
    url.searchParams.set("_view", "full");
    url.searchParams.set("_limit", `${pageSize}`);
    url.searchParams.set("_offset", `${offset}`);
    url.searchParams.set("_sort", "-modified");
    const response = await fetch(url, {
      headers: {Accept: "application/json"},
      signal: AbortSignal.timeout(25000),
    });
    if (!response.ok) {
      const detail = (await response.text()).slice(0, 500);
      throw new Error(
        `FSA Food Alerts API returned ${response.status}: ${detail}`,
      );
    }
    const body = await response.json();
    const items = Array.isArray(body?.items) ? body.items : [];
    results.push(...items);
    if (items.length < pageSize) break;
  }
  return results;
}

async function notifyAlert(alert) {
  if (alert.status.toLowerCase() !== "published" ||
      alert.retailerIds.length === 0) return 0;
  const snapshot = await installationsCollection
    .where("retailerIds", "array-contains-any", alert.retailerIds)
    .get();
  const referencesByToken = new Map();
  for (const document of snapshot.docs) {
    const registration = document.data();
    const token = typeof registration.token === "string" ?
      registration.token.trim() : "";
    if (registration.active !== false && token) {
      const references = referencesByToken.get(token) || [];
      references.push(document.ref);
      referencesByToken.set(token, references);
    }
  }

  let sent = 0;
  for (const tokenBatch of chunks([...referencesByToken.keys()])) {
    const response = await getMessaging().sendEachForMulticast(
      buildRecallMessage(tokenBatch, alert),
    );
    sent += response.successCount;
    const invalidReferences = [];
    response.responses.forEach((result, index) => {
      if (!result.success && isInvalidMessagingToken(result.error)) {
        invalidReferences.push(
          ...(referencesByToken.get(tokenBatch[index]) || []),
        );
      } else if (!result.success) {
        logger.error("Could not send food-alert notification", {
          alertId: alert.id,
          error: result.error,
        });
      }
    });
    for (const referenceBatch of chunks(invalidReferences, 450)) {
      const writeBatch = db.batch();
      referenceBatch.forEach((reference) => writeBatch.delete(reference));
      await writeBatch.commit();
    }
  }
  logger.info("Direct recall notification completed", {
    alertId: alert.id,
    matchedInstallations: snapshot.size,
    uniqueTokens: referencesByToken.size,
    sent,
  });
  return sent;
}
