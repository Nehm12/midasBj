/**
 * Broker MQTT pour la communication avec les appareils IoT.
 *
 * Utilise Aedes (broker MQTT pur JavaScript) pour :
 * - Recevoir les publications des appareils sur midas/<deviceId>/telemetry
 * - Persister les données reçues dans PostgreSQL via Prisma
 * - Mettre à jour le timestamp lastSeenAt de l'appareil
 *
 * Les appareils doivent envoyer : { ciphertext, nonce, signature }
 */
import Aedes, { Client, PublishPacket } from 'aedes';
import { createServer } from 'node:net';
import { FastifyInstance } from 'fastify';
import config from '../../config/index.js';
import prisma from '../db/client.js';

const aedes = new Aedes();

export async function startMqttBroker(app: FastifyInstance) {
  const server = createServer(aedes.handle);

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

  return new Promise<void>((resolve) => {
    server.listen(config.MQTT_PORT, () => {
      app.log.info(`MQTT broker listening on port ${config.MQTT_PORT}`);
      resolve();
    });
  });
}
