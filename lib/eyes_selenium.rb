require 'pry'
module Applitools
  # @!visibility private
  class << self
    # @!visibility private
    def require_dir(dir)
      Dir[File.join(File.dirname(File.expand_path(__FILE__)), 'applitools', dir, '*.rb')].sort.each do |f|
        require f
      end
    end
  end

  # @!visibility private
  class EyesError < StandardError; end
  # @!visibility private
  class EyesAbort < EyesError; end
  # @!visibility private
  class EyesIllegalArgument < EyesError; end
  # @!visibility private
  class OutOfBoundsException < EyesError; end;
  # @!visibility private
  class EyesDriverOperationException < EyesError; end;
  # @!visibility private
  class EyesNotOpenException < EyesError; end;
  # @!visibility private
  class EyesCoordinateTypeConversionException < EyesError; end;

  # @!visibility private
  class AbstractMethodCalled < EyesError
    attr_accessor :method_name, :object

    def initialize(method_name, object)
      @method = method_name
      @object = object
      message = "Abstract method #{method_name} is called for #{object}. "\
          'You should override it in a descendant class.'
      super message
    end
  end

  # @!visibility private
  class TestFailedError < StandardError
    attr_accessor :test_results

    def initialize(message, test_results = nil)
      super(message)

      @test_results = test_results
    end
  end

  # @!visibility private
  class NewTestError < TestFailedError; end
end

require_relative 'applitools/method_tracer'
require_relative 'applitools/extensions'
require_relative 'applitools/version'

Applitools.require_dir 'core'
Applitools.require_dir 'base'
Applitools.require_dir 'utils'
Applitools.require_dir 'selenium'


require_relative 'applitools/eyes'
require_relative 'applitools/selenium_webdriver'
require_relative 'applitools/appium_driver'
require_relative 'applitools/watir_browser'
require_relative 'applitools/images'


# module Applitools
#   extend self
#   @initialized = nil
#
#   def initialize_applitools
#     unless @initialized
#       @initialized = true
#       binding.pry
#       if defined? Sauce
#         require 'applitools/sauce'
#       elsif defined? Capybara
#         p "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1"
#         require 'applitools/capybara'
#       end
#     end
#   end
# end
#
