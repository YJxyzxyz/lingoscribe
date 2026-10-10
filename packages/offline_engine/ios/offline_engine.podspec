Pod::Spec.new do |s|
  s.name = 'offline_engine'
  s.version = '0.1.0'
  s.summary = 'Local Whisper transcription and audio decoding for LingoScribe.'
  s.description = s.summary
  s.homepage = 'https://github.com/YJxyzxyz/lingoscribe'
  s.license = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author = 'LingoScribe contributors'
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.resource_bundles = { 'offline_engine_privacy' => ['Classes/PrivacyInfo.xcprivacy'] }
  s.vendored_frameworks = 'Frameworks/LingoWhisper.xcframework'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.swift_version = '5.0'
  s.frameworks = 'AVFoundation', 'Accelerate'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'OTHER_LDFLAGS' => '$(inherited) -Wl,-u,_ls_job_create -Wl,-u,_ls_job_create_v2 -Wl,-u,_ls_job_run -Wl,-u,_ls_job_progress -Wl,-u,_ls_job_phase -Wl,-u,_ls_job_cancel -Wl,-u,_ls_job_result -Wl,-u,_ls_job_free' }
end
