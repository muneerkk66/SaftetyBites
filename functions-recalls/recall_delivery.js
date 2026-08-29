const supportedRetailers = new Set([
  "tesco",
  "aldi",
  "asda",
  "sainsburys",
  "lidl",
  "morrisons",
  "waitrose",
  "iceland",
  "coop",
  "marks_spencer",
]);

export function normalizeInstallation(data) {
  const installationId = typeof data?.installationId === "string" ?
    data.installationId.trim().toLowerCase() : "";
  const token = typeof data?.token === "string" ? data.token.trim() : "";
  const platform = data?.platform === "ios" || data?.platform === "android" ?
    data.platform : "unknown";
  const retailerIds = [...new Set(Array.isArray(data?.retailerIds) ?
    data.retailerIds.filter((value) => typeof value === "string")
      .map((value) => value.trim().toLowerCase())
      .filter((value) => supportedRetailers.has(value)) : [])].sort();

  if (!/^[a-f0-9]{32}$/.test(installationId)) {
    throw new Error("A valid installation identifier is required.");
  }
  if (token.length < 20 || token.length > 4096) {
    throw new Error("A valid Firebase messaging token is required.");
  }
  return {installationId, token, platform, retailerIds};
}

export function buildRecallMessage(tokens, alert) {
  const body = (alert.consumerAdvice || alert.summary ||
    "Open SafeBiteAI to review the official notice.").slice(0, 180);
  return {
    tokens,
    notification: {
      title: alert.shortTitle.slice(0, 100),
      body,
    },
    data: {
      alertId: alert.id,
      alertType: alert.alertType,
      route: "alerts",
      sourceUrl: alert.sourceUrl,
    },
    android: {priority: "high"},
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          "content-available": 1,
        },
      },
    },
  };
}

export function isInvalidMessagingToken(error) {
  return error?.code === "messaging/registration-token-not-registered" ||
    error?.code === "messaging/invalid-registration-token";
}

export function chunks(values, size = 500) {
  const result = [];
  for (let offset = 0; offset < values.length; offset += size) {
    result.push(values.slice(offset, offset + size));
  }
  return result;
}
