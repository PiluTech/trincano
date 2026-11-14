# Cria (ou recria) o alvo TrincanoTests (Swift Testing, sem host) em Ice.xcodeproj.
# Uso: ruby scripts/add-test-target.rb   (requer: gem install --user-install xcodeproj)
Gem.paths = { "GEM_HOME" => Dir[File.expand_path("~/.gem/ruby/*")].first }
require "xcodeproj"

proj = Xcodeproj::Project.open("Ice.xcodeproj")
# Idempotente: recria o alvo e os grupos para refletir os arquivos atuais.
proj.targets.select { |t| t.name == "TrincanoTests" }.each do |t|
  # remove_from_project deixa as XCBuildConfiguration do alvo órfãs no pbxproj.
  configs = t.build_configuration_list.build_configurations.dup
  build_files = (t.source_build_phase.files + t.frameworks_build_phase.files).dup
  t.remove_from_project
  configs.each(&:remove_from_project)
  build_files.each(&:remove_from_project)
end
%w[Tests TestedSources].each do |n|
  g = proj.main_group[n]
  next unless g
  # remove_from_project do grupo deixa os PBXFileReference filhos órfãos no pbxproj.
  g.recursive_children.each(&:remove_from_project)
  g.remove_from_project
end

target = proj.new_target(:unit_test_bundle, "TrincanoTests", :osx, "14.0")
group = proj.main_group.new_group("Tests", "Tests")
tests_group = group.new_group("TrincanoTests", "TrincanoTests")

sources = Dir["Tests/TrincanoTests/*.swift"].sort
# Lógica pura compilada direto no alvo de testes (sem host, sem AppKit).
logic = Dir["Shared/Utilities/XPCPeerPolicy.swift", "Shared/Utilities/ActiveMenuBarDisplayResolver.swift", "Ice/Utilities/LayoutItemAccessibility.swift", "Ice/MenuBar/ControlItem/ControlItemImage.swift", "Ice/MenuBar/ControlItem/ControlItemImageSet.swift", "Ice/Utilities/ConcurrencyHelpers.swift"] + Dir["Ice/Utilities/Pure/*.swift"]

refs = sources.map { |f| tests_group.new_file(File.basename(f)) }
logic_group = proj.main_group.new_group("TestedSources", ".")
logic_refs = logic.map { |f| logic_group.new_file(f) }
target.add_file_references(refs + logic_refs)

target.build_configurations.each do |c|
  s = c.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"] = "br.com.pilutech.trincano.tests"
  s["PRODUCT_NAME"] = "$(TARGET_NAME)"
  s["SWIFT_VERSION"] = "6.0"
  s["GENERATE_INFOPLIST_FILE"] = "YES"
  s["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
  s["CODE_SIGN_STYLE"] = "Manual"
  s["CODE_SIGN_IDENTITY"] = "-"
  s["DEVELOPMENT_TEAM"] = ""
end
proj.save

scheme = Xcodeproj::XCScheme.new
scheme.add_test_target(target)
scheme.save_as("Ice.xcodeproj", "TrincanoTests", true)
puts "ok"
