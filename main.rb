require './wildfly-swarm-cli-standalone.jar'

class Build
  JBOSS_PUBLIC_REPO = "http://repository.jboss.org/nexus/content/groups/public/"
  java_import org.wildfly.swarm.tools.BuildTool

  MAVEN_API = org.jboss.shrinkwrap.resolver.api.maven
  java_import MAVEN_API.repository.MavenRemoteRepositories
  java_import MAVEN_API.ConfigurableMavenResolverSystem
  java_import MAVEN_API.Maven
  java_import MAVEN_API.repository.MavenChecksumPolicy
  java_import MAVEN_API.repository.MavenRemoteRepository
  java_import MAVEN_API.repository.MavenUpdatePolicy
  
  def self.literate(*names)
    names.each do |name|
      class_eval "def #{name}(value); @#{name} = value; self; end"
    end
  end

  literate :source, :output_dir, :name, :swarm_version
    
  def initialize
    @deps = []
    swarm_deps "bootstrap", "container"
  end

  def swarm_dep(name)
    ["compile", "org.wildfly.swarm", "wildfly-swarm-#{name}", -> {@swarm_version}, "jar"]
  end

  def deps(*dependencies)
    @deps.concat dependencies
    self
  end

  def swarm_deps(*dependency_names)
    new_deps = dependency_names.map {|d| swarm_dep d }
    deps *new_deps
    self
  end

  def maven_repo(url)
    repo =  MavenRemoteRepositories.create_remote_repository url, url, 'default'
    repo.set_checksum_policy MavenChecksumPolicy::CHECKSUM_POLICY_IGNORE
    repo.set_update_policy MavenUpdatePolicy::UPDATE_POLICY_NEVER
  end

  def maven_resolver_helper
    mvn = Maven.configure_resolver
            .with_maven_central_repo(true)
            .with_remote_repo(maven_repo(JBOSS_PUBLIC_REPO))
    org.wildfly.swarm.arquillian.adapter.ShrinkwrapArtifactResolvingHelper.new mvn
  end

  def run
    base_name, type = @source.split "\\.(?=[^\\.]+$)"
    tool = BuildTool.new
           .artifact_resolving_helper(maven_resolver_helper)
           .main_class("org.projectodd.swarmjr.RubyMain")
           .project_artifact("", base_name, "", type, java.io.File.new(@source))
           .resolve_transitive_dependencies(true)

    # wars are webby so implicitly add undertow
    swarm_deps "undertow" if "war" == type

    @deps.each do |life, group_id, artifact_id, version, type|
      tool.dependency life, group_id, artifact_id, version[], type, nil, nil
    end

    jar_name = @name || base_name
    out_dir = @output_dir.get_canonical_path
    puts "Building #{out_dir}/#{jar_name}-swarm.jar with fractions: #{@deps.map {|d| "\n\t#{d[1]}:#{d[2]}" }.join('')}"

    tool.build(jar_name, Java::java.nio.file.Paths.get(out_dir))
  end
end

Build.new.swarm_version("1.0.0.Alpha4")
                .source("target/swarmjr-0.1-SNAPSHOT.jar")
                .deps(["compile", "org.jruby", "jruby-complete", ->{ "9.0.1.0"}, "jar"])
                .swarm_deps("undertow")
                .output_dir(java.io.File.new("."))
                .name("frogger")
                .run()
