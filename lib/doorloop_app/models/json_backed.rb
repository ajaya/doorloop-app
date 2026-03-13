# frozen_string_literal: true

require "json"

module DoorLoopApp
  module Models
    module JsonBacked
      def self.included(base)
        base.extend(ClassMethods)
        base.unrestrict_primary_key
      end

      def to_api
        JSON.parse(data, symbolize_names: true).merge(_stored_at: updated_at)
      end

      module ClassMethods
        def setup!(db)
          migrate!(db)
          set_dataset(db[self::TABLE])
        end

        def id_field
          const_defined?(:ID_FIELD) ? const_get(:ID_FIELD) : "id"
        end

        def upsert_all(items)
          items.each do |item|
            h = item.is_a?(Hash) ? item : item.to_h
            id = (h[id_field] || h[id_field.to_sym] || h["id"] || h[:id])&.to_s
            next unless id

            attrs = { data: JSON.generate(h), updated_at: Time.now }
            self::COLUMNS.each { |col, spec| attrs[col] = extract(h, spec) }

            existing = self[id]
            if existing
              existing.update(attrs)
            else
              create(attrs.merge(id: id, created_at: Time.now))
            end
          end
        end

        def find_by_name(name)
          where(Sequel.ilike(:name, "%#{name}%")).all
        end

        def stale?(max_age: 300)
          latest = order(Sequel.desc(:updated_at)).first
          return true unless latest
          (Time.now - latest[:updated_at]) > max_age
        end

        def clear!
          dataset.delete
        end

        private

        def extract(h, spec)
          case spec
          when Array
            spec.filter_map { |path| dig_value(h, path) }
                .reject { |s| s.to_s.empty? }
                .join(", ").then { |s| s.empty? ? nil : s }
          when String
            val = dig_value(h, spec)
            val.is_a?(Array) ? JSON.generate(val) : val&.to_s
          end
        end

        def dig_value(h, path)
          path.split(".").reduce(h) do |obj, key|
            if obj.is_a?(Array)
              idx = Integer(key, exception: false)
              break nil unless idx
              obj[idx]
            elsif obj.is_a?(Hash)
              obj[key] || obj[key.to_sym]
            else
              break nil
            end
          end
        end
      end
    end
  end
end
