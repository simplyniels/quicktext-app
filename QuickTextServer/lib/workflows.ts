import { ApiError } from "./http";

export const workflows = {
  improve:
    "Überarbeite den Text klar, natürlich und präzise. Erhalte Bedeutung und Sprache. Gib nur den fertigen Text zurück.",
  calm:
    "Formuliere den Text ruhig, konstruktiv und respektvoll. Erhalte die Kernaussage. Gib nur den fertigen Text zurück.",
  emoji:
    "Erhalte den Text und ergänze wenige passende Emojis. Gib nur den fertigen Text zurück.",
} as const;

export type Workflow = keyof typeof workflows;

export function requireWorkflow(value: unknown): Workflow {
  if (typeof value !== "string" || !(value in workflows)) {
    throw new ApiError(400, "Unbekannter Workflow");
  }
  return value as Workflow;
}
