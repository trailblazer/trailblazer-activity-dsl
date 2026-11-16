module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.
    module DSL
      # Class-based DSL to define a circuit (and an activity).
      # NOTE: This is not meant for light-weight library circuits as needed in Reform or Representable,
      #       but for end-user facing business components.
      # NOTE: This used to be named Strategy.
      class Topology
        extend Dry::Configurable

        setting :builder # this keeps the Sequence instance.
        setting :circuit
        setting :outputs
        setting :helpers_module # Contains all macros like Subprocess(, Output() etc.

        extend DSL # {#forward_to_builder!}
        extend DSL::Step # #step

        def self.to_h
          {
            circuit: config.circuit,
            outputs: config.outputs # TODO: test me.
          }
        end
# FIXME: test this behavior (Runtime module_.
        def self.start_tuple # FIXME: make this nicer, for Processor
          config.circuit.start_tuple
        end
        def self.resolve(*args) # FIXME: make this nicer, for Processor
          config.circuit.resolve(*args)
        end

        module ExecContext
          module_function

          def find_path(nodes, path: []) # DISCUSS: move to Introspect.
            nodes.flat_map do |id, node|
              paths = []

              if node.task.is_a?(Circuit) # recurse.
                paths += find_path(node.task.nodes, path: [*path, id])
              end

              if node.is_a?(Circuit::Node::MergeToCircuitOptions) && node.options[:instance_method]
                paths += [[[*path, id], node]]
              end

              paths
            end
          end
        end

        def self.inherited(subclass)
          super

          paths = []
          paths = ExecContext.find_path(subclass.config.circuit.nodes) if subclass.config.circuit # FIXME: make check unnecessary.

          node_for_subclass = Circuit::Node[subclass.config.circuit, Circuit::Processor] # FIXME: store canonical node somewhere.

          paths.each do |path, node|
            path, id = path[0..-2], path[-1]

            node_for_subclass = Circuit::Node::Patch.(node_for_subclass, path, adds:[
              [
                id,
                node.class[node.task, node.interface, merge_to_circuit_options: node.merge_to_circuit_options.merge(exec_context: subclass.new.freeze)],
                :replace, id
              ]
            ])
          end

          subclass.config.circuit = node_for_subclass.task

          # when adding new #steps, do it with the new {exec_context}.
          subclass.config.builder = config.builder.clone(defaults: {exec_context: subclass.new.freeze})
        end

        config.builder = Builder.new(default_options: {})

        def self.build(builder:, default_options:, helpers: false, constants: false, adds:, &block)
          helpers_module = Module.new # FIXME: extract to separate method. # FIXME: test when helpers not given

          if helpers
            helper_modules = helpers.keys
            helper_methods = helpers.values.flatten.uniq # [:Output, :Track, :In, ...]

            helpers_module = Module.new do
              @helper_modules = helper_modules
              @helper_methods = helper_methods
              @constants = constants

              # this is called when doing {MyTopology.include helper}.
              def self.included(includer)
                includer.include *@constants if @constants
                includer.extend *@helper_modules if @helper_modules
                includer.singleton_class.send(:public, *@helper_methods)
              end
            end
          end

          builder = builder.clone(
            defaults: default_options,
            # default_options: default_options,
            adds: adds,
            helpers: helper_modules
          )

          circuit, outputs, _ = builder.(&block) if block_given?

          return circuit, outputs, builder, helpers_module
        end
      end
    end # DSL
  end
end

