# encoding: UTF-8

require 'json'
require 'yaml'
require 'optparse'
require 'xcodeproj'
require 'helpers/objc_dependency_tree_generator_helper'

class LeafNodesFileListGenerator

	def self.parse_command_line_options
	    options = {}

	    # Defaults
	    options[:object_files_dir] = '~/Library/Developer/Xcode/DerivedData/'
	    options[:project_files_dir] = '~/tinder_ios'
	    options[:project_name] = ''
	    options[:input_json] = ''

	    OptionParser.new do |o|
			o.separator 'General options:'
			o.on('-D DERIVED_DATA', 'Path to directory where DerivedData is') do |f|
				options[:object_files_dir] = f
			end
			o.on('-s PROJECT_NAME', 'Search project .o files by specified project name') do |f|
				options[:project_name] = f
			end
			o.on('-p PATH', '--project-path', 'Path to directory where tinder_ios repo at') do |f|
				options[:project_files_dir] = f
			end
			o.on('-i FILENAME', '--input-dep-tree-json', 'Path to file where are your json file from generate-objc-dependencies-to-json command') do |f|
				options[:input_json] = f
			end
			o.separator 'Common options:'
			o.on_tail('-h', 'Prints this help') do
				puts o
				exit
			end
	    	o.parse!
    	end

    	options
  	end

  	def initialize(options)
		@options = options
		@object_files_dir = @options[:object_files_dir]
		@project_files_dir = @options[:project_files_dir]
		@project_name = @options[:project_name]
		@input_json = @options[:input_json]
	end

	# path of .swiftdeps files of each class in the project
	def swift_deps_files_in_dir(object_files_dirs)
		dirs = Array(object_files_dirs)
		dirs.each do |dir|
		  Dir.glob("#{dir}/*.swiftdeps") { |file| yield file }
		end
	end

	# path of the swift file for the filename
	def find_file_in_dir(object_files_dirs, filename)
		dirs = Array(object_files_dirs)
		dirs.each do |dir|
		  Dir.glob("#{dir}/#{filename}.swift") { |file| yield file }
		  Dir.glob("#{dir}/*/#{filename}.swift") { |file| yield file }
		end
	end

	def xcode_proj_pharser
		project_files_dir = @project_files_dir
		project_path = project_files_dir + '/Projects/Tinder/Tinder.xcodeproj'
		project = Xcodeproj::Project.open(File.expand_path(project_path))
		target = project.targets.select{ |p| p.name == 'Tinder' }.first
		hierarchy_path = {}
		files = target.source_build_phase.files.to_a.map do |pbx_build_file|
			pbx_build_file.file_ref.hierarchy_path.to_s
		end.select do |path|
		  next if !path.end_with?(".m", ".mm", ".swift")
		  baseName = File.basename(path)
		  hierarchy_path[baseName] = path
		  #$stderr.puts path
		end
		hierarchy_path
	end

	def generate_list

		object_files_dir = @object_files_dir
		project_files_dir = @project_files_dir
		project_name = @project_name
		input_json = @input_json

		derive_data_dir = find_project_output_directory(
			[object_files_dir],
			project_name,
			'*',
			[],
			true
		)

		tinder_files_dir = "/Projects/Tinder/Tinder"
		sharedsource_files_dir = "/Projects/Tinder/SharedSource"

		file = File.open(File.expand_path(input_json), 'r')
		data = JSON.load file

# testing json
#json = <<'JSON_STRING'
#	{"links":[
#		{"source": "ChatViewController", "dest": "ChatViewControllerDelegate"}
#	 ],
#	 "objects":{
#	 	"ChatViewController": {"type":"unknown"},
#	 	"ChatViewControllerDelegate": {"type":"unknown"},
#	 	"ChatUserTitleView": {"type":"unknown"}
#	 }
#	}
#JSON_STRING

#data = JSON.parse json
# end testing json

		objects = data["objects"].keys
		links = data["links"]

		leaveNodes = {}

		objects.each do |object|
		  found = links.map(&:values).select { |source, dest| source == object }.map(&:first)
		  if found.length == 0
		  	dependentNodesCount = links.map(&:values).select { |source, dest| dest == object }.length
		  	next if dependentNodesCount == 0
		  	$stderr.puts 'found leaveNode - ' + object + ', ' + dependentNodesCount.to_s + ' nodes depends on'
		  	#leaveNodes << {"name": object, "dependent": dependentNodesCount}
		  	leaveNodes[object] = dependentNodesCount
		  end
		end

		hierarchy_path = xcode_proj_pharser

		# finds file paths leaf nodes are declare in
		filePaths = []
		swift_deps_files_in_dir(derive_data_dir) do |swiftdeps_file|
			# puts swiftdeps_file
			begin
				dependencies = YAML.load_file(swiftdeps_file)
			rescue Exception => e
				$stderr.puts 'Cannot read file  ' + swiftdeps_file + ' : This is possibly because output file was changed:' + e.message
				next
			end

			provided_objs = dependencies['provides']
			top_level_deps = dependencies['top-level']

			# support Xcode 7 format
			provided_objs = dependencies['provides-top-level'] if provided_objs.nil?
			top_level_deps = dependencies['depends-top-level'] if top_level_deps.nil?

			next if provided_objs.nil?
			next if top_level_deps.nil?

		  	filename = File.basename(swiftdeps_file, '.swiftdeps')
			provided_objs.each do |source|
				next if leaveNodes[source].nil?
				#next if fileNames.include? filename
				#$stderr.puts 'found fileName - ' + filename
				find_file_in_dir(File.expand_path(project_files_dir + tinder_files_dir), filename) do |found_file|
					filePath = found_file.gsub(project_files_dir, "")
					baseName = File.basename(found_file)
					groupPath = hierarchy_path[baseName]
					groupDir = File.dirname(groupPath)
					$stderr.puts 'found path - ' + filePath
					filePaths << {"path": filePath, "group_path": groupPath, "group_dir": groupDir, "name": source, "dependent": leaveNodes[source]}
				end

				find_file_in_dir(File.expand_path(project_files_dir + sharedsource_files_dir), filename) do |found_file|
					filePath = found_file.gsub(project_files_dir, "")
					baseName = File.basename(found_file)
					groupPath = hierarchy_path[baseName]
					groupDir = File.dirname(groupPath)
					$stderr.puts 'found path - ' + filePath
					filePaths << {"path": filePath, "group_path": groupPath, "group_dir": groupDir, "name": source, "dependent": leaveNodes[source]}
				end
				
			end
		end

		filePaths.map{|y| y[:group_path] + "\t" + y[:group_dir] + "\t" + y[:name] + "\t" + y[:dependent].to_s}.reduce("File Group Path\tFile Group Dir\tNode Name\tDepends by"){|output, line| output + "\n" + line}
	end

end
