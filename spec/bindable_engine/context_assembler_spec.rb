# frozen_string_literal: true

RSpec.describe BindableEngine::ContextAssembler do
  # --- Test Bindables ---

  let(:users_bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      include BindableEngine::BindableResultWrapper
      bind_as "users"

      def read(_context_record)
        { id: "u-1", email: "alice@example.com", name: "Alice", role: "admin" }
      end

      def list(_context_record)
        [
          { id: "u-1", email: "alice@example.com", name: "Alice" },
          { id: "u-2", email: "bob@example.com", name: "Bob" }
        ]
      end
    end
  end

  let(:profiles_bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      include BindableEngine::BindableResultWrapper
      bind_as "profiles"

      def read(_context_record)
        {
          bio: "Software engineer",
          presets: { name: "creative", temperature: 0.9, top_p: 0.95 },
          avatar_url: "https://example.com/alice.png"
        }
      end
    end
  end

  let(:failing_bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      include BindableEngine::BindableResultWrapper
      bind_as "broken"

      def read(_context_record)
        raise StandardError, "Database connection lost"
      end
    end
  end

  let(:sequential_bindable_class) do
    Class.new do
      include BindableEngine::Bindable
      include BindableEngine::BindableResultWrapper
      bind_as "settings"

      def read(context_record)
        accumulated = context_record.metadata[:accumulated_context] || {}
        user_data = accumulated["users"]
        theme = user_data ? "custom-#{user_data[:id]}" : "default"
        { theme: theme, locale: "en" }
      end
    end
  end

  # --- Registry setup ---

  let(:registry) do
    reg = BindableEngine::BindableRegistry.instance
    reg.reset!
    reg.register(users_bindable_class.new)
    reg.register(profiles_bindable_class.new)
    reg
  end

  let(:assembler) { described_class.new(registry: registry) }

  # --- Parallel assembly ---

  describe "parallel assembly" do
    let(:bundle) do
      {
        id: "user-profile-context",
        assembly_mode: "parallel",
        views: [
          { concept: "users" },
          { concept: "profiles" }
        ]
      }
    end

    it "fetches all views and merges results" do
      result = assembler.assemble(bundle)

      expect(result[:bundle]).to eq("user-profile-context")
      expect(result[:assembly_mode]).to eq("parallel")
      expect(result[:views].keys).to contain_exactly("users", "profiles")
      expect(result[:views]["users"][:id]).to eq("u-1")
      expect(result[:views]["profiles"][:bio]).to eq("Software engineer")
    end

    it "defaults to parallel when assembly_mode is omitted" do
      bundle_no_mode = { id: "default-mode", views: [{ concept: "users" }] }
      result = assembler.assemble(bundle_no_mode)

      expect(result[:assembly_mode]).to eq("parallel")
      expect(result[:views]["users"][:id]).to eq("u-1")
    end
  end

  # --- Sequential assembly ---

  describe "sequential assembly" do
    before do
      registry.register(sequential_bindable_class.new)
    end

    let(:bundle) do
      {
        id: "sequential-context",
        assembly_mode: "sequential",
        views: [
          { concept: "users" },
          { concept: "settings" }
        ]
      }
    end

    it "fetches in order and passes accumulated context to subsequent calls" do
      result = assembler.assemble(bundle)

      expect(result[:assembly_mode]).to eq("sequential")
      expect(result[:views]["users"][:id]).to eq("u-1")
      expect(result[:views]["settings"][:theme]).to eq("custom-u-1")
    end

    it "accumulates context progressively" do
      result = assembler.assemble(bundle)
      expect(result[:views]["settings"][:locale]).to eq("en")
    end
  end

  # --- Lazy assembly ---

  describe "lazy assembly" do
    let(:bundle) do
      {
        id: "lazy-context",
        assembly_mode: "lazy",
        views: [
          { concept: "users", fields: [:id, :email] },
          { concept: "profiles", includes: { presets: [:name, :temperature] } }
        ]
      }
    end

    it "returns view specs without fetching data" do
      result = assembler.assemble(bundle)

      expect(result[:assembly_mode]).to eq("lazy")

      users_spec = result[:views]["users"]
      expect(users_spec[:_lazy]).to be true
      expect(users_spec[:concept]).to eq("users")
      expect(users_spec[:fields]).to eq([:id, :email])

      profiles_spec = result[:views]["profiles"]
      expect(profiles_spec[:_lazy]).to be true
      expect(profiles_spec[:includes]).to eq({ presets: [:name, :temperature] })
    end

    it "does not call any Bindables" do
      spy_class = Class.new do
        include BindableEngine::Bindable
        include BindableEngine::BindableResultWrapper
        bind_as "spy"

        attr_reader :called

        def initialize
          @called = false
        end

        def read(_ctx)
          @called = true
          { data: "should not be fetched" }
        end
      end

      spy_instance = spy_class.new
      registry.register(spy_instance)

      bundle_with_spy = {
        id: "lazy-spy",
        assembly_mode: "lazy",
        views: [{ concept: "spy" }]
      }

      assembler.assemble(bundle_with_spy)
      expect(spy_instance.called).to be false
    end
  end

  # --- Field filtering ---

  describe "field filtering" do
    it "keeps only specified fields from a Hash result" do
      bundle = {
        id: "filtered",
        assembly_mode: "parallel",
        views: [
          { concept: "users", fields: [:id, :email] }
        ]
      }

      result = assembler.assemble(bundle)
      user_data = result[:views]["users"]

      expect(user_data.keys).to contain_exactly(:id, :email)
      expect(user_data[:id]).to eq("u-1")
      expect(user_data[:email]).to eq("alice@example.com")
      expect(user_data).not_to have_key(:name)
      expect(user_data).not_to have_key(:role)
    end

    it "filters fields from each item in an Array result" do
      bundle = {
        id: "filtered-list",
        assembly_mode: "parallel",
        views: [
          { concept: "users", action: :list, fields: [:id, :name] }
        ]
      }

      result = assembler.assemble(bundle)
      user_list = result[:views]["users"]

      expect(user_list).to be_an(Array)
      expect(user_list.size).to eq(2)
      expect(user_list.first.keys).to contain_exactly(:id, :name)
      expect(user_list.first[:email]).to be_nil
    end
  end

  # --- Include expansion ---

  describe "include expansion" do
    it "extracts association data and filters its fields" do
      bundle = {
        id: "with-includes",
        assembly_mode: "parallel",
        views: [
          { concept: "profiles", includes: { presets: [:name, :temperature] } }
        ]
      }

      result = assembler.assemble(bundle)
      profile_data = result[:views]["profiles"]

      expect(profile_data[:bio]).to eq("Software engineer")
      expect(profile_data[:presets].keys).to contain_exactly(:name, :temperature)
      expect(profile_data[:presets][:name]).to eq("creative")
      expect(profile_data[:presets][:temperature]).to eq(0.9)
      expect(profile_data[:presets]).not_to have_key(:top_p)
    end
  end

  # --- Partial failure ---

  describe "partial failure" do
    before do
      registry.register(failing_bindable_class.new)
    end

    it "skips failed views and includes successful ones" do
      bundle = {
        id: "partial-fail",
        assembly_mode: "parallel",
        views: [
          { concept: "users" },
          { concept: "broken" },
          { concept: "profiles" }
        ]
      }

      result = assembler.assemble(bundle)

      expect(result[:views].keys).to contain_exactly("users", "profiles")
      expect(result[:views]).not_to have_key("broken")
      expect(result[:views]["users"][:id]).to eq("u-1")
      expect(result[:views]["profiles"][:bio]).to eq("Software engineer")
    end
  end

  # --- Empty bundle ---

  describe "empty bundle" do
    it "returns empty views for no views" do
      bundle = { id: "empty", assembly_mode: "parallel", views: [] }
      result = assembler.assemble(bundle)

      expect(result[:bundle]).to eq("empty")
      expect(result[:views]).to eq({})
    end

    it "returns empty views when views key is missing" do
      bundle = { id: "no-views", assembly_mode: "parallel" }
      result = assembler.assemble(bundle)

      expect(result[:views]).to eq({})
    end
  end

  # --- Missing bindable ---

  describe "missing bindable" do
    it "skips gracefully when view references unknown concept" do
      bundle = {
        id: "missing-concept",
        assembly_mode: "parallel",
        views: [
          { concept: "nonexistent" },
          { concept: "users" }
        ]
      }

      result = assembler.assemble(bundle)

      expect(result[:views].keys).to eq(["users"])
      expect(result[:views]).not_to have_key("nonexistent")
    end
  end

  # --- actor_metadata ---

  describe "actor_metadata" do
    it "passes actor_metadata to ContextRecord" do
      metadata_capturing_class = Class.new do
        include BindableEngine::Bindable
        include BindableEngine::BindableResultWrapper
        bind_as "metadata_echo"

        def read(context_record)
          { received_metadata: context_record.metadata.to_h }
        end
      end

      registry.register(metadata_capturing_class.new)

      bundle = {
        id: "metadata-test",
        assembly_mode: "parallel",
        views: [{ concept: "metadata_echo" }]
      }

      result = assembler.assemble(bundle, actor_metadata: { user_id: "u-42", role: "admin" })
      received = result[:views]["metadata_echo"][:received_metadata]

      expect(received[:user_id]).to eq("u-42")
      expect(received[:role]).to eq("admin")
    end
  end

  # --- Custom action ---

  describe "custom action" do
    it "uses the specified action instead of default :read" do
      bundle = {
        id: "list-action",
        assembly_mode: "parallel",
        views: [
          { concept: "users", action: :list }
        ]
      }

      result = assembler.assemble(bundle)
      expect(result[:views]["users"]).to be_an(Array)
      expect(result[:views]["users"].size).to eq(2)
    end
  end

  # --- Combined fields and includes ---

  describe "combined fields and includes" do
    it "applies both field filtering and include expansion" do
      bundle = {
        id: "combined",
        assembly_mode: "parallel",
        views: [
          {
            concept: "profiles",
            fields: [:bio, :presets],
            includes: { presets: [:name] }
          }
        ]
      }

      result = assembler.assemble(bundle)
      profile = result[:views]["profiles"]

      expect(profile.keys).to contain_exactly(:bio, :presets)
      expect(profile[:presets].keys).to contain_exactly(:name)
    end
  end
end
