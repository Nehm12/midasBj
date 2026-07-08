import { Prisma } from '@prisma/client';
import prisma from '../../infrastructure/db/client.js';

export interface WorkflowTransition {
  to: string;
  condition?: (ctx: Record<string, unknown>) => boolean | Promise<boolean>;
  onTransition?: (ctx: Record<string, unknown>) => void | Promise<void>;
}

export interface WorkflowState {
  name: string;
  transitions: WorkflowTransition[];
  onEnter?: (ctx: Record<string, unknown>) => void | Promise<void>;
}

export interface WorkflowDefinitionConfig {
  name: string;
  version: number;
  states: WorkflowState[];
}

export class WorkflowEngine {
  private definitions = new Map<string, WorkflowDefinitionConfig>();

  register(def: WorkflowDefinitionConfig) {
    const keys = def.states.map(s => s.name);
    for (const state of def.states) {
      for (const t of state.transitions) {
        if (!keys.includes(t.to)) {
          throw new Error(
            `Transition target "${t.to}" not found in states ${JSON.stringify(keys)}`,
          );
        }
      }
    }
    this.definitions.set(def.name, def);
  }

  private getDef(name: string): WorkflowDefinitionConfig {
    const def = this.definitions.get(name);
    if (!def) throw new Error(`Workflow definition "${name}" not registered`);
    return def;
  }

  private getState(name: string, def: WorkflowDefinitionConfig): WorkflowState {
    const state = def.states.find(s => s.name === name);
    if (!state) throw new Error(`State "${name}" not found in workflow "${def.name}"`);
    return state;
  }

  async createInstance(definitionName: string, consentId: string, context: Record<string, unknown>) {
    const def = this.getDef(definitionName);
    const initialState = def.states[0];
    if (!initialState) throw new Error('Workflow has no states');

    const definition = await prisma.workflowDefinition.findUnique({ where: { name: definitionName } });
    if (!definition) {
      await prisma.workflowDefinition.create({
        data: {
          name: definitionName,
          version: def.version,
          states: JSON.parse(JSON.stringify(def.states.map(s => ({ name: s.name, transitions: s.transitions.map(t => ({ to: t.to })) })))),
          transitions: JSON.parse(JSON.stringify(def.states.flatMap(s => s.transitions.map(t => ({ from: s.name, to: t.to }))))),
        },
      });
    }

    const instance = await prisma.workflowInstance.create({
      data: {
        definitionId: definition?.id ?? (await prisma.workflowDefinition.findUniqueOrThrow({ where: { name: definitionName } })).id,
        consentId,
        currentState: initialState.name,
        context: context as Prisma.InputJsonValue,
        history: JSON.stringify([{ from: null, to: initialState.name, at: new Date().toISOString() }]),
      },
    });

    if (initialState.onEnter) {
      await initialState.onEnter(context);
    }

    return instance;
  }

  async transition(instanceId: string, targetState?: string) {
    const instance = await prisma.workflowInstance.findUniqueOrThrow({
      where: { id: instanceId },
      include: { definition: true },
    });

    const def = this.getDef(instance.definition.name);
    const currentState = this.getState(instance.currentState, def);
    const ctx = instance.context as Record<string, unknown>;

    let nextState: string | undefined;

    if (targetState) {
      const valid = currentState.transitions.some(t => t.to === targetState);
      if (!valid) {
        throw new Error(
          `Transition from "${instance.currentState}" to "${targetState}" not allowed`,
        );
      }
      nextState = targetState;
    } else {
      const automatic = currentState.transitions.find(t => !t.condition);
      if (automatic) nextState = automatic.to;
    }

    if (!nextState) {
      for (const t of currentState.transitions) {
        if (t.condition) {
          const pass = await Promise.resolve(t.condition(ctx));
          if (pass) {
            nextState = t.to;
            if (t.onTransition) await Promise.resolve(t.onTransition(ctx));
            break;
          }
        }
      }
    }

    if (!nextState) {
      throw new Error(`No valid transition from "${instance.currentState}" in workflow "${def.name}"`);
    }

    const history = JSON.parse(instance.history as string);
    history.push({ from: instance.currentState, to: nextState, at: new Date().toISOString() });

    const updated = await prisma.workflowInstance.update({
      where: { id: instanceId },
      data: {
        currentState: nextState,
        context: ctx as Prisma.InputJsonValue,
        history: JSON.stringify(history),
      },
    });

    const nextStateDef = this.getState(nextState, def);
    if (nextStateDef.onEnter) {
      await Promise.resolve(nextStateDef.onEnter(ctx));
    }

    return updated;
  }

  async getInstance(instanceId: string) {
    return prisma.workflowInstance.findUniqueOrThrow({
      where: { id: instanceId },
      include: { definition: true },
    });
  }

  async getInstanceByConsent(consentId: string) {
    return prisma.workflowInstance.findUniqueOrThrow({
      where: { consentId },
      include: { definition: true },
    });
  }
}

export const workflowEngine = new WorkflowEngine();
