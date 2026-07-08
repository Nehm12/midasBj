import { workflowEngine, WorkflowDefinitionConfig } from './engine.js';

export const CONSENT_WORKFLOW = 'consent-workflow';

const consentWorkflow: WorkflowDefinitionConfig = {
  name: CONSENT_WORKFLOW,
  version: 1,
  states: [
    {
      name: 'REQUESTED',
      transitions: [
        { to: 'PENDING_REVIEW' },
      ],
    },
    {
      name: 'PENDING_REVIEW',
      transitions: [
        {
          to: 'GRANTED',
          condition: (ctx) => ctx['signature'] !== undefined && ctx['signature'] !== '',
        },
        {
          to: 'DENIED',
          condition: (ctx) => ctx['denied'] === true,
        },
      ],
    },
    {
      name: 'GRANTED',
      onEnter: async (ctx) => {
        const { activateConsent } = await import('../../modules/consent/consent.service.js');
        await activateConsent(ctx['consentId'] as string);
      },
      transitions: [
        {
          to: 'ACTIVE',
          condition: () => true,
        },
      ],
    },
    {
      name: 'ACTIVE',
      transitions: [
        {
          to: 'REVOKED',
          condition: (ctx) => ctx['revoked'] === true,
        },
        {
          to: 'EXPIRED',
          condition: (ctx) => {
            const expiresAt = ctx['expiresAt'] as number | undefined;
            return expiresAt !== undefined && Date.now() > expiresAt;
          },
        },
        {
          to: 'COMPLETED',
          condition: (ctx) => {
            const consentType = ctx['consentType'] as string;
            const usageCount = (ctx['usageCount'] as number) || 0;
            const maxUsage = (ctx['maxUsageCount'] as number) || 1;
            return consentType === 'SINGLE_USE' && usageCount >= maxUsage;
          },
        },
      ],
    },
    {
      name: 'REVOKED',
      transitions: [],
    },
    {
      name: 'EXPIRED',
      transitions: [],
    },
    {
      name: 'DENIED',
      transitions: [],
    },
    {
      name: 'COMPLETED',
      transitions: [],
    },
  ],
};

workflowEngine.register(consentWorkflow);

export default consentWorkflow;
