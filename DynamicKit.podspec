Pod::Spec.new do |s|
  s.name        = 'DynamicKit'
  s.module_name = 'DynamicKit'
  s.version     = '1.0.0'
  s.summary     = 'A dynamic programming kit.'

  s.homepage    = 'https://github.com/Meniny/DynamicKit'
  s.license     = { type: 'MIT', file: 'LICENSE.md' }
  s.authors     = { 'Elias Abel' => 'admin@meniny.cn' }
  s.social_media_url = 'https://meniny.cn/'

  s.ios.deployment_target     = '8.0'
  s.osx.deployment_target     = '10.10'
  s.tvos.deployment_target    = '9.0'
  s.watchos.deployment_target = '2.0'

  s.requires_arc        = true
  s.source              = { git: 'https://github.com/Meniny/DynamicKit.git', tag: s.version.to_s }
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.1' }
  s.swift_version       = '4.1'

  # s.dependency "Jsonify"

  s.default_subspecs = 'Core', 'Eval', 'UIKit', 'Runtime', 'Mirror', 'HTTP', 'Boxing'

  # Core
  s.subspec 'Core' do |sp|
    sp.source_files  = 'DynamicKit/Core/**/*.swift'
  end

  # Eval
  s.subspec 'Eval' do |sp|
    sp.source_files  = 'DynamicKit/Eval/**/*.swift'
  end

  # UIKit Extensions
  s.subspec 'UIKit' do |sp|
    sp.source_files  = 'DynamicKit/UIKit/**/*.swift'
    sp.dependency      'DynamicKit/Eval'
  end

  # Runtime Extensions
  s.subspec 'Runtime' do |sp|
    sp.source_files  = 'DynamicKit/Runtime/**/*.swift'
  end

  # Mirror Extensions
  s.subspec 'Mirror' do |sp|
    sp.source_files  = 'DynamicKit/Mirror/**/*.swift'
  end

  # Boxing Extensions
  s.subspec 'Boxing' do |sp|
    sp.source_files  = 'DynamicKit/Boxing/**/*.swift'
  end

  # HTTP Extensions
  s.subspec 'HTTP' do |sp|
    sp.source_files  = 'DynamicKit/HTTP/**/*.swift'
    sp.dependency      'DynamicKit/Core'
  end

  # REPL Extensions
  # s.subspec 'REPL' do |sp|
  #   sp.source_files  = 'DynamicKit/REPL/**/*.swift'
  #   sp.dependency      'DynamicKit/Eval'
  # end
end
