// Small stdlib-only helpers a one-off Node glue script might use.

const { execSync } = require("child_process");

function run(command) {
  return execSync(command).toString().trim();
}

function logInfo(message) {
  console.log(`[info] ${message}`);
}

module.exports = { run, logInfo };
