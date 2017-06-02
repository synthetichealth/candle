module Candle
  class Helpers
    # Helper method to wrap a resource in a Bundle.entry
    def self.bundle_entry(url, resource)
      entry = FHIR::Bundle::Entry.new
      entry.fullUrl = url
      entry.resource = resource
      entry
    end
    # Extract an ID for a specific resourceType from a URL
    def self.extract_id(url, resourceType)
      start = url.index("#{resourceType}/")
      return nil unless start
      start = start + resourceType.length + 1
      stop = url.index('/', start) || url.length
      stop -= 1
      url[start..stop]
    end
  end
end
