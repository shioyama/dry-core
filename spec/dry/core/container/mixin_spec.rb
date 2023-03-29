# frozen_string_literal: true

RSpec.describe $loader::Dry::Core::Container::Mixin do
  describe "extended" do
    let(:klass) do
      Class.new { extend $loader::Dry::Core::Container::Mixin }
    end

    let(:container) do
      klass
    end

    it_behaves_like "a container"
  end

  describe "included" do
    let(:klass) do
      Class.new { include $loader::Dry::Core::Container::Mixin }
    end

    let(:container) do
      klass.new
    end

    it_behaves_like "a container"

    context "into a class with a custom .initialize method" do
      let(:klass) do
        Class.new do
          attr_reader :test

          include $loader::Dry::Core::Container::Mixin

          def initialize
            @test = true
          end
        end
      end

      it "does not fail on missing member variable" do
        expect { container.register :key, -> {} }.to_not raise_error
      end

      it "doesn't override the original initialize method" do
        expect(container.test).to be(true)
      end
    end
  end

  if defined?($loader::Dry::Configurable)
    context "using custom settings via Dry::Configurable with a class" do
      let(:klass) do
        Class.new do
          extend $loader::Dry::Core::Container::Mixin

          setting :root, default: "/tmp"
        end
      end

      let(:container) do
        klass
      end

      it "exposes custom config" do
        expect(container.config.root).to eql("/tmp")
      end
    end

    context "using custom settings via Dry::Configurable with an object" do
      let(:klass) do
        Class.new do
          include $loader::Dry::Core::Container::Mixin

          setting :root, default: "/tmp"
        end
      end

      let(:container) do
        klass.new
      end

      it "exposes custom config" do
        expect(container.config.root).to eql("/tmp")
      end
    end
  end
end
