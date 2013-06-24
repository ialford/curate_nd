module ActiveFedora
  module DelegateAttributes
    class Attribute

      attr_reader :name, :datastream

      def initialize(name, options = {})
        @options = options.symbolize_keys
        @options.assert_valid_keys(:default, :form, :datastream, :validates, :at, :as, :multiple, :writer, :reader, :label, :hint)
        @datastream = @options.fetch(:datastream, false)
        @name = name
        @options[:multiple] = true unless @options.key?(:multiple)
        @options[:form] ||= {}
      end

      def label
        options[:label] || name.to_s.titleize
      end

      def with_delegation_options
        yield(name, options_for_delegation) if datastream
      end

      def with_validation_options
        yield(name, options[:validates]) if options[:validates]
      end

      def with_accession_options
        yield(name, {}) if !datastream
      end

      def options_for_input(overrides = {})
        options[:form].tap {|hash|
          hash[:hint] ||= options[:hint] if options[:hint]
          hash[:label] ||= options[:label] if options[:label]
          hash[:as] ||= options[:as] if options[:as]
          if options[:multiple]
            hash[:as] = 'multi_value'
            hash[:input_html] ||= {}
            hash[:input_html][:multiple] = 'multiple'
          end
        }.deep_merge(overrides)
      end

      def default(context)
        this_default = options[:default]
        case
        when this_default.respond_to?(:call) then context.instance_exec(&this_default)
        when this_default.duplicable? then this_default.dup
        else this_default
        end
      end

      def wrap_writer_method(context)
        with_writer_method_wrap do |method_name, block|
          context.instance_exec do
            original_method = instance_method(method_name)
            define_method(method_name) do |*args|
              original_method.bind(self).call(instance_exec(*args, &block))
            end
          end
        end
      end

      def wrap_reader_method(context)
        with_reader_method_wrapper do |method_name, block|
          context.instance_exec do
            original_method = instance_method(method_name)
            define_method(method_name) do |*args|
              instance_exec(original_method.bind(self).call(*args), &block)
            end
          end
        end
      end

      private

        def options_for_delegation
          {
            to: datastream,
            unique: !options[:multiple]
          }.tap {|hash|
            hash[:at] = options[:at] if options.key?(:at)
          }
        end

        def with_writer_method_wrap
          if writer = options[:writer]
            method_name = "#{name}=".to_sym
            proc = writer.respond_to?(:call) ?
              writer :
              lambda { |value| send(writer, value) }
            yield(method_name, proc)
          end
        end

        def with_reader_method_wrapper
          if reader = options[:reader]
            method_name = "#{name}".to_sym
            proc = reader.respond_to?(:call) ?
              reader :
              lambda { |value| send(reader, value) }
            yield(method_name, proc)
          end
        end

        def options
          @options
        end

    end
  end
end