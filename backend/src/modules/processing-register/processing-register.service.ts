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
