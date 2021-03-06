Pod::Spec.new do |s|
  s.name                    = "OptimizelySDKShared"
  s.version                 = "1.4.0"
  s.summary                 = "Optimizely server-side testing shared framework."
  s.homepage                = "http://developers.optimizely.com/server/reference/index.html?language=objectivec"
  s.license                 = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  s.author                  = { "Optimizely" => "support@optimizely.com" }
  s.ios.deployment_target   = "8.0"
  s.tvos.deployment_target  = "9.0"
  s.source                  = {
    :git => "https://github.com/optimizely/objective-c-sdk.git",
    :tag => "shared-"+s.version.to_s
  }
  s.source_files            = "OptimizelySDKShared/OptimizelySDKShared/*.{h,m}"
  s.tvos.exclude_files      = "OptimizelySDKShared/OptimizelySDKShared/OPTLYDatabase.{h,m}",\
                              "OptimizelySDKShared/OptimizelySDKShared/OPTLYDatabaseEntity.{h,m}"
  s.public_header_files     = "OptimizelySDKShared/OptimizelySDKShared/*.h"
  s.framework               = "Foundation"
  s.requires_arc            = true
  s.xcconfig                = { 'GCC_PREPROCESSOR_DEFINITIONS' => "OPTIMIZELY_SDK_SHARED_VERSION=@\\\"#{s.version}\\\"" }
  s.dependency 'OptimizelySDKCore', '1.4.0'
end
