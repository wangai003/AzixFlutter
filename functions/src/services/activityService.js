const admin = require('firebase-admin');
const MiningActivity = require('../models/MiningActivity');
const MiningSession = require('../models/MiningSession');

class ActivityService {
  constructor() {
    this.db = admin.firestore();
  }

  // Log a single activity
  async logActivity(req, res) {
    try {
      const {
        activityType,
        startTime,
        endTime,
        metadata = {},
        sessionId
      } = req.body;

      const userId = req.user.uid;
      const deviceId = req.headers['x-device-id'] || req.body.deviceId;
      const ipAddress = req.ip;
      const userAgent = req.headers['user-agent'];

      // Validate required fields
      if (!activityType || !startTime || !endTime) {
        return res.status(400).json({
          error: 'Missing required fields: activityType, startTime, endTime'
        });
      }

      // Validate activity type
      const validTypes = ['app_usage', 'social_interaction', 'content_creation'];
      if (!validTypes.includes(activityType)) {
        return res.status(400).json({
          error: 'Invalid activity type'
        });
      }

      // Parse timestamps
      const start = new Date(startTime);
      const end = new Date(endTime);

      if (isNaN(start.getTime()) || isNaN(end.getTime())) {
        return res.status(400).json({
          error: 'Invalid timestamp format'
        });
      }

      // Create activity
      const activity = new MiningActivity({
        sessionId,
        userId,
        activityType,
        startTime: start,
        endTime: end,
        metadata,
        deviceId,
        ipAddress,
        userAgent
      });

      // Calculate duration and reward
      activity.calculateDuration();
      const miningRate = await this.getUserMiningRate(userId);
      activity.calculateReward(miningRate);

      // Validate activity
      const isValid = await activity.validate();
      if (!isValid) {
        return res.status(400).json({
          error: 'Activity validation failed',
          reason: activity.validationReason
        });
      }

      // Save activity
      await this.db.collection('mining_activities').doc(activity.activityId).set(activity.toFirestore());

      // Update session if provided
      if (sessionId) {
        await this.updateSessionWithActivity(sessionId, userId, activity);
      }

      console.log(`Logged activity for user ${userId}: ${activityType}, reward: ${activity.reward} AKOFA`);

      res.json({
        success: true,
        activity: activity.toFirestore()
      });
    } catch (error) {
      console.error('Error logging activity:', error);
      res.status(500).json({ error: 'Failed to log activity' });
    }
  }

  // Log batch activities
  async logBatchActivities(req, res) {
    try {
      const { activities, sessionId } = req.body;
      const userId = req.user.uid;

      if (!Array.isArray(activities)) {
        return res.status(400).json({ error: 'Activities must be an array' });
      }

      if (activities.length > 50) {
        return res.status(400).json({ error: 'Maximum 50 activities per batch' });
      }

      const results = [];
      const batch = this.db.batch();

      for (const activityData of activities) {
        const {
          activityType,
          startTime,
          endTime,
          metadata = {}
        } = activityData;

        // Create activity
        const activity = new MiningActivity({
          sessionId,
          userId,
          activityType,
          startTime: new Date(startTime),
          endTime: new Date(endTime),
          metadata,
          deviceId: req.headers['x-device-id'] || activityData.deviceId,
          ipAddress: req.ip,
          userAgent: req.headers['user-agent']
        });

        // Calculate and validate
        activity.calculateDuration();
        const miningRate = await this.getUserMiningRate(userId);
        activity.calculateReward(miningRate);

        const isValid = await activity.validate();

        if (isValid) {
          batch.set(this.db.collection('mining_activities').doc(activity.activityId), activity.toFirestore());
          results.push({ success: true, activity: activity.toFirestore() });
        } else {
          results.push({
            success: false,
            error: activity.validationReason,
            activity: activityData
          });
        }
      }

      // Commit batch
      await batch.commit();

      // Update session if provided
      if (sessionId && results.some(r => r.success)) {
        const totalReward = results
          .filter(r => r.success)
          .reduce((sum, r) => sum + r.activity.reward, 0);

        await this.updateSessionRewards(sessionId, userId, totalReward);
      }

      const successCount = results.filter(r => r.success).length;
      console.log(`Batch logged ${successCount}/${activities.length} activities for user ${userId}`);

      res.json({
        success: true,
        results,
        summary: {
          total: activities.length,
          successful: successCount,
          failed: activities.length - successCount
        }
      });
    } catch (error) {
      console.error('Error logging batch activities:', error);
      res.status(500).json({ error: 'Failed to log batch activities' });
    }
  }

  // Get pending activities for user
  async getPendingActivities(req, res) {
    try {
      const userId = req.user.uid;
      const limit = parseInt(req.query.limit) || 20;

      // Get activities that haven't been processed into rewards yet
      const snapshot = await this.db.collection('mining_activities')
        .where('userId', '==', userId)
        .where('validated', '==', true)
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .get();

      const activities = snapshot.docs.map(doc => MiningActivity.fromFirestore(doc.data()).toFirestore());

      res.json({
        activities,
        count: activities.length
      });
    } catch (error) {
      console.error('Error getting pending activities:', error);
      res.status(500).json({ error: 'Failed to get pending activities' });
    }
  }

  // Helper: Update session with activity
  async updateSessionWithActivity(sessionId, userId, activity) {
    try {
      const sessionRef = this.db.collection('mining_sessions').doc(sessionId);
      const sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) return;

      const session = MiningSession.fromFirestore(sessionDoc.data());

      if (session.userId !== userId) return;

      // Add activity to session
      session.addActivity({
        activityId: activity.activityId,
        type: activity.activityType,
        duration: activity.duration,
        reward: activity.reward,
        timestamp: activity.createdAt
      });

      // Update accumulated time and earnings
      session.accumulatedSeconds += activity.duration;
      session.calculateEarnings();

      await sessionRef.update({
        activities: session.activities,
        accumulatedSeconds: session.accumulatedSeconds,
        earnedAmount: session.earnedAmount,
        lastActivity: session.lastActivity,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error('Error updating session with activity:', error);
    }
  }

  // Helper: Update session rewards
  async updateSessionRewards(sessionId, userId, additionalReward) {
    try {
      const sessionRef = this.db.collection('mining_sessions').doc(sessionId);
      const sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) return;

      const session = MiningSession.fromFirestore(sessionDoc.data());

      if (session.userId !== userId) return;

      session.earnedAmount += additionalReward;

      await sessionRef.update({
        earnedAmount: session.earnedAmount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error('Error updating session rewards:', error);
    }
  }

  // Helper: Get user's mining rate
  async getUserMiningRate(userId) {
    try {
      const userDoc = await this.db.collection('USER').doc(userId).get();
      if (!userDoc.exists) return 0.25;

      const userData = userDoc.data();
      const isRateBoosted = userData.miningRateBoosted || false;
      const referralCount = userData.referralCount || 0;

      return (isRateBoosted && referralCount >= 5) ? 0.50 : 0.25;
    } catch (error) {
      console.error('Error getting user mining rate:', error);
      return 0.25;
    }
  }

  // Process pending activities (called by scheduled function)
  async processPendingActivities() {
    try {
      const batchSize = 100;
      const cutoffTime = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours ago

      // Get activities older than 24 hours that haven't been processed
      const snapshot = await this.db.collection('mining_activities')
        .where('validated', '==', true)
        .where('createdAt', '<', cutoffTime)
        .limit(batchSize)
        .get();

      if (snapshot.empty) return;

      console.log(`Processing ${snapshot.docs.length} pending activities`);

      const batch = this.db.batch();

      for (const doc of snapshot.docs) {
        const activity = MiningActivity.fromFirestore(doc.data());

        // Mark as processed (you could add a processed field)
        batch.update(doc.ref, {
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
      console.log('Processed pending activities successfully');
    } catch (error) {
      console.error('Error processing pending activities:', error);
    }
  }
}

module.exports = new ActivityService();