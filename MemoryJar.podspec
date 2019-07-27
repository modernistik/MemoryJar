#
# Be sure to run `pod lib lint MemoryJar.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MemoryJar'
  s.version          = '0.1.0'
  s.summary          = 'Fast, efficient and thread-safe persistent string caching for Swift.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Two layer persistent string caching library with capacity management through LRU collector. Designed for async-writes and blocking-reads.
                       DESC

  s.homepage         = 'https://github.com/modernistik/MemoryJar'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Anthony Persaud' => 'persaud@modernistik.com' }
  s.source           = { :git => 'https://github.com/modernistik/MemoryJar.git', :tag => s.version.to_s }
  s.social_media_url = 'https://www.modernistik.com/'

  s.ios.deployment_target = '10.0'
  s.swift_version = ["4.2", "5.0"]

  s.source_files = 'MemoryJar/**/*'
  
end

# To publish `pod trunk push MemoryJar.podspec`
# https://guides.cocoapods.org/making/getting-setup-with-trunk.html
# Register a new authentication token: pod trunk register <email> '<firstname> <lastname>' --description='Macbook'
