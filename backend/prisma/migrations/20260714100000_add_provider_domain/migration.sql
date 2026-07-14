-- AlterTable
ALTER TABLE "Consent" ADD COLUMN "providerDomain" TEXT;
ALTER TABLE "Consent" ALTER COLUMN "providerDID" SET DEFAULT '';
