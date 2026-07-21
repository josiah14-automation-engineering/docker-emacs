# Flight-test for systems-ide's Ruby glue-script tier.
#
# Mirrors a Chef-recipe-style deployment script: plain Ruby only, no chef
# gem dependency, matching this tier's no-project/no-dependency-manager
# scope.

require_relative "helpers"

PACKAGES = %w[nginx app].freeze

puts "hostname: #{Helpers.run('hostname')}"
PACKAGES.each { |pkg| Helpers.ensure_package(pkg) }
