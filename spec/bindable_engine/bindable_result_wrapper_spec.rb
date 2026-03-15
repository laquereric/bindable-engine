# frozen_string_literal: true

RSpec.describe BindableEngine::BindableResultWrapper do
  let(:bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      include BindableEngine::BindableResultWrapper
      bind_as "WrappedBindable"

      def read(context_record)
        { name: "test", id: context_record.payload[:id] }
      end

      def list(_context_record)
        [{ id: "1" }, { id: "2" }]
      end

      def create(_context_record)
        { error: "something went wrong" }
      end

      def update(_context_record)
        raise BindableEngine::ValidationError, "Name is required"
      end

      def delete(_context_record)
        raise StandardError, "Database connection lost"
      end
    end
  end

  let(:bindable) { bindable_class.new }

  def make_record(action:, payload: {})
    BindableEngine::ContextRecord.new(
      action: action,
      target: "WrappedBindable",
      payload: payload
    )
  end

  describe "#safe_handle" do
    context "with raw Hash return" do
      it "wraps the hash in a Success result" do
        result = bindable.safe_handle(make_record(action: :read, payload: { id: "42" }))
        expect(result).to be_a(BindableEngine::Result)
        expect(result.success?).to be true
        expect(result.value![:data]).to eq({ name: "test", id: "42" })
        expect(result.value![:metadata]).to eq({})
      end
    end

    context "with array return" do
      it "wraps non-Hash values in a Success result" do
        result = bindable.safe_handle(make_record(action: :list))
        expect(result.success?).to be true
        expect(result.value![:data]).to eq([{ id: "1" }, { id: "2" }])
      end
    end

    context "with Hash containing :error key" do
      it "wraps in a Failure result" do
        result = bindable.safe_handle(make_record(action: :create))
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:internal_error)
        expect(result.failure[:message]).to eq("something went wrong")
      end
    end

    context "when ValidationError is raised" do
      it "returns a validation_error Failure" do
        result = bindable.safe_handle(make_record(action: :update))
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:validation_error)
        expect(result.failure[:message]).to eq("Name is required")
      end
    end

    context "when StandardError is raised" do
      it "returns an internal_error Failure with trace" do
        result = bindable.safe_handle(make_record(action: :delete))
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:internal_error)
        expect(result.failure[:message]).to eq("Database connection lost")
        expect(result.failure[:trace]).to be_an(Array)
      end
    end

    context "with unknown action" do
      it "returns a validation_error Failure" do
        record = make_record(action: :read)
        allow(record).to receive(:action).and_return(:explode)
        result = bindable.safe_handle(record)
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:validation_error)
        expect(result.failure[:message]).to include("Unknown action")
      end
    end

    context "when NotImplementedError is raised" do
      it "returns a not_implemented Failure" do
        execute_class = Class.new do
          include BindableEngine::Bindable
          include BindableEngine::BindableResultWrapper
          bind_as "ExecuteOnly"
        end
        b = execute_class.new
        record = BindableEngine::ContextRecord.new(
          action: :execute,
          target: "ExecuteOnly"
        )
        result = b.safe_handle(record)
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:not_implemented)
      end
    end

    context "when AuthenticationError is raised" do
      it "returns an unauthorized Failure" do
        auth_class = Class.new do
          include BindableEngine::Bindable
          include BindableEngine::BindableResultWrapper
          bind_as "AuthTest"

          def read(_ctx)
            raise BindableEngine::AuthenticationError, "Token expired"
          end
        end
        b = auth_class.new
        result = b.safe_handle(make_record(action: :read))
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:unauthorized)
        expect(result.failure[:message]).to eq("Token expired")
      end
    end

    context "when AuthorizationError is raised" do
      it "returns a forbidden Failure" do
        authz_class = Class.new do
          include BindableEngine::Bindable
          include BindableEngine::BindableResultWrapper
          bind_as "AuthzTest"

          def read(_ctx)
            raise BindableEngine::AuthorizationError, "Insufficient role"
          end
        end
        b = authz_class.new
        result = b.safe_handle(make_record(action: :read))
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:forbidden)
        expect(result.failure[:message]).to eq("Insufficient role")
      end
    end

    context "when Bindable returns a Result directly" do
      it "passes through Success without re-wrapping" do
        monad_class = Class.new do
          include BindableEngine::Bindable
          include BindableEngine::BindableResultWrapper
          bind_as "MonadReturn"

          def read(_ctx)
            BindableEngine::Result.success({ data: { already: "wrapped" }, metadata: {} })
          end
        end
        b = monad_class.new
        result = b.safe_handle(make_record(action: :read))
        expect(result.success?).to be true
        expect(result.value![:data]).to eq({ already: "wrapped" })
      end
    end

    context "when Bindable returns a Failure Result directly" do
      it "passes through Failure without re-wrapping" do
        monad_class = Class.new do
          include BindableEngine::Bindable
          include BindableEngine::BindableResultWrapper
          bind_as "MonadFailReturn"

          def read(_ctx)
            BindableEngine::Result.failure(code: :not_found, message: "Gone")
          end
        end
        b = monad_class.new
        result = b.safe_handle(make_record(action: :read))
        expect(result.failure?).to be true
        expect(result.failure[:code]).to eq(:not_found)
      end
    end
  end

  describe "backward compatibility" do
    it "still responds to handle (raw return, no wrapping)" do
      result = bindable.handle(make_record(action: :read, payload: { id: "99" }))
      expect(result).to eq({ name: "test", id: "99" })
    end
  end
end
