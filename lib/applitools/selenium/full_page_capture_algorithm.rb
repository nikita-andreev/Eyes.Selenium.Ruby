module Applitools::Selenium
  class FullPageCaptureAlgorithm
    extend Forwardable
    def_delegators 'Applitools::EyesLogger', :logger, :log_handler, :log_handler=

    MAX_SCROLL_BAR_SIZE = 50
    MIN_SCREENSHOT_PART_HEIGHT = 10


    def get_stiched_region(options = {})
      logger.info 'get_stiched_region() has been invoked.'
      image_provider = options[:image_provider]
      region_provider = options[:region_to_check]
      origin_provider = options[:origin_provider]
      position_provider = options[:position_provider]
      scale_provider = options[:scale_provider]
      cut_provider = options[:cut_provider]
      wait_before_screenshot = options[:wait_before_screenshots]
      eyes_screenshot_factory = options[:eyes_screenshot_factory]

      logger.info "Region to check: #{region_provider.region}"
      logger.info "Coordinates type: #{region_provider.coordinate_type}"

      original_position = origin_provider.state
      current_position = nil
      set_position_retries = 3
      while current_position.nil? || (current_position.x !=0 || current_position.y !=0) and set_position_retries > 0  do
        origin_provider.position = Applitools::Core::Location.new 0,0
        sleep wait_before_screenshot
        current_position = origin_provider.current_position
        set_position_retries = set_position_retries - 1
      end

      unless (current_position.x.zero? && current_position.y.zero?)
        origin_provider.restore_state original_position
        raise Applitools::EyesError.new 'Couldn\'t set position to the top/left corner!'
      end

      logger.info 'Getting top/left image...'
      image = image_provider.take_screenshot
      image = scale_provider.scale_image(image) if scale_provider
      image = cut_provider.cut(image) if cut_provider
      logger.info 'Done! Creating screenshot object...'
      screenshot = eyes_screenshot_factory.call(image)
      logger.info 'Done! Getting region in screenshot...'
      region_in_screenshot = screenshot.convert_region_location(region_provider.region, region_provider.coordinate_type, Applitools::Core::EyesScreenshot::COORDINATE_TYPES[:screenshot_as_is])
      logger.info "Done! region in screenshot: #{region_in_screenshot}"

      # Handling a specific case where the region is actually larger than
      # the screenshot (e.g., when body width/height are set to 100%, and
      # an internal div is set to value which is larger than the viewport).

      region_in_screenshot.intersect Applitools::Core::Region.new(0,0,image.width, image.height)
      logger.info "Region after intersect: #{region_in_screenshot}"

      image.crop!(region_in_screenshot.x,
                 region_in_screenshot.y,
                 region_in_screenshot.width,
                 region_in_screenshot.height) unless region_in_screenshot.empty?

      begin
        entire_size = position_provider.entire_size
        logger.info "Entire size of region context: #{entire_size}"
      rescue Applitools::EyesDriverOperationException => e
        logger.error "Failed to extract entire size of region context: #{e.message}"
        logger.error "Using image size instead: #{image.width}x#{image.height}"
        entire_size = Applitools::Core::RectangleSize.new image.width, image.height
      end

      # Notice that this might still happen even if we used
      # "getImagePart", since "entirePageSize" might be that of a frame.

      if image.width >= entire_size.width && image.height >= entire_size.height
        origin_provider.restore_state original_position
        return image
      end

      part_image_size = Applitools::Core::RectangleSize.new image.width, [image.height - MAX_SCROLL_BAR_SIZE, MIN_SCREENSHOT_PART_HEIGHT].max
      logger.info "Total size: #{entire_size}, image_part_size: #{part_image_size}"

      # Getting the list of sub-regions composing the whole region (we'll
      # take screenshot for each one).

      entire_page = Applitools::Core::Region.from_location_size Applitools::Core::Location::TOP_LEFT, entire_size
      image_parts = entire_page.sub_regions(part_image_size)


      logger.info "Creating stitchedImage container. Size: #{entire_size}"
      # Notice stitchedImage uses the same type of image as the screenshots.

      stitched_image = Applitools::Core::Screenshot.from_region entire_size
      logger.info "Done! Adding initial screenshot.."
      logger.info "Initial part:(0,0) [#{image.width} x #{image.height}]"

      stitched_image.replace! image, 0, 0
      logger.info "Done!"

      last_successful_location = Applitools::Core::Location.new 0, 0
      last_succesful_part_size = Applitools::Core::RectangleSize.new image.width, image.height

      original_stitched_state = position_provider.state

      logger.info 'Getting the rest of the image parts...'

      part_image = nil
      image_parts.each_with_index do |part_region, i|
        if i > 0
          logger.info "Taking screenshot for #{part_region}"

          position_provider.position = part_region.location
          sleep wait_before_screenshot
          current_position = position_provider.current_position
          logger.info "Set position to #{current_position}"
          logger.info 'Getting image...'

          part_image = image_provider.take_screenshot
          part_image = scale_provider.scale_image part_image if scale_provider
          part_image = cut_provider.cut part_image if cut_provider

          logger.info 'Done!'

          part_image.crop!(region_in_screenshot.x,
                           region_in_screenshot.y,
                           region_in_screenshot.width,
                           region_in_screenshot.height) unless region_in_screenshot.empty?

          logger.info 'Stitching part into the image container...'

          stitched_image.replace! part_image, current_position.x, current_position.y
          logger.info 'Done!'

          last_successful_location = current_position

        end
      end

      last_succesful_part_size = Applitools::Core::RectangleSize.new part_image.width, part_image.height if part_image

      logger.info 'Stitching done!'

      position_provider.restore_state original_stitched_state
      origin_provider.restore_state original_position

      actual_image_width = last_successful_location.x + last_succesful_part_size.width
      actual_image_height = last_successful_location.y + last_succesful_part_size.height

      logger.info "Extracted entire size: #{entire_size}"
      logger.info "Actual stitched size: #{actual_image_width} x #{actual_image_height}"

      if (actual_image_width < stitched_image.width() || actual_image_height < stitched_image.height)
        logger.info 'Trimming unnecessary margins...'
        stitched_image.crop!(0,0,actual_image_width,actual_image_height)
        logger.info 'Done!'
      end

      stitched_image
    end
  end
end