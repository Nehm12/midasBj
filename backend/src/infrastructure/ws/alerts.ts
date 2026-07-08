import { FastifyInstance } from 'fastify';
import { WebSocket } from 'ws';

const clients = new Set<WebSocket>();

export function broadcastAlert(alert: Record<string, unknown>) {
  const message = JSON.stringify({ type: 'ALERT', data: alert });
  for (const ws of clients) {
    if (ws.readyState === ws.OPEN) {
      ws.send(message);
    }
  }
}

export async function registerWebSocketRoutes(app: FastifyInstance) {
  app.get('/ws/alerts', { websocket: true }, (socket, _req) => {
    clients.add(socket);
    socket.send(JSON.stringify({ type: 'CONNECTED', message: 'Alert stream connected' }));

    socket.on('message', (raw) => {
      try {
        const msg = JSON.parse(raw.toString());
        if (msg.type === 'ping') {
          socket.send(JSON.stringify({ type: 'pong' }));
        }
      } catch {
        // ignore invalid messages
      }
    });

    socket.on('close', () => {
      clients.delete(socket);
    });
  });
}
