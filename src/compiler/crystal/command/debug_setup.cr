# Implementation of the `crystal tool debug:setup` command
#
# Sets up LLDB debugging configuration for existing Crystal projects.

require "file_utils"
require "yaml"

class Crystal::Command
  private def debug_setup
    global = false
    force = false
    project_dir = Dir.current

    OptionParser.parse(@options) do |opts|
      opts.banner = <<-USAGE
        Usage: crystal tool debug:setup [options]

        Sets up LLDB debugging configuration for Crystal projects.

        This command creates or updates:
        - .vscode/launch.json - VSCode debug configurations
        - .vscode/tasks.json - VSCode build tasks
        - .vscode/crystal_formatters.py - LLDB formatters and custom commands

        With --global, also updates ~/.lldbinit to load formatters globally.

        Options:
        USAGE

      opts.on("--global", "Install formatters globally in ~/.lldbinit") do
        global = true
      end

      opts.on("-f", "--force", "Overwrite existing files") do
        force = true
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.unknown_args do |args|
        if !args.empty?
          project_dir = args[0]
        end
      end
    end

    setup_command = DebugSetupCommand.new(project_dir, global, force, @color)
    setup_command.run
  end

  class DebugSetupCommand
    @project_dir : String
    @global : Bool
    @force : Bool
    @color : Bool

    def initialize(@project_dir : String, @global : Bool, @force : Bool, @color : Bool)
    end

    def run
      # Expand project directory path
      project_path = ::Path.new(@project_dir).expand(home: true)

      unless Dir.exists?(project_path)
        error "Directory does not exist: #{project_path}"
      end

      # Determine project name from directory or shard.yml
      project_name = get_project_name(project_path)

      # Setup VSCode configuration
      setup_vscode(project_path, project_name)

      # Setup global LLDB configuration if requested
      setup_global_lldb if @global

      success "LLDB debugging setup complete!"
      puts ""
      puts "  VSCode: Press F5 to start debugging"
      puts "  LLDB: Run 'lldb your_program' and formatters will load automatically" if @global
      puts ""
      puts "  Custom commands available in Debug Console:"
      puts "    - crystal_size <var>         Get size of Array, Hash, Set, or String"
      puts "    - crystal_at <array> <index> Get array element at index"
      puts "    - crystal_keys <hash>        List hash keys"
    end

    private def get_project_name(project_path : ::Path) : String
      # Try to read from shard.yml
      shard_file = project_path / "shard.yml"
      if File.exists?(shard_file)
        shard = YAML.parse(File.read(shard_file))
        if name = shard["name"]?.try(&.as_s)
          return name
        end
      end

      # Fallback to directory name
      project_path.basename
    end

    private def setup_vscode(project_path : ::Path, project_name : String)
      vscode_dir = project_path / ".vscode"
      Dir.mkdir_p(vscode_dir) unless Dir.exists?(vscode_dir)

      # Copy formatters
      setup_formatters(vscode_dir)

      # Create launch.json
      setup_launch_json(vscode_dir, project_name)

      # Create tasks.json
      setup_tasks_json(vscode_dir, project_name)
    end

    private def setup_formatters(vscode_dir : ::Path)
      dest = vscode_dir / "crystal_formatters.py"

      if File.exists?(dest) && !@force
        info "Skipping #{dest} (already exists, use --force to overwrite)"
        return
      end

      # Find formatters relative to Crystal executable
      # Try: <exec_path>/../etc/lldb/crystal_formatters.py
      exec_path = Crystal::Config.exec_path
      if exec_path
        source = ::Path.new(exec_path).parent / "etc" / "lldb" / "crystal_formatters.py"
      else
        compiler_dir = ::Path.new(Process.executable_path.not_nil!).parent
        source = compiler_dir / "etc" / "lldb" / "crystal_formatters.py"
      end

      unless File.exists?(source)
        error "Cannot find crystal_formatters.py at #{source}"
      end

      File.copy(source, dest)
      success "Created #{dest}"
    end

    private def setup_launch_json(vscode_dir : ::Path, project_name : String)
      dest = vscode_dir / "launch.json"

      if File.exists?(dest) && !@force
        info "Skipping #{dest} (already exists, use --force to overwrite)"
        return
      end

      content = build_launch_json(project_name)
      File.write(dest, content)
      success "Created #{dest}"
    end

    private def setup_tasks_json(vscode_dir : ::Path, project_name : String)
      dest = vscode_dir / "tasks.json"

      if File.exists?(dest) && !@force
        info "Skipping #{dest} (already exists, use --force to overwrite)"
        return
      end

      content = build_tasks_json(project_name)
      File.write(dest, content)
      success "Created #{dest}"
    end

    private def setup_global_lldb
      lldbinit_path = ::Path.home / ".lldbinit"
      formatters_import = "command script import ${CRYSTAL_ROOT}/etc/lldb/crystal_formatters.py"

      # Check if already configured
      if File.exists?(lldbinit_path)
        content = File.read(lldbinit_path)
        if content.includes?("crystal_formatters.py")
          info "#{lldbinit_path} already contains Crystal formatters configuration"
          return
        end
      end

      # Append to .lldbinit
      File.open(lldbinit_path, "a") do |f|
        f.puts ""
        f.puts "# Crystal LLDB formatters (added by crystal tool debug:setup)"
        f.puts formatters_import
      end

      success "Updated #{lldbinit_path}"
    end

    private def build_launch_json(project_name : String) : String
      <<-JSON
      {
        "version": "0.2.0",
        "configurations": [
          {
            "type": "lldb-dap",
            "request": "launch",
            "name": "Crystal: Debug Current File",
            "program": "${workspaceFolder}/${fileBasenameNoExtension}",
            "args": [],
            "cwd": "${workspaceFolder}",
            "initCommands": [
              "command script import ${workspaceFolder}/.vscode/crystal_formatters.py",
              "settings set target.inline-breakpoint-strategy always"
            ],
            "preLaunchTask": "crystal: build current file (debug)",
            "sourceMap": {},
            "enableSyntheticChildDebugging": true
          },
          {
            "type": "lldb-dap",
            "request": "launch",
            "name": "Crystal: Debug Program",
            "program": "${workspaceFolder}/bin/#{project_name}",
            "args": [],
            "cwd": "${workspaceFolder}",
            "initCommands": [
              "command script import ${workspaceFolder}/.vscode/crystal_formatters.py",
              "settings set target.inline-breakpoint-strategy always"
            ],
            "enableSyntheticChildDebugging": true
          }
        ]
      }
      JSON
    end

    private def build_tasks_json(project_name : String) : String
      <<-JSON
      {
        "version": "2.0.0",
        "tasks": [
          {
            "label": "crystal: build current file (debug)",
            "type": "shell",
            "command": "crystal",
            "args": [
              "build",
              "--debug",
              "-o",
              "${fileBasenameNoExtension}",
              "${file}"
            ],
            "group": {
              "kind": "build",
              "isDefault": true
            },
            "presentation": {
              "reveal": "always",
              "panel": "new"
            },
            "problemMatcher": []
          },
          {
            "label": "crystal: build program (debug)",
            "type": "shell",
            "command": "crystal",
            "args": [
              "build",
              "--debug",
              "-o",
              "bin/#{project_name}",
              "src/#{project_name}.cr"
            ],
            "group": "build",
            "presentation": {
              "reveal": "always",
              "panel": "new"
            },
            "problemMatcher": []
          },
          {
            "label": "crystal: run specs",
            "type": "shell",
            "command": "crystal",
            "args": [
              "spec"
            ],
            "group": "test",
            "presentation": {
              "reveal": "always",
              "panel": "new"
            },
            "problemMatcher": []
          }
        ]
      }
      JSON
    end

    private def success(message : String)
      if @color
        puts "    #{"create".colorize(:light_green)}  #{message}"
      else
        puts "    create  #{message}"
      end
    end

    private def info(message : String)
      if @color
        puts "      #{"skip".colorize(:yellow)}  #{message}"
      else
        puts "      skip  #{message}"
      end
    end

    private def error(message : String)
      if @color
        STDERR.puts "#{"Error:".colorize(:red)} #{message}"
      else
        STDERR.puts "Error: #{message}"
      end
      exit 1
    end
  end
end
