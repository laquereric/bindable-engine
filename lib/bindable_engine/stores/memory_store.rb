# frozen_string_literal: true

module BindableEngine
  module Stores
    # Thread-safe in-memory store. Default for tests and lightweight domains.
    class MemoryStore < Store
      def initialize
        @mutex = Mutex.new
        @data = {}
      end

      def save(id, attrs)
        @mutex.synchronize do
          @data[id.to_s] = attrs.transform_keys(&:to_s)
        end
        Result.success(@data[id.to_s].merge("id" => id.to_s))
      end

      def find(id)
        @mutex.synchronize do
          record = @data[id.to_s]
          if record
            Result.success(record.merge("id" => id.to_s))
          else
            Result.failure(code: :not_found, message: "Record not found: #{id}")
          end
        end
      end

      def query(criteria = {})
        @mutex.synchronize do
          results = @data.map { |id, attrs| attrs.merge("id" => id) }
          criteria.each do |key, value|
            results = results.select { |r| r[key.to_s] == value }
          end
          Result.success(results)
        end
      end

      def destroy(id)
        @mutex.synchronize do
          if @data.delete(id.to_s)
            Result.success({ "id" => id.to_s, "deleted" => true })
          else
            Result.failure(code: :not_found, message: "Record not found: #{id}")
          end
        end
      end

      def clear!
        @mutex.synchronize { @data.clear }
      end

      def size
        @mutex.synchronize { @data.size }
      end
    end
  end
end
