// Flight-test for systems-ide's TypeScript glue-script tier.
//
// Same shape as the JavaScript flight-test (script.js/utils.js) but with
// real type annotations and an interface, so ts-ls's static type
// checking -- the one capability plain JS can't exercise -- has
// something to actually catch. Plain Node/CommonJS-compatible source,
// no `tsc` build step, matching this tier's no-project-tooling scope.

import { run, logInfo, checkPackage, PackageStatus } from "./helpers";

const packages: string[] = ["nginx", "app"];

logInfo(`hostname: ${run("hostname")}`);

const statuses: PackageStatus[] = packages.map(checkPackage);
statuses.forEach((status) => logInfo(`${status.name}: ${status.installed}`));
