Pod::Spec.new do |s|
  s.name     = 'SCStackViewController'
  s.version  = '3.3.3'
  s.platform = :ios
  s.ios.deployment_target = '5.0'

  s.summary  = 'SCStackViewController is a container controller which allows you to stack other view controllers and build custom transitions between them.'
  s.description = <<-DESC
                  SCStackViewController is a generic container view controller which allows you to stack child view controllers on the top/left/bottom/right of the root and build custom transitions between them while providing correct physics and appearance calls, custom layouts, easing functions, custom navigation steps and more.
                  DESC
  s.homepage = 'https://github.com/stefanceriu/SCStackViewController'
  s.author   = { 'Stefan Ceriu' => 'stefan.ceriu@yahoo.com' }
  s.social_media_url = 'https://twitter.com/stefanceriu'
  s.source   = { :git => 'https://github.com/stefanceriu/SCStackViewController.git', :tag => "v#{s.version}" }
  s.license      = { :type => 'MIT License', :file => 'LICENSE' }
  s.source_files = 'SCStackViewController/*', 'SCStackViewController/Layouters/*'
  s.requires_arc = true

  s.dependency 'SCScrollView', '~> 1.1'

end