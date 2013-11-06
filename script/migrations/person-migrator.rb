# rails runner script/migrations/person-migrator.rb
module Migrator
  module_function
  def call
    @successes = []
    @silent_failures = []
    @failures = []

    ActiveFedora::Base.send(:connections).each do |connection|
      connection.search('pid~und:*').each do |rubydora_object|
        begin
          if Migration.build(rubydora_object).migrate
            @successes << rubydora_object.pid
          else
            @silent_failures << rubydora_object.pid
          end
        rescue Exception => e
          @failures << [rubydora_object.pid, e]
        end
      end
    end

    puts "Successes: #{@successes.inspect}"
    puts "\tCount: #{@successes.size}"
    puts "Silent Failures: #{@silent_failures.inspect}"
    puts "\tCount: #{@silent_failures.size}"
    puts "Failures with Exception: #{@failures.inspect}"
    puts "\tCount: #{@failures.size}"
  end

  class UnsavedDigitalObject < ActiveFedora::UnsavedDigitalObject
    attr_reader :repository
    def initialize(repository, *args, &block)
      @repository = repository
      super(*args, &block)
    end
  end

  module Migration
    module_function

    def build(rubydora_object, container_namespace = Migrator::Migrations)
      active_fedora_object = ActiveFedora::Base.find(rubydora_object.pid, cast: false)
      best_model_match = determine_best_active_fedora_model(active_fedora_object)

      migrator_name = "#{best_model_match.to_s.gsub("::", "")}Migrator"
      if container_namespace.const_defined?(migrator_name)
        container_namespace.const_get(migrator_name).new(rubydora_object, active_fedora_object)
      else
        container_namespace.const_get('BaseMigrator').new(rubydora_object, active_fedora_object)
      end
    end

    def determine_best_active_fedora_model(active_fedora_object)
      best_model_match = active_fedora_object.class unless active_fedora_object.instance_of? ActiveFedora::Base
      ActiveFedora::ContentModel.known_models_for(active_fedora_object).each do |model_value|
        # If this is of type ActiveFedora::Base, then set to the first found :has_model.
        best_model_match ||= model_value

        # If there is an inheritance structure, use the most specific case.
        if best_model_match > model_value
          best_model_match = model_value
        end
      end
      best_model_match
    end
  end

  module Migrations
    class BaseMigrator
      attr_reader :rubydora_object, :active_fedora_object

      def initialize(rubydora_object, active_fedora_object)
        @rubydora_object = rubydora_object
        @active_fedora_object = active_fedora_object
      end

      def migrate
        load_datastreams &&
        update_index &&
        visit
      end

      def inspect
        "#<#{self.class.inspect} content_model_name:#{content_model_name.inspect} pid:#{rubydora_object.pid.inspect}>"
      end

      def content_model_name
        Migrator::Migration.determine_best_active_fedora_model(active_fedora_object).to_s
      end

      protected

      def build_unsaved_digital_object
        Migrator::UnsavedDigitalObject.new(rubydora_object.repository, active_fedora_object.class, 'und', rubydora_object.pid)
      end

      def load_datastreams
        # A rudimentary check to see if the object's datastreams can be loaded
        model_object.datastreams.each {|ds_name, ds_object| ds_object.inspect }
      end

      def update_index
        model_object.update_index
      end

      def model_object
        @model_object = ActiveFedora::Base.find(rubydora_object.pid, cast: true)
      end

      def visit
        true
      end
    end

    class PersonMigrator < BaseMigrator
      # This is what the datastream used to look like
      class FromDescMetadata < ActiveFedora::QualifiedDublinCoreDatastream
        def initialize(*args)
          super
          field :display_name, :string
          field :preferred_email, :string
          field :alternate_email, :string
        end
      end

      def migrate
        active_fedora_object.datastreams.each do |ds_name, ds_object|
          if ds_name == 'descMetadata'
            migrate_desc_metadata(ds_name, ds_object)
          end
        end
        super
      end

      private

      # Migrating from a QualifiedDublinCoreDatastream to an RdfNTriplesDatastream
      def migrate_desc_metadata(ds_name, ds_object)
        from = FromDescMetadata.new(rubydora_object, ds_name)
        to = PersonMetadataDatastream.new(build_unsaved_digital_object, ds_name)
        begin
          to.name = from.display_name if from.display_name.present?
          to.preferred_email = from.preferred_email if from.preferred_email.present?
          to.alternate_email = from.alternate_email if from.alternate_email.present?
          to.save
        rescue Nokogiri::XML::XPath::SyntaxError
          # already converted
          true
        end
      end

      # Assumes application is running at application URL
      def visit
        remote_url = File.join(Rails.configuration.application_root_url, "people/#{rubydora_object.pid}")
        RestClient.get(remote_url, content_type: :html, accept: :html) do |response, request, result, &block|
          if [301, 302, 307].include? response.code
            response.follow_redirection(request, result, &block)
          else
            response.return!(request, result, &block)
          end
        end
      end
    end
  end

end

Migrator.call