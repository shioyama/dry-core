# frozen_string_literal: true

RSpec.shared_examples "a container" do
  describe "configuration" do
    describe "registry" do
      describe "default" do
        it { expect(klass.config.registry).to be_a($loader::Dry::Core::Container::Registry) }
      end

      describe "custom" do
        let(:custom_registry) { double("Registry") }
        let(:key) { :key }
        let(:item) { :item }
        let(:options) { {} }

        before do
          klass.configure do |config|
            config.registry = custom_registry
          end

          allow(custom_registry).to receive(:call)
        end

        after do
          # HACK: Have to reset the configuration so that it doesn't
          # interfere with other specs
          klass.configure do |config|
            config.registry = $loader::Dry::Core::Container::Registry.new
          end
        end

        subject! { container.register(key, item, options) }

        it do
          expect(custom_registry).to have_received(:call).with(
            container._container,
            key,
            item,
            options
          )
        end
      end
    end

    describe "resolver" do
      describe "default" do
        it { expect(klass.config.resolver).to be_a($loader::Dry::Core::Container::Resolver) }
      end

      describe "custom" do
        let(:custom_resolver) { double("Resolver") }
        let(:item) { double("Item") }
        let(:key) { :key }

        before do
          klass.configure do |config|
            config.resolver = custom_resolver
          end

          allow(custom_resolver).to receive(:call).and_return(item)
        end

        after do
          # HACK: Have to reset the configuration so that it doesn't
          # interfere with other specs
          klass.configure do |config|
            config.resolver = $loader::Dry::Core::Container::Resolver.new
          end
        end

        subject! { container.resolve(key) }

        it { expect(custom_resolver).to have_received(:call).with(container._container, key) }
        it { is_expected.to eq(item) }
      end
    end

    describe "namespace_separator" do
      describe "default" do
        it { expect(klass.config.namespace_separator).to eq(".") }
      end

      describe "custom" do
        let(:custom_registry) { double("Registry") }
        let(:key) { "key" }
        let(:namespace_separator) { "-" }
        let(:namespace) { "one" }

        before do
          klass.configure do |config|
            config.namespace_separator = namespace_separator
          end

          container.namespace(namespace) do
            register("key", "item")
          end
        end

        after do
          # HACK: Have to reset the configuration so that it doesn't
          # interfere with other specs
          klass.configure do |config|
            config.namespace_separator = "."
          end
        end

        subject! { container.resolve([namespace, key].join(namespace_separator)) }

        it { is_expected.to eq("item") }
      end
    end
  end

  context "with default configuration" do
    describe "registering a block" do
      context "without options" do
        context "without arguments" do
          it "registers and resolves an object" do
            container.register(:item) { "item" }

            expect(container.keys).to eq(["item"])
            expect(container.key?(:item)).to be true
            expect(container.resolve(:item)).to eq("item")
          end
        end

        context "with arguments" do
          it "registers and resolves a proc" do
            container.register(:item) { |item| item }

            expect(container.resolve(:item).call("item")).to eq("item")
          end

          it "does not call a proc on resolving if one accepts an arbitrary number of keyword arguments" do
            container.register(:item) { |*| "item" }

            expect(container.resolve(:item)).to be_a_kind_of Proc
            expect(container.resolve(:item).call).to eq("item")
          end
        end
      end

      context "with option call: false" do
        it "registers and resolves a proc" do
          container.register(:item, call: false) { "item" }

          expect(container.keys).to eq(["item"])
          expect(container.key?(:item)).to be true
          expect(container.resolve(:item).call).to eq("item")
          expect(container[:item].call).to eq("item")
        end
      end
    end

    describe "registering a proc" do
      context "without options" do
        context "without arguments" do
          it "registers and resolves an object" do
            container.register(:item, proc { "item" })

            expect(container.keys).to eq(["item"])
            expect(container.key?(:item)).to be true
            expect(container.resolve(:item)).to eq("item")
            expect(container[:item]).to eq("item")
          end
        end

        context "with arguments" do
          it "registers and resolves a proc" do
            container.register(:item, proc { |item| item })

            expect(container.keys).to eq(["item"])
            expect(container.key?(:item)).to be true
            expect(container.resolve(:item).call("item")).to eq("item")
            expect(container[:item].call("item")).to eq("item")
          end
        end
      end

      context "with option call: false" do
        it "registers and resolves a proc" do
          container.register(:item, proc { "item" }, call: false)

          expect(container.keys).to eq(["item"])
          expect(container.key?(:item)).to be true
          expect(container.resolve(:item).call).to eq("item")
          expect(container[:item].call).to eq("item")
        end
      end

      context "with option memoize: true" do
        it "registers and resolves a proc" do
          container.register(:item, proc { "item" }, memoize: true)

          expect(container[:item]).to be container[:item]
          expect(container.keys).to eq(["item"])
          expect(container.key?(:item)).to be true
          expect(container.resolve(:item)).to eq("item")
          expect(container[:item]).to eq("item")
        end

        it "only resolves the proc once" do
          resolved_times = 0

          container.register(:item, proc { resolved_times += 1 }, memoize: true)

          expect(container.resolve(:item)).to be 1
          expect(container.resolve(:item)).to be 1
        end

        context "when receiving something other than a proc" do
          it do
            expect { container.register(:item, "Hello!", memoize: true) }.to raise_error($loader::Dry::Core::Container::Error)
          end
        end
      end
    end

    describe "registering an object" do
      context "without options" do
        it "registers and resolves the object" do
          item = "item"
          container.register(:item, item)

          expect(container.keys).to eq(["item"])
          expect(container.key?(:item)).to be true
          expect(container.resolve(:item)).to be(item)
          expect(container[:item]).to be(item)
        end
      end

      context "with option call: false" do
        it "registers and resolves an object" do
          item = -> { "test" }
          container.register(:item, item, call: false)

          expect(container.keys).to eq(["item"])
          expect(container.key?(:item)).to be true
          expect(container.resolve(:item)).to eq(item)
          expect(container[:item]).to eq(item)
        end
      end
    end

    describe "registering with the same key multiple times" do
      it do
        container.register(:item, proc { "item" })

        expect { container.register(:item, proc { "item" }) }.to raise_error($loader::Dry::Core::Container::KeyError)
      end
    end

    describe "resolving with a key that has not been registered" do
      it do
        expect(container.key?(:item)).to be false
        expect { container.resolve(:item) }.to raise_error(KeyError) do |error|
          # This is the API needed for DidYouMean::KeyErrorChecker to provide corrections
          expect(error.key).to eq("item")
          expect(error.receiver).to eq(container._container)
          expect(error.spell_checker).to be_instance_of(DidYouMean::KeyErrorChecker)
        end
      end
    end

    describe "mixing Strings and Symbols" do
      it do
        container.register(:item, "item")
        expect(container.resolve("item")).to eql("item")
      end
    end

    describe "#merge" do
      let(:key) { :key }
      let(:other) { $loader::Dry::Core::Container.new }

      before do
        other.register(key) { :item }
      end

      context "without namespace argument" do
        subject! { container.merge(other) }

        it { expect(container.resolve(key)).to be(:item) }
        it { expect(container[key]).to be(:item) }
      end

      context "with namespace argument" do
        subject! { container.merge(other, namespace: namespace) }

        context "when namespace is nil" do
          let(:namespace) { nil }

          it { expect(container.resolve(key)).to be(:item) }
          it { expect(container[key]).to be(:item) }
        end

        context "when namespace is not nil" do
          let(:namespace) { "namespace" }

          it { expect(container.resolve("#{namespace}.#{key}")).to be(:item) }
          it { expect(container["#{namespace}.#{key}"]).to be(:item) }
        end
      end

      context "with a block resolving conflicts" do
        before do
          container.register(:conflicting_key, "original")
          other.register(:conflicting_key, "from other")
        end

        it "resolves conflict using provided block" do
          container.merge(other) { |_, left, right| left }

          expect(container[:conflicting_key]).to eql("original")
        end
      end

      context "with a block resolving conflicts with a namespace" do
        before do
          container.register("items.conflicting_key", "original")
          other.register("conflicting_key", "from other")
        end

        it "resolves conflict using provided block" do
          container.merge(other, namespace: "items") { |_, left, right| left }

          expect(container["items.conflicting_key"]).to eql("original")
        end
      end
    end

    describe "#key?" do
      let(:key) { :key }

      before do
        container.register(key) { :item }
      end

      subject! { container.key?(resolve_key) }

      context "when key exists in container" do
        let(:resolve_key) { key }

        it { is_expected.to be true }
      end

      context "when key does not exist in container" do
        let(:resolve_key) { :random }

        it { is_expected.to be false }
      end
    end

    describe "#keys" do
      let(:keys) { [:key_1, :key_2] }
      let(:expected_keys) { %w[key_1 key_2] }

      before do
        keys.each do |key|
          container.register(key) { :item }
        end
      end

      subject! { container.keys }

      it "returns stringified versions of all registered keys" do
        is_expected.to match_array(expected_keys)
      end
    end

    describe "#each_key" do
      let(:keys) { [:key_1, :key_2] }
      let(:expected_keys) { %w[key_1 key_2] }
      let!(:yielded_keys) { [] }

      before do
        keys.each do |key|
          container.register(key) { :item }
        end
      end

      subject! do
        container.each_key { |key| yielded_keys << key }
      end

      it "yields stringified versions of all registered keys to the block" do
        expect(yielded_keys).to match_array(expected_keys)
      end

      it "returns the container" do
        is_expected.to eq(container)
      end
    end

    describe "#each" do
      let(:keys) { [:key_1, :key_2] }
      let(:expected_key_value_pairs) { [%w[key_1 value_for_key_1], %w[key_2 value_for_key_2]] }
      let!(:yielded_key_value_pairs) { [] }

      before do
        keys.each do |key|
          container.register(key) { "value_for_#{key}" }
        end
      end

      subject! do
        container.each { |key, value| yielded_key_value_pairs << [key, value] }
      end

      it "yields stringified versions of all registered keys to the block" do
        expect(yielded_key_value_pairs).to match_array(expected_key_value_pairs)
      end

      it "returns the container" do
        is_expected.to eq(expected_key_value_pairs)
      end
    end

    describe "#decorate" do
      require "delegate"

      let(:key) { :key }
      let(:decorated_class_spy) { spy(:decorated_class_spy) }
      let(:decorated_class) { Class.new }

      context "for callable item" do
        before do
          allow(decorated_class_spy).to receive(:new) { decorated_class.new }
          container.register(key, memoize: memoize) { decorated_class_spy.new }
          container.decorate(key, with: SimpleDelegator)
        end

        context "memoize false" do
          let(:memoize) { false }

          it "does not call the block until the key is resolved" do
            expect(decorated_class_spy).not_to have_received(:new)
            container.resolve(key)
            expect(decorated_class_spy).to have_received(:new)
          end

          specify do
            expect(container[key]).to be_instance_of(SimpleDelegator)
            expect(container[key].__getobj__).to be_instance_of(decorated_class)
            expect(container[key]).not_to be(container[key])
            expect(container[key].__getobj__).not_to be(container[key].__getobj__)
          end
        end

        context "memoize true" do
          let(:memoize) { true }

          specify do
            expect(container[key]).to be_instance_of(SimpleDelegator)
            expect(container[key].__getobj__).to be_instance_of(decorated_class)
            expect(container[key]).to be(container[key])
          end
        end
      end

      context "for not callable item" do
        describe "wrapping" do
          before do
            container.register(key, call: false) { "value" }
            container.decorate(key, with: SimpleDelegator)
          end

          it "expected to be an instance of SimpleDelegator" do
            expect(container.resolve(key)).to be_instance_of(SimpleDelegator)
            expect(container.resolve(key).__getobj__.call).to eql("value")
          end
        end

        describe "memoization" do
          before do
            @called = 0
            container.register(key, "value")

            container.decorate(key) do |value|
              @called += 1
              "<#{value}>"
            end
          end

          it "decorates static value only once" do
            expect(container.resolve(key)).to eql("<value>")
            expect(container.resolve(key)).to eql("<value>")
            expect(@called).to be(1)
          end
        end
      end

      context "with an instance as a decorator" do
        let(:decorator) do
          double.tap do |decorator|
            allow(decorator).to receive(:call) { |input| "decorated #{input}" }
          end
        end

        before do
          container.register(key) { "value" }
          container.decorate(key, with: decorator)
        end

        it "expected to pass original value to decorator#call method" do
          expect(container.resolve(key)).to eq("decorated value")
        end
      end
    end

    describe "namespace" do
      context "when block does not take arguments" do
        before do
          container.namespace("one") do
            register("two", 2)
          end
        end

        subject! { container.resolve("one.two") }

        it "registers items under the given namespace" do
          is_expected.to eq(2)
        end
      end

      context "when block takes arguments" do
        before do
          container.namespace("one") do |c|
            c.register("two", 2)
          end
        end

        subject! { container.resolve("one.two") }

        it "registers items under the given namespace" do
          is_expected.to eq(2)
        end
      end

      context "with nesting" do
        before do
          container.namespace("one") do
            namespace("two") do
              register("three", 3)
            end
          end
        end

        subject! { container.resolve("one.two.three") }

        it "registers items under the given namespaces" do
          is_expected.to eq(3)
        end
      end

      context "with nesting and when block takes arguments" do
        before do
          container.namespace("one") do |c|
            c.register("two", 2)
            c.register("three", c.resolve("two"))
          end
        end

        subject! { container.resolve("one.three") }

        it "resolves items relative to the namespace" do
          is_expected.to eq(2)
        end
      end
    end

    describe "import" do
      it "allows importing of namespaces" do
        ns = $loader::Dry::Core::Container::Namespace.new("one") do
          register("two", 2)
        end

        container.import(ns)

        expect(container.resolve("one.two")).to eq(2)
      end

      it "allows importing of nested namespaces" do
        ns = $loader::Dry::Core::Container::Namespace.new("two") do
          register("three", 3)
        end

        container.namespace("one") do
          import(ns)
        end

        expect(container.resolve("one.two.three")).to eq(3)
      end
    end
  end

  describe "stubbing" do
    before :all do
      require "dry/core/container/stub"
    end

    before do
      container.enable_stubs!

      container.register(:item, "item")
      container.register(:foo, "bar")
    end

    after do
      container.unstub
    end

    it "keys can be stubbed" do
      container.stub(:item, "stub")
      expect(container.resolve(:item)).to eql("stub")
      expect(container[:item]).to eql("stub")
    end

    it "only other keys remain accesible" do
      container.stub(:item, "stub")
      expect(container.resolve(:foo)).to eql("bar")
      expect(container[:foo]).to eql("bar")
    end

    it "keys can be reverted back to their original value" do
      container.stub(:item, "stub")
      container.unstub(:item)

      expect(container.resolve(:item)).to eql("item")
      expect(container[:item]).to eql("item")
    end

    describe "with block argument" do
      it "executes the block with the given stubs" do
        expect { |b| container.stub(:item, "stub", &b) }.to yield_control
      end

      it "keys are stubbed only while inside the block" do
        container.stub(:item, "stub") do
          expect(container.resolve(:item)).to eql("stub")
        end

        expect(container.resolve(:item)).to eql("item")
      end
    end

    describe "mixing Strings and Symbols" do
      it do
        container.stub(:item, "stub")
        expect(container.resolve("item")).to eql("stub")
      end
    end

    it "raises an error when key is missing" do
      expect { container.stub(:non_existing, "something") }
        .to raise_error(ArgumentError, 'cannot stub "non_existing" - no such key in container')
    end
  end

  describe ".freeze" do
    before do
      container.register(:foo, "bar")
    end

    it "allows to freeze a container so that nothing can be registered later" do
      container.freeze
      expect { container.register(:baz, "quux") }.to raise_error(FrozenError)
      expect(container).to be_frozen
    end

    it "wraps FrozenError to provide which key was attempted to be registered" do
      container.freeze
      expect { container.register(:baz, "quux") }
        .to raise_error(
          FrozenError,
          /can't modify frozen \S+ \(when attempting to register 'baz'\)/
        )
    end

    it "returns self back" do
      expect(container.freeze).to be(container)
    end
  end

  describe ".dup" do
    it "returns a copy that doesn't share registered keys with the parent" do
      container.dup.register(:foo, "bar")
      expect(container.key?(:foo)).to be false
    end
  end

  describe ".clone" do
    it "returns a copy that doesn't share registered keys with the parent" do
      container.clone.register(:foo, "bar")
      expect(container.key?(:foo)).to be false
    end

    it "re-uses frozen container" do
      expect(container.freeze.clone).to be_frozen
      expect(container.clone._container).to be(container._container)
    end
  end

  describe ".resolve" do
    it "accepts a fallback block" do
      expect(container.resolve("missing") { :fallback }).to be(:fallback)
    end
  end
end
