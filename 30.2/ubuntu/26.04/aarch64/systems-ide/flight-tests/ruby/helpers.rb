# Small stdlib-only helpers a Chef-recipe-style deployment script might use.

module Helpers
  def self.run(command)
    `#{command}`.strip
  end

  def self.ensure_package(name)
    puts "would ensure package installed: #{name}"
  end
end
