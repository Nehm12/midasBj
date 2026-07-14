/**
 * Broker MQTT pour la communication avec les appareils IoT.
 *
 * Utilise Aedes (broker MQTT pur JavaScript) pour :
 * - Recevoir les publications des appareils sur midas/<deviceId>/telemetry
 * - Persister les données reçues dans PostgreSQL via Prisma
 * - Mettre à jour le timestamp lastSeenAt de l'appareil
 *
 * Supporte TCP (port 1883) et WebSocket (port 8084)
 * pour la compatibilité avec Render (qui bloque le TCP pur).
 */
import Aedes, { Client, PublishPacket } from 'aedes';
import { createServer } from 'net';
import { createServer as createHttpServer } from 'http';
import { WebSocketServer } from 'ws';
import { FastifyInstance } from 'fastify';
import config from '../../config/index.js';
import prisma from '../db/client.js';

const aedes = new Aedes();

export async function startMqttBroker(app: FastifyInstance) {
  // TCP server (port 1883) — pour les appareils IoT en local
  const tcpServer = createServer(aedes.handle);

  // WebSocket server (port 8084) — pour les apps mobiles / Render
  const httpServer = createHttpServer();
  const wss = new WebSocketServer({ noServer: true });

  httpServer.on('upgrade', (request, socket, head) => {
    wss.handleUpgrade(request, socket, head, (ws) => {
      aedes.handle(ws as any);
    });
  });

  aedes.on('client', (client: Client) => {
    app.log.info(`MQTT client connected: ${client.id}`);
  });

  aedes.on('publish', async (packet: PublishPacket, _client: Client | null) => {
    const topic = packet.topic;
    if (topic.startsWith('midas/') && topic.endsWith('/telemetry')) {
      try {
        const payload = JSON.parse(packet.payload.toString());
        const deviceId = topic.split('/')[1];
        await prisma.ioTData.create({
          data: {
            deviceId,
            encryptedPayload: payload.ciphertext ?? '',
            nonce: payload.nonce ?? '',
            signature: payload.signature ?? '',
          },
        });
        await prisma.ioTDevice.update({
          where: { deviceId },
          data: { lastSeenAt: new Date() },
        });
        app.log.info(`MQTT data ingested from ${deviceId}`);
      } catch (err) {
        app.log.warn({ err }, 'MQTT payload processing failed');
      }
    }
  });

  const wsPort = config.MQTT_PORT + 1;

  return new Promise<void>((resolve) => {
    tcpServer.listen(config.MQTT_PORT, () => {
      app.log.info(`MQTT broker (TCP) listening on port ${config.MQTT_PORT}`);
      httpServer.listen(wsPort, () => {
        app.log.info(`MQTT broker (WebSocket) listening on port ${wsPort}`);
        resolve();
      });
    });
  });
}
