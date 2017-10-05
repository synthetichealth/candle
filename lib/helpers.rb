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
    # Check content type
    def self.valid_content_type(content_type)
      content_type && content_type.start_with?('application/fhir+json')
    end
    # Reject invalid content-type
    def self.reject_content_type(content_type)
      error = FHIR::OperationOutcome.new
      error.issue << FHIR::OperationOutcome::Issue.new
      error.issue.last.severity = 'error'
      error.issue.last.code = 'not-supported'
      error.issue.last.diagnostics = "The content-type `#{content_type}` is not supported. This service only supports `application/fhir+json`."
      error
    end
  end
end
