module Applitools::Selenium
  class ScrollPositionProvider
    extend Forwardable

    def_delegators 'Applitools::EyesLogger', :logger, :log_handler, :log_handler=

    def initialize(executor)
      self.executor = executor
    end

    ##
    # The scroll position of the current frame
    #
    #
    #

    def current_position
      logger.info 'current_position()'
      result = Applitools::Utils::EyesSeleniumUtils.current_scroll_position(executor)
      logger.info "Current position: #{result}"
      result
    rescue Applitools::EyesDriverOperationException => e
      raise 'Failed to extract current scroll position!'
    end

    def state
      current_position
    end

    def restore_state(value)
      self.position = value
    end

    def position=(value)
      logger.info "Scrolling to #{value}"
      Applitools::Utils::EyesSeleniumUtils.scroll_to(executor, value)
      logger.info("Done scrolling!");
    end

    alias scroll_to position=

    def entire_size
      result = Applitools::Utils::EyesSeleniumUtils.entire_page_size(executor)
      logger.info "Entire size: #{result}"
      result
    end

    private
    attr_accessor :executor

  end
end