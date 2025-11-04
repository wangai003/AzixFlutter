const admin = require('firebase-admin');

class SecurityService {
  constructor() {
    this.db = admin.firestore();
  }

  // Validate active mining sessions
  async validateActiveSessions() {
    try {
      const now = new Date();
      const cutoffTime = new Date(now.getTime() - 24 * 60 * 60 * 1000); // 24 hours ago

      // Get all active sessions
      const snapshot = await this.db.collection('mining_sessions')
        .where('status', 'in', ['active', 'paused'])
        .get();

      console.log(`Validating ${snapshot.docs.length} active sessions`);

      const batch = this.db.batch();
      let expiredCount = 0;
      let suspiciousCount = 0;

      for (const doc of snapshot.docs) {
        const session = doc.data();
        const sessionId = doc.id;
        const userId = session.userId;

        // Check if session has expired
        if (session.endTime && session.endTime.toDate() < now) {
          batch.update(doc.ref, {
            status: 'expired',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          expiredCount++;
          continue;
        }

        // Check for suspicious activity patterns
        const isSuspicious = await this.checkSessionForSuspiciousActivity(session);

        if (isSuspicious) {
          // Log security event
          await this.logSecurityEvent('suspicious_session_activity', {
            sessionId,
            userId,
            reason: isSuspicious.reason,
            severity: 'medium'
          });

          // Flag session for review
          batch.update(doc.ref, {
            flagged: true,
            flagReason: isSuspicious.reason,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

          suspiciousCount++;
        }
      }

      if (expiredCount > 0 || suspiciousCount > 0) {
        await batch.commit();
      }

      console.log(`Session validation complete: ${expiredCount} expired, ${suspiciousCount} flagged`);

    } catch (error) {
      console.error('Error validating active sessions:', error);
    }
  }

  // Check session for suspicious activity
  async checkSessionForSuspiciousActivity(session) {
    try {
      const userId = session.userId;
      const sessionId = session.sessionId;

      // Check 1: Unrealistic accumulated time
      const sessionDuration = (new Date() - session.startTime.toDate()) / 1000; // seconds
      const accumulatedTime = session.accumulatedSeconds || 0;

      if (accumulatedTime > sessionDuration * 1.5) { // More than 150% of session duration
        return {
          suspicious: true,
          reason: 'Accumulated time exceeds session duration'
        };
      }

      // Check 2: Too many activities in short time
      const activities = session.activities || [];
      const recentActivities = activities.filter(activity => {
        const activityTime = new Date(activity.timestamp).getTime();
        const oneHourAgo = Date.now() - 60 * 60 * 1000;
        return activityTime > oneHourAgo;
      });

      if (recentActivities.length > 100) { // More than 100 activities per hour
        return {
          suspicious: true,
          reason: 'Too many activities in short time period'
        };
      }

      // Check 3: Same device mining multiple sessions
      const deviceId = session.deviceId;
      if (deviceId) {
        const deviceSessions = await this.db.collection('mining_sessions')
          .where('deviceId', '==', deviceId)
          .where('status', 'in', ['active', 'paused'])
          .get();

        if (deviceSessions.docs.length > 3) { // More than 3 active sessions on same device
          return {
            suspicious: true,
            reason: 'Multiple active sessions on same device'
          };
        }
      }

      // Check 4: Activity pattern analysis
      const activityPattern = this.analyzeActivityPattern(activities);
      if (activityPattern.suspicious) {
        return {
          suspicious: true,
          reason: activityPattern.reason
        };
      }

      return { suspicious: false };

    } catch (error) {
      console.error('Error checking session for suspicious activity:', error);
      return { suspicious: false };
    }
  }

  // Analyze activity pattern for anomalies
  analyzeActivityPattern(activities) {
    if (!activities || activities.length < 5) {
      return { suspicious: false };
    }

    // Check for perfectly regular intervals (bot-like behavior)
    const timestamps = activities.map(a => new Date(a.timestamp).getTime()).sort();
    const intervals = [];

    for (let i = 1; i < timestamps.length; i++) {
      intervals.push(timestamps[i] - timestamps[i - 1]);
    }

    // Calculate interval variance
    const avgInterval = intervals.reduce((sum, interval) => sum + interval, 0) / intervals.length;
    const variance = intervals.reduce((sum, interval) => sum + Math.pow(interval - avgInterval, 2), 0) / intervals.length;
    const stdDev = Math.sqrt(variance);

    // If intervals are too regular (low variance), flag as suspicious
    if (stdDev < avgInterval * 0.1 && avgInterval < 60000) { // Less than 1 minute intervals, very regular
      return {
        suspicious: true,
        reason: 'Unnaturally regular activity intervals'
      };
    }

    // Check for burst activity (many activities in short time)
    const now = Date.now();
    const lastHourActivities = activities.filter(a => {
      const activityTime = new Date(a.timestamp).getTime();
      return (now - activityTime) < 60 * 60 * 1000; // Last hour
    });

    if (lastHourActivities.length > 50) {
      const timeSpan = Math.max(...lastHourActivities.map(a => new Date(a.timestamp).getTime())) -
                      Math.min(...lastHourActivities.map(a => new Date(a.timestamp).getTime()));
      const activitiesPerMinute = (lastHourActivities.length / (timeSpan / 1000)) * 60;

      if (activitiesPerMinute > 10) { // More than 10 activities per minute
        return {
          suspicious: true,
          reason: 'Burst activity pattern detected'
        };
      }
    }

    return { suspicious: false };
  }

  // Validate activity before logging
  async validateActivity(activityData, userId, sessionId = null) {
    try {
      const {
        activityType,
        startTime,
        endTime,
        duration,
        deviceId,
        ipAddress
      } = activityData;

      // Basic validation
      if (!activityType || !['app_usage', 'social_interaction', 'content_creation'].includes(activityType)) {
        return { valid: false, reason: 'Invalid activity type' };
      }

      if (!startTime || !endTime) {
        return { valid: false, reason: 'Missing timestamps' };
      }

      const start = new Date(startTime);
      const end = new Date(endTime);

      if (isNaN(start.getTime()) || isNaN(end.getTime())) {
        return { valid: false, reason: 'Invalid timestamp format' };
      }

      if (end <= start) {
        return { valid: false, reason: 'End time must be after start time' };
      }

      const calculatedDuration = (end - start) / 1000;
      if (duration && Math.abs(duration - calculatedDuration) > 5) { // Allow 5 second difference
        return { valid: false, reason: 'Duration mismatch' };
      }

      // Check for future activities
      const now = new Date();
      if (start > now || end > now) {
        return { valid: false, reason: 'Activity cannot be in the future' };
      }

      // Check for too old activities
      const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      if (start < oneDayAgo) {
        return { valid: false, reason: 'Activity is too old' };
      }

      // Device consistency check
      if (deviceId) {
        const isDeviceConsistent = await this.checkDeviceConsistency(userId, deviceId);
        if (!isDeviceConsistent) {
          await this.logSecurityEvent('device_inconsistency', {
            userId,
            deviceId,
            activityType,
            severity: 'low'
          });
        }
      }

      // IP-based checks
      if (ipAddress) {
        const ipCheck = await this.checkIPAddress(ipAddress, userId);
        if (ipCheck.suspicious) {
          await this.logSecurityEvent('suspicious_ip', {
            userId,
            ipAddress,
            reason: ipCheck.reason,
            severity: 'medium'
          });
        }
      }

      // Rate limiting check
      const rateCheck = await this.checkActivityRate(userId, activityType);
      if (!rateCheck.allowed) {
        return {
          valid: false,
          reason: `Rate limit exceeded: ${rateCheck.reason}`
        };
      }

      return { valid: true };

    } catch (error) {
      console.error('Error validating activity:', error);
      return { valid: false, reason: 'Validation error' };
    }
  }

  // Check device consistency for user
  async checkDeviceConsistency(userId, deviceId) {
    try {
      // Get user's recent sessions
      const recentSessions = await this.db.collection('mining_sessions')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();

      const deviceIds = recentSessions.docs.map(doc => doc.data().deviceId);
      const uniqueDevices = [...new Set(deviceIds)];

      // Allow up to 3 different devices
      return uniqueDevices.length <= 3 || uniqueDevices.includes(deviceId);
    } catch (error) {
      return true; // Allow on error
    }
  }

  // Check IP address for suspicious patterns
  async checkIPAddress(ipAddress, userId) {
    try {
      // Get recent activities from this IP
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

      const recentActivities = await this.db.collection('mining_activities')
        .where('ipAddress', '==', ipAddress)
        .where('createdAt', '>', oneHourAgo)
        .get();

      // Check if this IP is used by multiple users
      const users = [...new Set(recentActivities.docs.map(doc => doc.data().userId))];

      if (users.length > 3) {
        return {
          suspicious: true,
          reason: 'IP address shared by multiple users'
        };
      }

      return { suspicious: false };
    } catch (error) {
      return { suspicious: false };
    }
  }

  // Check activity rate limits
  async checkActivityRate(userId, activityType) {
    try {
      const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

      // Check per minute rate
      const minuteActivities = await this.db.collection('mining_activities')
        .where('userId', '==', userId)
        .where('activityType', '==', activityType)
        .where('createdAt', '>', oneMinuteAgo)
        .get();

      if (minuteActivities.docs.length > 30) { // Max 30 activities per minute
        return {
          allowed: false,
          reason: 'Too many activities per minute'
        };
      }

      // Check per hour rate
      const hourActivities = await this.db.collection('mining_activities')
        .where('userId', '==', userId)
        .where('activityType', '==', activityType)
        .where('createdAt', '>', oneHourAgo)
        .get();

      if (hourActivities.docs.length > 500) { // Max 500 activities per hour
        return {
          allowed: false,
          reason: 'Too many activities per hour'
        };
      }

      return { allowed: true };
    } catch (error) {
      return { allowed: true }; // Allow on error
    }
  }

  // Log security event
  async logSecurityEvent(eventType, details) {
    try {
      await this.db.collection('security_events').add({
        eventType,
        details,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`Security event logged: ${eventType}`);
    } catch (error) {
      console.error('Error logging security event:', error);
    }
  }

  // Get user security profile
  async getUserSecurityProfile(userId) {
    try {
      const profile = {
        trustScore: 100,
        flags: [],
        lastActivity: null,
        riskLevel: 'low'
      };

      // Get security events for user
      const events = await this.db.collection('security_events')
        .where('details.userId', '==', userId)
        .orderBy('timestamp', 'desc')
        .limit(20)
        .get();

      if (!events.empty) {
        const eventCount = events.docs.length;
        const highSeverityEvents = events.docs.filter(doc =>
          doc.data().details.severity === 'high'
        ).length;

        // Calculate trust score
        profile.trustScore = Math.max(0, 100 - (eventCount * 2) - (highSeverityEvents * 10));
        profile.flags = events.docs.map(doc => ({
          type: doc.data().eventType,
          timestamp: doc.data().timestamp,
          severity: doc.data().details.severity
        }));

        if (profile.trustScore < 50) {
          profile.riskLevel = 'high';
        } else if (profile.trustScore < 75) {
          profile.riskLevel = 'medium';
        }
      }

      return profile;
    } catch (error) {
      console.error('Error getting user security profile:', error);
      return {
        trustScore: 100,
        flags: [],
        riskLevel: 'low'
      };
    }
  }
}

module.exports = new SecurityService();