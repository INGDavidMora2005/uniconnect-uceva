const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const functions = require("firebase-functions");

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

// 3. onNewMessage — CORREGIDO: ruta apunta a chats/{chatId}/messages/{messageId}
exports.onNewMessage = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();
  const { receiverId, senderId, text } = data;
  if (!receiverId) return;
  const token = await getFcmToken(receiverId);
  // Obtener nombre del remitente desde Firestore
  const senderDoc = await getFirestore().doc(`users/${senderId}`).get();
  const senderName = senderDoc.exists ? (senderDoc.data()?.name ?? "Alguien") : "Alguien";
  const title = `Nuevo mensaje de ${senderName}`;
  const body = text && text.length > 0
    ? text.substring(0, 50) + (text.length > 50 ? "..." : "")
    : "Te envió un mensaje";
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

// 5. scheduledCloseChatAfter24h — Ejecutarse cada hora
exports.scheduledCloseChatAfter24h = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async (context) => {
    const db = getFirestore();
    const batch = db.batch();
    let closedCount = 0;

    try {
      const completedRoutes = await db
        .collection("routes")
        .where("status", "==", "Completada")
        .get();

      const now = admin.firestore.Timestamp.now();

      for (const routeDoc of completedRoutes.docs) {
        const routeData = routeDoc.data();
        const updatedAt = routeData.updatedAt;

        if (!updatedAt) continue;

        const updatedAtTimestamp =
          updatedAt instanceof admin.firestore.Timestamp
            ? updatedAt
            : admin.firestore.Timestamp.fromDate(
                new Date(updatedAt.seconds * 1000)
              );

        const diffMs = now.toMillis() - updatedAtTimestamp.toMillis();
        const twentyFourHoursMs = 24 * 60 * 60 * 1000;

        if (diffMs < twentyFourHoursMs) continue;

        const chatsSnapshot = await db
          .collection("chats")
          .where("routeId", "==", routeDoc.id)
          .where("isClosed", "==", false)
          .get();

        for (const chatDoc of chatsSnapshot.docs) {
          batch.update(chatDoc.ref, {
            isClosed: true,
            closedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          closedCount++;
        }
      }

      if (closedCount > 0) {
        await batch.commit();
        console.log(`scheduledCloseChatAfter24h: Se cerraron ${closedCount} chat(s).`);
      } else {
        console.log("scheduledCloseChatAfter24h: No se encontraron chats para cerrar.");
      }
    } catch (error) {
      console.error("scheduledCloseChatAfter24h — Error:", error);
    }
  });

// Migration function to add suspended field to existing users
exports.migrateAddSuspendedField = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const usersSnap = await db.collection('users').get();

    const batch = db.batch();
    let count = 0;

    usersSnap.docs.forEach((doc) => {
      const data = doc.data();
      if (data.suspended === undefined) {
        batch.update(doc.ref, { suspended: false });
        count++;
      }
    });

    if (count > 0) {
      await batch.commit();
    }

    res.json({
      success: true,
      message: `Updated ${count} users with suspended: false`
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});