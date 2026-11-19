module Trailblazer
  class Activity
    module DSL
      # FIXME: we should move the Step logic here, it's much more intuitive.
      class Normalizer
        def self.call(normalizer, name, **options)
          lib_ctx, _ = Circuit::Processor.(normalizer, options, Circuit::Node::Runner.new, nil)

          return lib_ctx[:adds_for_sequence]
        end
      end
    end
  end
end
