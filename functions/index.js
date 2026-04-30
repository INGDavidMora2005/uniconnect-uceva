const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Initialize Firebase Admin SDK
const admin = require("firebase-admin");
admin.initializeApp();

// Helper: get FCM token for a user
async function getFcmToken(userId) {
  if (!userId) return null;
  const userDoc = await getFirestore().doc(`users/${userId}`).get();
  if (!userDoc.exists) return null;
  const data = userDoc.data();
  return data?.fcmToken ?? null;
}

// Helper: send push notification
async function sendPush(token, title, body, data = {}) {
  if (!token) return;
  await getMessaging().send({
    token,
    notification: { title, body },
    data,
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  });
}

// 1. onCupoRequested
exports.onCupoRequested = onDocumentCreated("cupo_requests/{requestId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();
  const { driverId, passengerName, origin, destination, time } = data;
  if (!driverId) return;
  const token = await getFcmToken(driverId);
  const title = "Solicitud de cupo recibida";
  const body = `${passengerName} quiere compartir cupo de ${origin} a ${destination}`;
  await sendPush(token, title, body, { type: "cupo_request", requestId: snapshot.id });
});

// 2. onCupoResponded
exports.onCupoResponded = onDocumentUpdated("cupo_requests/{requestId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  // Only act if status changed from pending to accepted/rejected
  if (before.status !== "pending") return;
  if (after.status !== "accepted" && after.status !== "rejected") return;
  const { passengerId, origin, destination } = after;
  if (!passengerId) return;
  const token = await getFcmToken(passengerId);
  const title = after.status === "accepted" ? "Cupo aceptado" : "Cupo rechazado";
  const body = `Tu solicitud de cupo de ${origin} a ${destination} fue ${after.status === "accepted" ? "aceptada" : "rechazada"}`;
  await sendPush(token, title, body, {
    type: after.status === "accepted" ? "cupo_accepted" : "cupo_rejected",
    requestId: event.params.requestId,
  });
});

// 3. onNewMessage
exports.onNewMessage = onDocumentCreated("messages/{chatId}/messages/{messageId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();
  const { receiverId, senderName, text } = data;
  if (!receiverId) return;
  const token = await getFcmToken(receiverId);
  const title = `Nuevo mensaje de ${senderName}`;
  const body = text.substring(0, 50) + (text.length > 50 ? "..." : "");
  await sendPush(token, title, body, { type: "new_message", chatId: event.params.chatId });
});

// 4. onRatingReceived
exports.onRatingReceived = onDocumentCreated("ratings/{ratingId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();
  const { ratedUserId, raterName, stars, routeDescription } = data;
  if (!ratedUserId) return;
  const token = await getFcmToken(ratedUserId);
  const title = "Nueva calificación recibida";
  const body = `${raterName} te calificó con ${stars} estrellas${routeDescription ? ` en ${routeDescription}` : ""}`;
  await sendPush(token, title, body, { type: "new_rating", ratingId: snapshot.id });
});