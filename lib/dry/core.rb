# frozen_string_literal: true

require "im"

loader = Im::Loader.new.tap do |loader|
  root = File.expand_path("..", __dir__)
  loader.tag = "dry-core"
  loader.inflector = Im::GemInflector.new("#{root}/dry-core.rb")
  loader.push_dir(root)
  loader.ignore("#{root}/dry-core.rb")
  loader.inflector.inflect("namespace_dsl" => "NamespaceDSL")
end

loader.setup

require "dry/core/constants"

# :nodoc:
module loader::Dry
  # :nodoc:
  module Core
    include Constants

    class InvalidClassAttributeValueError < StandardError
      def initialize(name, value)
        super(
          "Value #{value.inspect} is invalid for class attribute #{name.inspect}"
        )
      end
    end

    class << self
      attr_accessor :loader
    end
  end

  # See dry/core/equalizer.rb
  unless singleton_class.method_defined?(:Equalizer)
    # Build an equalizer module for the inclusion in other class
    #
    # ## Credits
    #
    # Equalizer has been originally imported from the equalizer gem created by Dan Kubb
    #
    # @api public
    def self.Equalizer(*keys, **options)
      Core.loader::Dry::Core::Equalizer.new(*keys, **options)
    end
  end
end

loader::Dry::Core.loader = loader
