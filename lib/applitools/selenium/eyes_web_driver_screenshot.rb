module Applitools::Selenium
  class EyesWebDriverScreenshot < Applitools::Core::EyesScreenshot

    SCREENSHOT_TYPES = {
        viewport: 'VIEPORT',
        entire_frame: 'ENTIRE_FRAME'
    }.freeze

    INIT_CALLBACKS = {
        [:driver, :screenshot_type, :frame_location_in_screenshot].sort => :initialize_main,
        [:driver].sort => :initialize_main,
        [:driver, :entire_frame_size].sort => :initialize_for_element

    }.freeze

    attr_accessor :driver

    class << self
      alias _new new

      def new(*args)
        image = args.shift
        raise Applitools::EyesIllegalArgument.new "image is expected to be Applitools::Core::Screenshot!" unless image.is_a? Applitools::Core::Screenshot
        if (options = args.first).is_a? Hash
          _new(image).tap do |obj|
             callback = INIT_CALLBACKS[options.keys.sort]
             if obj.respond_to? callback
               obj.send callback, options
             else
               raise Applitools::EyesIllegalArgument.new 'Can\'t find an appropriate initializer!'
             end
          end
        else
          raise Applitools::EyesIllegalArgument.new "#{self.class}.initialize(): Hash is expected as an argument!"
        end
      end
    end

    def initialize_for_element(options = {})
      Applitools::Core::ArgumentGuard.not_nil options[:driver], 'options[:driver]'
      Applitools::Core::ArgumentGuard.not_nil options[:entire_frame_size], 'options[:entire_frame_size]'
      entire_frame_size = options[:entire_frame_size]
      self.driver = options[:driver]
      self.frame_chain = driver.frame_chain
      self.screenshot_type = SCREENSHOT_TYPES[:entire_frame]
      self.scroll_position = Applitools::Core::Location.new 0,0
      self.frame_location_in_screenshot = Applitools::Core::Location.new 0,0
      self.frame_window = Applitools::Core::Region.new(0,0,entire_frame_size.width, entire_frame_size.height)
    end

    def initialize_main(options = {})
      # options = {screenshot_type: SCREENSHOT_TYPES[:viewport]}.merge options

      Applitools::Core::ArgumentGuard.hash options, 'options', [:driver]
      Applitools::Core::ArgumentGuard.not_nil options[:driver], 'options[:driver]'

      self.driver = options[:driver]
      self.position_provider = Applitools::Selenium::ScrollPositionProvider.new driver


      viewport_size = driver.default_content_viewport_size #method in driver?

      self.frame_chain = driver.frame_chain #method in driver? frame chain is in another branch
      unless frame_chain.size == 0
        frame_size = frame_chain.current_frame_size
      else
        begin
          frame_size = position_provider.entire_size
        rescue
          frame_size = viewport_size
        end
      end

      begin
        self.scroll_position = position_provider.current_position
      rescue
        self.scroll_position = Applitools::Core::Location.new(0,0)
      end

      unless options[:screenshot_type]
        if (image.width <= viewport_size.width && image.height <= viewport_size.height)
          self.screenshot_type = SCREENSHOT_TYPES[:viewport]
        else
          self.screenshot_type = SCREENSHOT_TYPES[:entire_frame]
        end
      else
        self.screenshot_type = options[:screenshot_type]
      end

      unless options[:frame_location_in_screenshot]
        if frame_chain.size > 0
          self.frame_location_in_screenshot =  calc_frame_location_in_screenshot
        else
          self.frame_location_in_screenshot = Applitools::Core::Location.new(0,0)
          frame_location_in_screenshot.offset Applitools::Core::Location.for(-scroll_position.x, -scroll_position.y) if
              screenshot_type == SCREENSHOT_TYPES[:viewport]
        end
      else
        self.frame_location_in_screenshot = options[:frame_location_in_screenshot] if options[:frame_location_in_screenshot]
      end

      logger.info 'Calculating frame window..'
      self.frame_window = Applitools::Core::Region.from_location_size(frame_location_in_screenshot, frame_size);
      frame_window.intersect Applitools::Core::Region.new(0, 0, image.width, image.height)

      raise Applitools::EyesException.new 'Got empty frame window for screenshot!' if
          (frame_window.width <= 0 || frame_window.height <= 0)

      logger.info 'Done!'
    end

    def convert_location(location, from, to)
      Applitools::Core::ArgumentGuard.not_nil location, 'location'
      Applitools::Core::ArgumentGuard.not_nil from, 'from'
      Applitools::Core::ArgumentGuard.not_nil to, 'to'

      result = Applitools::Core::Location.for location
      return result if from == to
      if frame_chain.size.zero? && screenshot_type == SCREENSHOT_TYPES[:entire_frame]
        if (from == Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_relative] ||
            from == Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_as_is]) &&
            to == Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is]
          result.offset frame_location_in_screenshot
        elsif from == Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is] &&
            (to == Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_relative] ||
             to == Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_as_is])
          result.offset_negative frame_location_in_screenshot
        end
      else
        case from
          when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_as_is]
            case to
              when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_relative]
                result.offset scroll_position
              when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is]
                result.offset frame_location_in_screenshot
            else
              raise Applitools::EyesCoordinateTypeConversionException.new "Can't convert coordinates from #{from} to #{to}"
            end
          when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_relative]
            case to
              when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is]
                # binding.pry
                result.offset_negative scroll_position
                # result.offset frame_location_in_screenshot
                # binding.pry
              when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_as_is]
                result.offset_negative scroll_position
            else
              raise Applitools::EyesCoordinateTypeConversionException.new "Can't convert coordinates from #{from} to #{to}"
            end
          when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is]
            case to
              when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_relative]
                result.offset_negative frame_location_in_screenshot
                result.offset scroll_position
              when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_as_is]
                result.offset_negative frame_location_in_screenshot
            else
              raise Applitools::EyesCoordinateTypeConversionException.new "Can't convert coordinates from #{from} to #{to}"
            end
        else
          raise Applitools::EyesCoordinateTypeConversionException.new "Can't convert coordinates from #{from} to #{to}"
        end
      end
      result
    end

    def frame_chain
      Applitools::Core::FrameChain.new other: @frame_chain
    end

    def intersected_region(region, original_coordinate_types, result_coordinate_types)
      return Applitools::Core::Region::EMPTY if region.empty?
      intersected_region = convert_region_location region, original_coordinate_types, Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is]

      case original_coordinate_types
        when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_as_is]
        when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_relative]
          intersected_region.intersect frame_window
        when Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is]
          intersected_region.intersect Applitools::Core::Region.new(0,0, image.width, image.height)
        else
          raise Applitools::EyesCoordinateTypeConversionException.new "Unknown coordinates type: #{original_coordinate_types}"
      end

      return intersected_region if intersected_region.empty?
      convert_region_location(intersected_region, Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is], result_coordinate_types)
    end

    def location_in_screenshot

    end

    def sub_screenshot(region, coordinate_type, throw_if_clipped = false)
      logger.info "get_subscreenshot(#{region}, #{coordinate_type}, #{throw_if_clipped})"
      Applitools::Core::ArgumentGuard.not_nil region, 'region'
      Applitools::Core::ArgumentGuard.not_nil coordinate_type, 'coordinate_type'

      as_is_subscreenshot_region = intersected_region region, coordinate_type, Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is]
      raise Applitools::OutOfBoundsException.new "Region #{region} (#{coordinate_type}) is out" \
        " of screenshot bounds [#{frame_window}]" if
          as_is_subscreenshot_region.empty? || (throw_if_clipped && !as_is_subscreenshot_region.size == region.size)

      sub_screenshot_image = Applitools::Core::Screenshot.new image.crop(as_is_subscreenshot_region.left,
        as_is_subscreenshot_region.top, as_is_subscreenshot_region.width,
        as_is_subscreenshot_region.height).to_datastream.to_blob

      context_as_is_region_location = convert_location as_is_subscreenshot_region.location,
                                                       Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is],
                                                       Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:context_as_is]


      frame_location_in_sub_screenshot = Applitools::Core::Location.new -context_as_is_region_location.x,
          -context_as_is_region_location.y
      result = self.class.new sub_screenshot_image, driver: driver, screenshot_type: screenshot_type,
                              frame_location_in_screenshot: frame_location_in_sub_screenshot

      logger.info 'Done!'
      result
    end

    private

    attr_accessor :position_provider, :frame_chain, :scroll_position, :screenshot_type, :frame_location_in_screenshot,
                  :frame_window

    def calc_frame_location_in_screenshot
      ##stub - need to implement
    end
  end
end