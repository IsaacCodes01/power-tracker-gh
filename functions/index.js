const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// Fires for EVERY notification your app already creates via
// FirestoreService.createNotification() — reportVerified, powerRestored,
// statusUpdate, announcement, maintenance, newReport — all of it, with no
// per-type code needed here. If you add a new NotificationType later,
// pushes for it work automatically as long as it goes through
// createNotification() like the rest.
exports.sendPushOnNotification = onDocumentCreated(
  "notifications/{notifId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notif = snap.data();
    const userId = notif.userId;
    if (!userId) return;

    const db = getFirestore();
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return; // No device registered for this user — nothing to send.

    try {
      await getMessaging().send({
        token,
        notification: {
          title: notif.title || "Power Tracker GH",
          body: notif.message || "",
        },
        data: {
          notificationId: event.params.notifId,
          type: notif.type || "",
          relatedReportId: notif.relatedReportId || "",
        },
        android: {
          priority: "high",
          notification: { channelId: "power_tracker_default" },
        },
        apns: {
          payload: { aps: { sound: "default" } },
        },
      });
    } catch (err) {
      console.error("FCM send failed for user", userId, err);
      // Token is stale (app uninstalled, token rotated elsewhere) —
      // clear it so future writes don't keep failing the same way.
      if (
        err.code === "messaging/registration-token-not-registered" ||
        err.code === "messaging/invalid-registration-token"
      ) {
        await userRef.update({ fcmToken: FieldValue.delete() });
      }
    }
  }
);