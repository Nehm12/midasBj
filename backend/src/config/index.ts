/**
 * Configuration centralisée de l'application.
 *
 * Utilise Zod pour valider et typer les variables d'environnement.
 * Toutes les valeurs ont des defaults pour le développement.
 */
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  DATABASE_URL: z.string().default('postgresql://midas:midas@localhost:5432/midasbenin'),
  KEYCLOAK_URL: z.string().default('http://localhost:8080'),
  KEYCLOAK_REALM: z.string().default('midas-benin'),
  KEYCLOAK_CLIENT_ID: z.string().default('mobile-app'),
  KEYCLOAK_CLIENT_SECRET: z.string().default(''),
  KEYCLOAK_OIDC_URL: z.string().default('http://localhost:8080/realms/midas-benin'),
  MQTT_PORT: z.coerce.number().default(1883),
  MQTT_WS_PORT: z.coerce.number().default(8081),
  JWT_SECRET: z.string().default('dev-secret-change-in-production'),
  LOG_LEVEL: z.string().default('info'),
});

const config = envSchema.parse(process.env);
export type Config = z.infer<typeof envSchema>;
export default config;
