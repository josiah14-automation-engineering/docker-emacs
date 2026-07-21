// Small stdlib-only helpers a one-off Node/TypeScript glue script might
// use -- typed so ts-ls's static checking has something real to enforce
// (see flight-tests/javascript/utils.js for the untyped JS-tier
// equivalent this mirrors).

import { execSync } from "child_process";

export interface PackageStatus {
  name: string;
  installed: boolean;
}

export function run(command: string): string {
  return execSync(command).toString().trim();
}

export function logInfo(message: string): void {
  console.log(`[info] ${message}`);
}

export function checkPackage(name: string): PackageStatus {
  return { name, installed: true };
}
