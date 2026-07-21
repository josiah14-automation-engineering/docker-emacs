// Flight-test for systems-ide's JavaScript glue-script tier.
//
// Plain Node/CommonJS -- not GJS. GNOME Shell extension scripting uses a
// different binding system (imports.gi.*, GObject Introspection) that a
// stock typescript-language-server doesn't understand regardless of
// project structure; that's a separate concern from what this
// flight-test demonstrates (see BUILDLOG.md).

const utils = require("./utils");

const services = ["nginx", "app"];

utils.logInfo(`hostname: ${utils.run("hostname")}`);
services.forEach((service) => utils.logInfo(`would restart: ${service}`));
