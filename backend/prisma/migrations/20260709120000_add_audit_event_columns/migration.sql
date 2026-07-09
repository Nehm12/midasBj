-- AlterTable
ALTER TABLE "AuditEvent" ADD COLUMN "signKey" TEXT NOT NULL DEFAULT '';
ALTER TABLE "AuditEvent" ADD COLUMN "userSignature" TEXT;
ALTER TABLE "AuditEvent" ADD COLUMN "userDid" TEXT;
