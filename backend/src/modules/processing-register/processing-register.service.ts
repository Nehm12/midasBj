/**
 * Service du registre des traitements (RGPD).
 *
 * Permet aux contrôleurs de données d'enregistrer leurs traitements :
 * - controller : nom de l'organisation responsable
 * - purpose : finalité du traitement
 * - dataClasses : catégories de données traitées
 * - retention : durée de conservation en jours
 * - legalBasis : base légale du traitement
 */
import prisma from '../../infrastructure/db/client.js';

export const processingRegisterService = {
  async register(data: {
    controller: string;
    purpose: string;
    dataClasses: string[];
    retention: number;
    legalBasis: string;
  }) {
    return prisma.processingRegister.create({ data });
  },

  async list() {
    return prisma.processingRegister.findMany({
      orderBy: { createdAt: 'desc' },
    });
  },

  async getById(id: string) {
    return prisma.processingRegister.findUniqueOrThrow({ where: { id } });
  },
};
