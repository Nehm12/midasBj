-- CreateEnum
CREATE TYPE "ConsentType" AS ENUM ('TEMPORARY', 'PERMANENT', 'SINGLE_USE');

-- AlterTable: IoTData — ajouter colonnes manquantes
ALTER TABLE "IoTData" ADD COLUMN "payloadType" TEXT NOT NULL DEFAULT 'telemetry';
ALTER TABLE "IoTData" ADD COLUMN "metricName" TEXT;
ALTER TABLE "IoTData" ADD COLUMN "metricValue" DOUBLE PRECISION;
ALTER TABLE "IoTData" ADD COLUMN "unit" TEXT;

-- AlterTable: Consent — ajouter colonnes manquantes
ALTER TABLE "Consent" ADD COLUMN "consentType" "ConsentType" NOT NULL DEFAULT 'TEMPORARY';
ALTER TABLE "Consent" ADD COLUMN "usageCount" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Consent" ADD COLUMN "maxUsageCount" INTEGER NOT NULL DEFAULT 1;

-- CreateTable: IoTThreshold
CREATE TABLE "IoTThreshold" (
    "id" UUID NOT NULL,
    "deviceId" UUID NOT NULL,
    "metric" TEXT NOT NULL,
    "minValue" DOUBLE PRECISION,
    "maxValue" DOUBLE PRECISION,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "IoTThreshold_pkey" PRIMARY KEY ("id")
);

-- CreateTable: IoTAlert
CREATE TABLE "IoTAlert" (
    "id" UUID NOT NULL,
    "deviceId" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "severity" TEXT NOT NULL DEFAULT 'INFO',
    "message" TEXT NOT NULL,
    "metric" TEXT,
    "value" DOUBLE PRECISION,
    "threshold" DOUBLE PRECISION,
    "read" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IoTAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable: WorkflowDefinition
CREATE TABLE "WorkflowDefinition" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "states" JSONB NOT NULL,
    "transitions" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WorkflowDefinition_pkey" PRIMARY KEY ("id")
);

-- CreateTable: WorkflowInstance
CREATE TABLE "WorkflowInstance" (
    "id" UUID NOT NULL,
    "definitionId" UUID NOT NULL,
    "consentId" UUID NOT NULL,
    "currentState" TEXT NOT NULL,
    "context" JSONB NOT NULL,
    "history" JSONB NOT NULL DEFAULT '[]',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WorkflowInstance_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "IoTThreshold_deviceId_metric_key" ON "IoTThreshold"("deviceId", "metric");
CREATE INDEX "IoTAlert_deviceId_createdAt_idx" ON "IoTAlert"("deviceId", "createdAt");
CREATE INDEX "IoTAlert_read_idx" ON "IoTAlert"("read");
CREATE UNIQUE INDEX "WorkflowDefinition_name_key" ON "WorkflowDefinition"("name");
CREATE INDEX "WorkflowInstance_currentState_idx" ON "WorkflowInstance"("currentState");
CREATE INDEX "IoTData_deviceId_receivedAt_idx" ON "IoTData"("deviceId", "receivedAt");
CREATE INDEX "IoTData_deviceId_metricName_idx" ON "IoTData"("deviceId", "metricName");

-- AddForeignKey
ALTER TABLE "IoTThreshold" ADD CONSTRAINT "IoTThreshold_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "IoTDevice"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "IoTAlert" ADD CONSTRAINT "IoTAlert_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "IoTDevice"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "WorkflowInstance" ADD CONSTRAINT "WorkflowInstance_definitionId_fkey" FOREIGN KEY ("definitionId") REFERENCES "WorkflowDefinition"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "WorkflowInstance" ADD CONSTRAINT "WorkflowInstance_consentId_fkey" FOREIGN KEY ("consentId") REFERENCES "Consent"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: Consent → WorkflowInstance (via workflow relation)
-- Note: WorkflowInstance.consentId is already unique, FK added above
