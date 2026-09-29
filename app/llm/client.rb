module LLM
  class Client
    # Interface for LLM clients
    # All clients must implement this interface
    
    # @param system [String] System prompt
    # @param messages [Array<Hash>] Messages array [{role: "user"|"assistant", content: "..."}]
    # @param schema [Hash, nil] JSON schema for structured output
    # @param tools [Array<Hash>, nil] Tools for tool-use
    # @return [Hash] Response with { content:, usage:, raw: }
    def complete(system:, messages:, schema: nil, tools: nil)
      raise NotImplementedError, "#{self.class}#complete not implemented"
    end

    # Search the web
    # @param query [String] Search query
    # @return [Array<Hash>] Results [{title:, url:, snippet:}]
    def web_search(query)
      raise NotImplementedError, "#{self.class}#web_search not implemented"
    end

    # Check if web search is available
    # @return [Boolean]
    def web_search_available?
      raise NotImplementedError, "#{self.class}#web_search_available? not implemented"
    end

    # Check if code execution is available
    # @return [Boolean]
    def code_execution_available?
      raise NotImplementedError, "#{self.class}#code_execution_available? not implemented"
    end

    # Check if file output is available
    # @return [Boolean]
    def file_output_available?
      raise NotImplementedError, "#{self.class}#file_output_available? not implemented"
    end

    # Check if attachments are supported
    # @return [Boolean]
    def attachments_available?
      raise NotImplementedError, "#{self.class}#attachments_available? not implemented"
    end

    # Check if long output is supported
    # @return [Boolean]
    def long_output_available?
      raise NotImplementedError, "#{self.class}#long_output_available? not implemented"
    end
  end
end
