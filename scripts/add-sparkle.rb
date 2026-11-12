# Adiciona o pacote Sparkle (versão exata) ao alvo Ice. Idempotente.
# Uso: ruby scripts/add-sparkle.rb   (requer: gem install --user-install xcodeproj)
Gem.paths = { "GEM_HOME" => Dir[File.expand_path("~/.gem/ruby/*")].first }
require "xcodeproj"

VERSION = "2.10.1"
URL = "https://github.com/sparkle-project/Sparkle"
proj = Xcodeproj::Project.open("Ice.xcodeproj")
target = proj.targets.find { |t| t.name == "Ice" } or abort "alvo Ice não achado"

ref = proj.root_object.package_references.find { |r| r.repositoryURL == URL }
unless ref
  ref = proj.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  ref.repositoryURL = URL
  ref.requirement = { "kind" => "exactVersion", "version" => VERSION }
  proj.root_object.package_references << ref
end
ref.requirement = { "kind" => "exactVersion", "version" => VERSION }

unless target.package_product_dependencies.any? { |d| d.product_name == "Sparkle" }
  dep = proj.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.product_name = "Sparkle"
  dep.package = ref
  target.package_product_dependencies << dep
  bf = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf.product_ref = dep
  target.frameworks_build_phase.files << bf
end
proj.save
puts "ok"
