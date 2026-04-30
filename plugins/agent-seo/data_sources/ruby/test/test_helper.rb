# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'agent_seo'
require 'json'

# Test helper methods
module TestHelpers
  # Load a fixture file from the fixtures directory
  #
  # @param filename [String] Name of the fixture file
  # @return [String] Contents of the fixture file
  def fixture(filename)
    File.read(File.join(__dir__, 'fixtures', filename))
  end

  # Load and parse a JSON fixture file
  #
  # @param filename [String] Name of the JSON fixture file
  # @return [Hash, Array] Parsed JSON data
  def json_fixture(filename)
    JSON.parse(fixture(filename))
  end
  def sample_good_content
    <<~CONTENT
      # How to Start a Podcast in 2024: Complete Guide

      Starting a podcast has never been easier. In this comprehensive guide, you'll learn exactly how to start a podcast from scratch, covering everything from equipment to distribution.

      ## Why Start a Podcast?

      Podcasting continues to grow in popularity. Here's why you should start a podcast today:

      - Build an engaged audience
      - Establish thought leadership
      - Create passive income streams
      - Connect with industry experts

      ## Essential Podcast Equipment

      To start a podcast, you need quality equipment. Here's what you'll need:

      1. A good microphone (USB or XLR)
      2. Headphones for monitoring
      3. Recording software
      4. Pop filter and microphone stand

      ## Choosing Your Podcast Topic

      When you start a podcast, topic selection is crucial. Consider:

      - Your expertise and passion
      - Audience demand
      - Competition analysis
      - Long-term sustainability

      ## Recording Your First Episode

      Ready to start a podcast recording? Follow these steps:

      1. Write an outline
      2. Set up your recording space
      3. Do a test recording
      4. Record your episode
      5. Edit and polish

      ## Publishing and Distribution

      After recording, you need to publish. Most podcast hosting platforms make this easy.

      ## Conclusion

      Now you know how to start a podcast. Take action today and begin your podcasting journey!

      [Start your free trial](https://example.com/trial) to begin hosting your podcast.
    CONTENT
  end

  def sample_poor_content
    'Short content without structure.'
  end
end
