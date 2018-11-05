Pod::Spec.new do |s|
	s.name					= "ULDocument"
	s.version				= "1.1.1"
	s.license				= "MIT"
	s.homepage				= "https://github.com/soulmen/ULDocument.git"
	s.summary				= "A lightweight and iCloud-ready document class."
	s.author				= {
		"Ulysses GmbH & Co. KG" => "mail@the-soulmen.com"
	}
	s.source				= {
		:git => "https://github.com/soulmen/ULDocument.git",
		:tag => s.version.to_s
	}

	s.osx.deployment_target = "10.10"
	s.ios.deployment_target = "8.0"

	s.source_files			= "Source/**/*.{h,m}", "Header/*.h"
	s.public_header_files	= "Header/*.h"
	
	s.requires_arc			= true
end
