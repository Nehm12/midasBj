/**
 * Système de collecte de logs pour la console APDP.
 *
 * Capture tous les événements significatifs du serveur :
 * - Requêtes HTTP entrantes/sortantes
 * - Événements d'audit
 * - Événements IoT (paire, télémétrie)
 * - Erreurs et warnings
 * - Événements d'authentification
 *
 * Les logs sont stockés en mémoire (buffer circulaire) et exposés via /api/v1/admin/logs.
 */
export interface LogEntry {
  id: string;
  timestamp: number;
  level: 'info' | 'warn' | 'error' | 'debug';
  category: 'http' | 'auth' | 'audit' | 'iot' | 'system' | 'admin';
  message: string;
  meta?: Record<string, unknown>;
}

const MAX_LOGS = 2000;
const logs: LogEntry[] = [];
let counter = 0;

function createLog(level: LogEntry['level'], category: LogEntry['category'], message: string, meta?: Record<string, unknown>): LogEntry {
  const entry: LogEntry = {
    id: `log_${++counter}_${Date.now()}`,
    timestamp: Date.now(),
    level,
    category,
    message,
    meta,
  };
  logs.push(entry);
  if (logs.length > MAX_LOGS) {
    logs.splice(0, logs.length - MAX_LOGS);
  }
  return entry;
}

export const logCollector = {
  info(category: LogEntry['category'], message: string, meta?: Record<string, unknown>) {
    return createLog('info', category, message, meta);
  },

  warn(category: LogEntry['category'], message: string, meta?: Record<string, unknown>) {
    return createLog('warn', category, message, meta);
  },

  error(category: LogEntry['category'], message: string, meta?: Record<string, unknown>) {
    return createLog('error', category, message, meta);
  },

  debug(category: LogEntry['category'], message: string, meta?: Record<string, unknown>) {
    return createLog('debug', category, message, meta);
  },

  getLogs(params: {
    level?: string;
    category?: string;
    from?: number;
    to?: number;
    search?: string;
    limit?: number;
    offset?: number;
  }) {
    let filtered = [...logs];

    if (params.level) {
      filtered = filtered.filter(l => l.level === params.level);
    }
    if (params.category) {
      filtered = filtered.filter(l => l.category === params.category);
    }
    if (params.from) {
      filtered = filtered.filter(l => l.timestamp >= params.from!);
    }
    if (params.to) {
      filtered = filtered.filter(l => l.timestamp <= params.to!);
    }
    if (params.search) {
      const s = params.search.toLowerCase();
      filtered = filtered.filter(l =>
        l.message.toLowerCase().includes(s) ||
        JSON.stringify(l.meta ?? {}).toLowerCase().includes(s)
      );
    }

    const total = filtered.length;
    const offset = params.offset ?? 0;
    const limit = params.limit ?? 100;
    const paginated = filtered.slice(offset, offset + limit);

    return { logs: paginated, total, offset, limit };
  },

  getStats() {
    const now = Date.now();
    const last1h = logs.filter(l => l.timestamp > now - 3600000);
    const last24h = logs.filter(l => l.timestamp > now - 86400000);

    const byLevel = {
      info: logs.filter(l => l.level === 'info').length,
      warn: logs.filter(l => l.level === 'warn').length,
      error: logs.filter(l => l.level === 'error').length,
      debug: logs.filter(l => l.level === 'debug').length,
    };

    const byCategory = {
      http: logs.filter(l => l.category === 'http').length,
      auth: logs.filter(l => l.category === 'auth').length,
      audit: logs.filter(l => l.category === 'audit').length,
      iot: logs.filter(l => l.category === 'iot').length,
      system: logs.filter(l => l.category === 'system').length,
      admin: logs.filter(l => l.category === 'admin').length,
    };

    return {
      total: logs.length,
      last1h: last1h.length,
      last24h: last24h.length,
      byLevel,
      byCategory,
      errors24h: last24h.filter(l => l.level === 'error').length,
      warnings24h: last24h.filter(l => l.level === 'warn').length,
    };
  },

  clear() {
    logs.length = 0;
    counter = 0;
  },
};
