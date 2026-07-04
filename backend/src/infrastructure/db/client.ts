/**
 * Client Prisma (ORM) pour la base de données PostgreSQL.
 *
 * Instance unique partagée dans toute l'application.
 * En développement, les requêtes SQL sont loggées pour le débogage.
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'warn', 'error'] : ['error'],
});

export default prisma;
